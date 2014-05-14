#include <stdio.h>
#include <sys/mman.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <inttypes.h>
#include <string.h>             // memset
#include <stddef.h>
#include <unistd.h>
#include "mailbox.h"
#include "qpufuncs.h"

//#define GPU_MEM_FLG 0x4 // cached=0xC; direct=0x4
//#define GPU_MEM_MAP 0x20000000 // cached=0x0; direct=0x20000000

#define GPU_MEM_FLG     0xC
#define GPU_MEM_MAP     0x0
#define REGISTER_BASE   0x20C00000

#define V3D_SRQPC       0x10c
#define V3D_SRQUA       0x10d
#define V3D_SRQUL       0x10e
#define V3D_SRQCS       0x10f

#define V3D_VPMBASE     0x7e

#define V3D_L2CACTL     0x8
#define V3D_SLCACTL     0x9

//#define DIRECT_EXEC
#define NUNIFORMS       4


/*
 * TODO: expand this for multiple QPUs
 */
struct sha256_memory_map
{
    /*
       data layout is:
         64 words for K constants (accessed as a texture lookup)
         16x8 (128) words for the 8 H vectors (VPM)
         16x16 (256) words for the input data (VPM)
       Total: 448 words
     */
    uint32_t data[64 + (128 + 256) * NUM_QPUS];
    uint32_t code[MAX_CODE_SIZE];
    /*
      uniforms are:
        u1: address of K texture
        u2: address of H vectors (also output location)
        u3: address of data buffer
        u4: number of laps to execute
     */
    uint32_t uniforms[NUNIFORMS*NUM_QPUS];
    uint32_t msg[NUM_QPUS*2];            // msg is a (uniform, code) tuple to execute_qpu

    /* Results are placed back into the H vector */
};


static struct
{
    int mb;
    unsigned handle;
    unsigned size;
    unsigned vc_msg;
    unsigned ptr;
    void* arm_ptr;
    volatile uint32_t *registers;
} sha256_qpu_context;


int SHA256SetupQPU(uint32_t* K, uint32_t *data, uint32_t *H, int stride,
                   unsigned *shader_code, unsigned code_len)
{
    sha256_qpu_context.mb = mbox_open();
    if (qpu_enable(sha256_qpu_context.mb, 1)) {
        fprintf(stderr, "Unable to enable QPU\n");
        return -1;
    }

#ifdef DIRECT_EXEC
    int mem_dev = open("/dev/mem", O_RDWR|O_SYNC);
    if (mem_dev == -1) {
        fprintf(stderr, "Error opening /dev/mem.  Check permissions\n");
        mbox_close(sha256_qpu_context.mb);
        return -1;
    }
    // close mem_dev
    // munmap cleanup

    sha256_qpu_context.registers = (volatile uint32_t*)mmap(NULL, 4096, PROT_READ|PROT_WRITE,
                                                            MAP_SHARED, mem_dev, REGISTER_BASE);
    if (sha256_qpu_context.registers == MAP_FAILED) {
        fprintf(stderr, "mmap failed.\n");
        close(mem_dev);
        mbox_close(sha256_qpu_context.mb);
        return -1;
    }
#endif

    // 1 MB should be plenty
    sha256_qpu_context.size = 1024 * 1024;
    sha256_qpu_context.handle = mem_alloc(sha256_qpu_context.mb,
                                          sha256_qpu_context.size, 4096,
                                          GPU_MEM_FLG);
    if (!sha256_qpu_context.handle) {
        fprintf(stderr, "Unable to allocate %d bytes of GPU memory",
                        sha256_qpu_context.size);
        return -2;
    }
    unsigned ptr = mem_lock(sha256_qpu_context.mb, sha256_qpu_context.handle);
    sha256_qpu_context.arm_ptr = mapmem(ptr + GPU_MEM_MAP, sha256_qpu_context.size);
    sha256_qpu_context.ptr = ptr;
    printf("Locked memory at 0x%x = 0x%x\n", ptr, sha256_qpu_context.arm_ptr);

    struct sha256_memory_map *arm_map = (struct sha256_memory_map *)
                                                sha256_qpu_context.arm_ptr;
    memset(arm_map, 0x0, sizeof(struct sha256_memory_map));
    unsigned vc_data = ptr + offsetof(struct sha256_memory_map, data);
    unsigned vc_uniforms = ptr + offsetof(struct sha256_memory_map, uniforms);
    unsigned vc_code = ptr + offsetof(struct sha256_memory_map, code);
    sha256_qpu_context.vc_msg = ptr + offsetof(struct sha256_memory_map, msg);

    memcpy(arm_map->code, shader_code, code_len);
    memcpy(arm_map->data, K, 64*sizeof(uint32_t));
    memcpy(arm_map->data+64, H, 128*sizeof(uint32_t)*NUM_QPUS);
    memcpy(arm_map->data+64 + 128*NUM_QPUS, data, 256*NUM_QPUS*sizeof(uint32_t));
    for (int i=0; i < NUM_QPUS; i++) {
        arm_map->uniforms[i*NUNIFORMS+0] = vc_data;         // data (address of K texture)
        arm_map->uniforms[i*NUNIFORMS+1] = vc_data + 64*sizeof(uint32_t) + 128 * i * sizeof(uint32_t);         // address of H vectors
        arm_map->uniforms[i*NUNIFORMS+2] = vc_data + 64*sizeof(uint32_t) + 128*NUM_QPUS*sizeof(uint32_t) + 256 * i * sizeof(uint32_t);
        arm_map->uniforms[i*NUNIFORMS+3] = 20000;           // fill this in in ExecuteQPU
        arm_map->msg[i*2+0] = vc_uniforms + i * NUNIFORMS * sizeof(uint32_t);
        arm_map->msg[i*2+1] = vc_code;
    }
    
    return sha256_qpu_context.mb;
}


