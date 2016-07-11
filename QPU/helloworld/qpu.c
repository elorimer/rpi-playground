// Extraction of rpi hello_fft example
/*
BCM2835 "GPU_FFT" release 3.0
Copyright (c) 2015, Andrew Holme.
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:
    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name of the copyright holder nor the
      names of its contributors may be used to endorse or promote products
      derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

#include <dlfcn.h>

#include "mailbox.h"
#include "qpu.h"

int gpu_fft_get_host_info(struct GPU_FFT_HOST *info) {
    void *handle;
    unsigned (*bcm_host_get_sdram_address)     (void);
    unsigned (*bcm_host_get_peripheral_address)(void);
    unsigned (*bcm_host_get_peripheral_size)   (void);

    // Pi 1 defaults
    info->peri_addr = 0x20000000;
    info->peri_size = 0x01000000;
    info->mem_flg = GPU_FFT_USE_VC4_L2_CACHE? 0xC : 0x4;
    info->mem_map = GPU_FFT_USE_VC4_L2_CACHE? 0x0 : 0x20000000; // Pi 1 only

    handle = dlopen("libbcm_host.so", RTLD_LAZY);
    if (!handle) return -1;

    *(void **) (&bcm_host_get_sdram_address)      = dlsym(handle, "bcm_host_get_sdram_address");
    *(void **) (&bcm_host_get_peripheral_address) = dlsym(handle, "bcm_host_get_peripheral_address");
    *(void **) (&bcm_host_get_peripheral_size)    = dlsym(handle, "bcm_host_get_peripheral_size");

    if (bcm_host_get_sdram_address && bcm_host_get_sdram_address()!=0x40000000) { // Pi 2?
        info->mem_flg = 0x4; // ARM cannot see VC4 L2 on Pi 2
        info->mem_map = 0x0;
    }

    if (bcm_host_get_peripheral_address) info->peri_addr = bcm_host_get_peripheral_address();
    if (bcm_host_get_peripheral_size)    info->peri_size = bcm_host_get_peripheral_size();

    dlclose(handle);
    return 0;
}

