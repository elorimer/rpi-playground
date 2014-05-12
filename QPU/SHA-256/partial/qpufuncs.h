#ifndef _QPUFUNCS_
#define _QPUFUNCS_

#define NUM_QPUS        1
#define MAX_CODE_SIZE   24000           /* in words */

int SHA256SetupQPU(uint32_t* K, uint32_t *data, uint32_t *H, int stride,
                   unsigned *shader_code, unsigned code_len);
int loadQPUCode(const char *fname, unsigned int* buffer, int len);
void SHA256CleanupQPU(int handle);
void SHA256ExecuteQPU(uint32_t* H);
void SHA256FetchResult(uint32_t* H);

#endif      // _QPUFUNCS_
