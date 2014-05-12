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

#define GPU_MEM_FLG     0xC         // cached
#define GPU_MEM_MAP     0x0         // cached
#define NUNIFORMS       3


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
        u4: stride
     */
    uint32_t uniforms[NUNIFORMS * NUM_QPUS];
    uint32_t msg[NUM_QPUS*2];            // msg is a (uniform, code) tuple to execute_qpu

    /* results are placed back into data where the H vectors were read from */
};


static struct
{
    int mb;
    unsigned handle;
    unsigned size;
    unsigned vc_msg;
    unsigned ptr;
    void* arm_ptr;
} sha256_qpu_context;


int SHA256SetupQPU(uint32_t* K, uint32_t *data, uint32_t *H, int stride,
                   unsigned *shader_code, unsigned code_len)
{
    sha256_qpu_context.mb = mbox_open();
    if (qpu_enable(sha256_qpu_context.mb, 1)) {
        fprintf(stderr, "Unable to enable QPU\n");
        return -1;
    }

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

        arm_map->msg[i*2+0] = vc_uniforms + i * NUNIFORMS * sizeof(uint32_t);
        arm_map->msg[i*2+1] = vc_code;
    }

    return sha256_qpu_context.mb;
}


void SHA256ExecuteQPU(uint32_t* H)
{
    unsigned ret = execute_qpu(sha256_qpu_context.mb, NUM_QPUS,
                               sha256_qpu_context.vc_msg, 1, 10000);
    if (ret != 0)
        fprintf(stderr, "Failed execute_qpu!\n");
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