void SHA256ExecuteQPU(uint32_t* H, int nlaps)
{
    struct sha256_memory_map *arm_map = (struct sha256_memory_map *)
                                                sha256_qpu_context.arm_ptr;
    for (int i=0; i < NUM_QPUS; i++)
        arm_map->uniforms[i*NUNIFORMS+3] = 20000;

#ifndef DIRECT_EXEC
    unsigned ret = execute_qpu(sha256_qpu_context.mb, NUM_QPUS,
                               sha256_qpu_context.vc_msg, 1, 10000);
    if (ret != 0)
        fprintf(stderr, "Failed execute_qpu!\n");
#else
    uint32_t qst = sha256_qpu_context.registers[V3D_SRQCS];
    int qlength = qst & 0x3f;
    int qreqs = (qst >> 8) & 0xFF;
    int qcomp = (qst >> 16) & 0xFF;
    int qerr = (qst >> 7) & 0x1;
//    printf("Queue length: %d, completed: %d, requests: %d, err: %d\n", qlength, qcomp, qreqs, qerr);
    int target = (qcomp + NUM_QPUS) % 256;

    for (int i=0; i < NUM_QPUS; i++)
    {
        sha256_qpu_context.registers[V3D_SRQUL] = NUNIFORMS;
        sha256_qpu_context.registers[V3D_SRQUA] = arm_map->msg[i*2+0];
        sha256_qpu_context.registers[V3D_SRQPC] = arm_map->msg[i*2+1];
    }

    do {
        qst = sha256_qpu_context.registers[V3D_SRQCS];
        qcomp = (qst >> 16) & 0xFF;
    } while (qcomp != target);
//    printf("Queue length: %d, completed: %d, requests: %d, err: %d\n", qlength, qcomp, qreqs, qerr);
#endif
}


void SHA256CleanupQPU(int handle)
{
    unmapmem(sha256_qpu_context.arm_ptr, sha256_qpu_context.size);
    mem_unlock(sha256_qpu_context.mb, sha256_qpu_context.handle);
    mem_free(sha256_qpu_context.mb, sha256_qpu_context.handle);
    qpu_enable(sha256_qpu_context.mb, 0);
    mbox_close(sha256_qpu_context.mb);
}


void SHA256FetchResult(uint32_t *H)
{
    struct sha256_memory_map *arm_map = (struct sha256_memory_map *)
                                                sha256_qpu_context.arm_ptr;
    memcpy(H, arm_map->data+64, NUM_QPUS*128*sizeof(uint32_t));
}


int loadQPUCode(const char *fname, unsigned int* buffer, int len)
{
    FILE *in = fopen(fname, "r");
    if (!in) {
        fprintf(stderr, "Failed to open %s.\n", fname);
        return -1;
    }

    size_t items = fread(buffer, sizeof(unsigned int), len, in);
    fclose(in);

    return items * sizeof(unsigned int);
}
