#include <stdio.h>
#include <inttypes.h>
#include <sys/time.h>
#include <string.h>
#include <stdlib.h>
#include "qpufuncs.h"

#define QPU_CODE_FILE   "sha256.bin"
#define NUM_QPUS        1
#define BUFFER_SIZE     NUM_QPUS * 16

static uint32_t K[] = {
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1,
    0x923f82a4, 0xab1c5ed5, 0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
    0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174, 0xe49b69c1, 0xefbe4786,
    0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147,
    0x06ca6351, 0x14292967, 0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
    0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85, 0xa2bfe8a1, 0xa81a664b,
    0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a,
    0x5b9cca4f, 0x682e6ff3, 0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
    0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
};

static inline uint32_t CH(uint32_t x, uint32_t y, uint32_t z) {
    return (x & y) ^ (~x & z);
}

static inline uint32_t Maj(uint32_t x, uint32_t y, uint32_t z) {
    return (x & y) ^ (x & z) ^ (y & z);
}

static inline uint32_t RotR(uint32_t x, uint8_t shift) {
    return (x >> shift) | (x << (32-shift));
}

static inline uint32_t sigma0(uint32_t x) {
    return RotR(x, 2) ^ RotR(x, 13) ^ RotR(x, 22);
}

static inline uint32_t sigma1(uint32_t x) {
    return RotR(x, 6) ^ RotR(x, 11) ^ RotR(x, 25);
}

static inline uint32_t smsigma0(uint32_t x) {
    return RotR(x, 7) ^ RotR(x, 18) ^ (x >> 3);
}

static inline uint32_t smsigma1(uint32_t x) {
    return RotR(x, 17) ^ RotR(x, 19) ^ (x >> 10);
}

#define ENDIAN(x, i)        ((x[i*4] << 24) | (x[i*4+1] << 16) | (x[i*4+2] << 8) | (x[i*4+3]))

/*
 * data is an array of BUFFER_SIZE buffers to hash
 * H is an input/output parameter
 * stride is the stride for data (TODO: handle hashes of more than one block)
 */
void execute_sha256_cpu(uint32_t *data, uint32_t *H, int stride)
{
    uint32_t W[64];
    uint32_t a, b, c, d, e, f, g, h;

    for (int k=0; k < BUFFER_SIZE; k++)
    {
        for (int i=0; i < 16; i++)
            W[i] = data[k*stride+i];
        for (int i=16; i < 64; i++)
            W[i] = smsigma1(W[i-2]) + W[i-7] + smsigma0(W[i-15]) + W[i-16];

        a = H[k*8+0];
        b = H[k*8+1];
        c = H[k*8+2];
        d = H[k*8+3];
        e = H[k*8+4];
        f = H[k*8+5];
        g = H[k*8+6];
        h = H[k*8+7];

        for (int i=0; i < 64; i++)
        {
            uint32_t T1 = h + sigma1(e) + CH(e,f,g) + K[i] + W[i];
            uint32_t T2 = sigma0(a) + Maj(a,b,c);
            h = g;
            g = f;
            f = e;
            e = d + T1;
            d = c;
            c = b;
            b = a;
            a = T1 + T2;
        }

        H[k*8+0] += a;
        H[k*8+1] += b;
        H[k*8+2] += c;
        H[k*8+3] += d;
        H[k*8+4] += e;
        H[k*8+5] += f;
        H[k*8+6] += g;
        H[k*8+7] += h;
    }
}


void execute_sha256_qpu(uint32_t *data, uint32_t *H, int stride)
{
    SHA256ExecuteQPU(H);
}


int main(int argc, char **argv)
{
    unsigned int shader_code[MAX_CODE_SIZE];
    bool run_cpu(true);

    if (argc < 2) {
        fprintf(stderr, "Usage: %s <input file> [-qpu]\n", argv[0]);
        return 1;
    }
    if (argc > 2 && (strcmp(argv[2], "-qpu") == 0))
        run_cpu = false;

    /* Load the data to hash */
    FILE *f_data = fopen(argv[1], "r");
    if (!f_data) {
        fprintf(stderr, "Unable to open file %s\n", argv[1]);
        return 3;
    }

    /* Load the QPU code */
    int code_len = loadQPUCode(QPU_CODE_FILE, shader_code, MAX_CODE_SIZE);
    if (code_len < 1) {
        fprintf(stderr, "Unable to load QPU code from %s\n", QPU_CODE_FILE);
        return 2;
    }
    printf("Loaded %d bytes of QPU code.\n", code_len);

    int nblocks = 1;                    // 1 512-bit block for now
    int stride = nblocks * 16;
    uint32_t *buffer = new uint32_t[BUFFER_SIZE*stride];
    uint32_t *H = new uint32_t[BUFFER_SIZE*8];

    uint32_t H0[] = { 0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f,
                      0x9b05688c, 0x1f83d9ab, 0x5be0cd19 };
    char filebuffer[64];            // 1 512-bit blocks
    for (int i=0; i < BUFFER_SIZE; i++)
    {
        memcpy(H+i*8, H0, sizeof(H0));
        memset(filebuffer, 0x0, sizeof(filebuffer));
        // read a line up to 64-bytes long
        char *p = fgets(filebuffer, sizeof(filebuffer)-1, f_data);
        if (!p) {
            fprintf(stderr, "Failed to read enough lines from data file.\n");
            delete[] H;
            delete[] buffer;
            return 4;
        }

        int bytes = strlen(filebuffer);
        filebuffer[bytes] = 0x80;           // SHA-256 padding

        // last 8 bytes are the length of the initial message in bits
        uint8_t len_buffer[8];
        *(uint64_t *)len_buffer = bytes * 8;
        for (int j=0; j < 8; j++)
            filebuffer[56+j] = len_buffer[7-j];

        for (int j=0; j < 16; j++)
            buffer[i*16+j] = ENDIAN(filebuffer, j);
    }

    int handle = SHA256SetupQPU(K, buffer, H, stride, shader_code, code_len);
    if (handle < 0) {
        fprintf(stderr, "Unable to setup QPU.  Check permissions\n");
        delete[] buffer;
        delete[] H;
        return 4;
    }

    /*
     * SHA-256 calculation here
     */
    for (int i=0; i < nblocks; i++)
    {
        printf("Running %s version ...\n", (run_cpu) ? "CPU" : "QPU");
        if (run_cpu)
            execute_sha256_cpu(buffer+i*16, H, stride);
        else
            execute_sha256_qpu(buffer+i*16, H, stride);
    }

    if (!run_cpu)
        SHA256FetchResult(H);

    // print out the H
    for (int i=0; i < BUFFER_SIZE; i++) {
        printf("%02d / SHA-256: ", i);
        for (int j=0; j < 8; j++)
            printf("%08x ", H[i*8+j]);
        printf("\n");
    }

    SHA256CleanupQPU(handle);

    delete[] buffer;
    delete[] H;
}
