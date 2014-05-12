define(`NOP', `nop ra39, ra39, ra39;  nop rb39, rb39, rb39')

## Move the uniforms (arguments) into registers
or ra31, ra32, 0;           nop         # address of K in ra31
or ra30, ra32, 0;           nop         # address of H in ra30
or ra29, ra32, 0;           nop         # address of data in ra29

## Load some rotation constants that don't fit in small immediates
ldi rb2, 0x16;
ldi rb5, 0x19;

## VCD DMA setup for the H vectors (16x8)
ldi ra49, 0x82801000

## Move the H vectors into the VPM (0,0 in VPM)
or ra50, ra30, 0;           nop

## Wait for the DMA to complete
and rb39, ra50, ra50;           nop

## Configure the VPM for reading the H vectors
ldi ra49, 0x801200

## Read the H vectors into registers ra20..ra27 (these are the a..h)
## Also copy them into rb20..rb27 (we need the original values to write back)
or ra20, ra48, 0;           v8max rb20, ra48, ra48;
or ra21, ra48, 0;           v8max rb21, ra48, ra48;
or ra22, ra48, 0;           v8max rb22, ra48, ra48;
or ra23, ra48, 0;           v8max rb23, ra48, ra48;
or ra24, ra48, 0;           v8max rb24, ra48, ra48;
or ra25, ra48, 0;           v8max rb25, ra48, ra48;
or ra26, ra48, 0;           v8max rb26, ra48, ra48;
or ra27, ra48, 0;           v8max rb27, ra48, ra48;

## Configure the VPM/VCD to read the data vectors
ldi ra49, 0x83001000
or ra50, ra29, 0;           nop         ## Load address to DMA
or rb39, ra50, 0;           nop         ## Wait for it

ldi ra49, 0x1200

## First 16 loops of compression
ldi ra2, 0x10;
compress:
    ## r0 = K[i] + h 
    or rb56, ra31, 0;       nop
    nop.tmu ra39, ra39, ra39;   nop
    add ra31, ra31, 4;      nop
    add rb32, r4, ra27;     nop

    ## T1 = h + K[i] + W[i]
    add rb18, r0, rb48;     nop

    ## T1 += CH(e,f,g) => (e & f) ^ (~e & g) (e: ra24, f: ra25, g: ra26)
    or ra32, ra24, 0;       nop         # load e into r0
    and ra33, ra25, r0;     nop         # r1 = r0 & f   (e & f)
    not ra32, r0, 0;        nop         # r0 = ~r0      (~e)
    and ra32, r0, ra26;     nop         # r0 = r0 & g   (~e & g)
    xor ra32, r0, r1;       nop         # r0 = r0 ^ r1  (e & f) ^ (~e & g)
    add rb18, rb18, r0;     nop         # accumulate into T1

    ## T1 += sigma1(e) => RotR(e, 6) ^ RotR(e, 11) ^ RotR(e, 25)
    ror rb32, ra24, 6;      nop
    ror rb33, ra24, 11;     nop
    ror rb34, ra24, rb5;    nop
    xor rb32, r0, r1;       nop
    xor rb32, r0, r2;       nop
    add rb18, r0, rb18;     nop

    ## T2 (ra3) = sigma0(a)  (a: ra20)
    ror ra32, ra20, 2;      nop         # r0 = RotR(a, 2)
    ror ra33, ra20, 13;     nop         # r1 = RotR(a, 13)
    xor ra32, r0, r1;       nop         # r0 = RotR(a, 2) ^ RotR(a, 13)
    ror ra33, ra20, rb2;    nop         # r1 = RotR(a, 22)
    xor ra3, r0, r1;        nop         # T2 = sigma0(a)

    ## T2 += Maj(a,b,c)
    or ra32, ra20, 0;       nop         # load a into r0
    and ra33, r0, ra21;     nop         # r1 = a & b
    and ra34, r0, ra22;     nop         # r2 = a & c
    xor ra32, r1, r2;       nop         # r0 = (a & b) ^ (a & c)
    or ra33, ra21, 0;       nop         # load b into r1
    and ra33, r1, ra22;     nop         # r1 = b & c
    xor ra32, r0, r1;       nop         # r0 = r0 ^ r1
    add ra3, ra3, r0;       nop         # T2 += Maj(a,b,c)

    ## swizzle
    or ra27, ra26, 0;       nop
    or ra26, ra25, 0;       nop
    or ra25, ra24, 0;       nop
    add ra24, ra23, rb18;   nop
    or ra23, ra22, 0;       nop
    or ra22, ra21, 0;       nop
    or ra21, ra20, 0;       nop
    add ra20, rb18, ra3;    nop

    ## Loop
    sub ra2, ra2, 1;        nop
    brr.ze ra39, compress
NOP
NOP
NOP

## Configure the VPM to write the H vectors back into place
ldi rb49, 0x1200

## Write H vectors back (+=)
add rb48, ra20, rb20;       nop
add rb48, ra21, rb21;       nop
add rb48, ra22, rb22;       nop
add rb48, ra23, rb23;       nop
add rb48, ra24, rb24;       nop
add rb48, ra25, rb25;       nop
add rb48, ra26, rb26;       nop
add rb48, ra27, rb27;       nop

## Configure the VCD for DMA back to the host
ldi rb49, 0x88084000

## Write the H address to store
or rb50, ra30, 0;           nop

## Wait for the DMA to complete
or rb39, rb50, ra39;        nop

## Trigger a host interrupt to finish the program
or rb38, ra39, rb39;        nop

nop.tend ra39, ra39, ra39;  nop rb39, rb39, rb39
NOP
NOP
