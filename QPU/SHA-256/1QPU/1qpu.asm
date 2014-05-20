define(`NOP', `nop ra39, ra39, ra39;  nop rb39, rb39, rb39')
define(`GENSCHEDULE',
`
    add rb32, $1, 0;                nop         # r0 = W_i-16
    ror rb33, $2, 7;                nop         # r1 = RotR(x, 7)
    ror rb34, $2, rb6;              nop         # r2 = RotR(x, 18)
    shr rb35, $2, 3;                nop         # r3 = x >> 3;
    xor rb33, r1, r2;               nop         # r1 = r1 ^ r2
    xor rb35, r1, r3;               nop         # r3 = r1 ^ r3
    add rb32, r0, r3;               nop         # r0 += r3          (W_i-16 + smsigma0(W_i-15))
    add rb32, r0, $3;               nop         # r0 += W_i-7
    ror rb33, $4, rb8;              nop         # r1 = RotR(x, 17)
    ror rb34, $4, rb7;              nop         # r2 = RotR(x, 19)
    xor rb33, r1, r2;               nop         # r1 = r1 ^ r2
    shr rb34, $4, 10;               nop         # r2 = x >> 10
    xor rb33, r1, r2;               nop         # r1 = r1 ^ r2
    add $1, r0, r1;                 nop         # r0 += smsigma1(W_i-2)
    add rb48, r0, r1;               nop
    ## $2 ignored, $3 ignored, $4 ignored, $1 ignored (suppress warnings)')
define(`GENSCHEDULE_ALL',
`
GENSCHEDULE(`ra4', `ra5', `ra13', `ra18')
GENSCHEDULE(`ra5', `ra6', `ra14', `ra19')
GENSCHEDULE(`ra6', `ra7', `ra15', `ra4')
GENSCHEDULE(`ra7', `ra8', `ra16', `ra5')
GENSCHEDULE(`ra8', `ra9', `ra17', `ra6')
GENSCHEDULE(`ra9', `ra10', `ra18', `ra7')
GENSCHEDULE(`ra10', `ra11', `ra19', `ra8')
GENSCHEDULE(`ra11', `ra12', `ra4', `ra9')
GENSCHEDULE(`ra12', `ra13', `ra5', `ra10')
GENSCHEDULE(`ra13', `ra14', `ra6', `ra11')
GENSCHEDULE(`ra14', `ra15', `ra7', `ra12')
GENSCHEDULE(`ra15', `ra16', `ra8', `ra13')
GENSCHEDULE(`ra16', `ra17', `ra9', `ra14')
GENSCHEDULE(`ra17', `ra18', `ra10', `ra15')
GENSCHEDULE(`ra18', `ra19', `ra11', `ra16')
GENSCHEDULE(`ra19', `ra4', `ra12', `ra17')')

## Move the uniforms (arguments) into registers
or ra31, ra32, 0;           nop         # address of K in ra31
or ra30, ra32, 0;           nop         # address of H in ra30
or ra29, ra32, 0;           nop         # address of data in ra29

## Load some rotation constants that don't fit in small immediates
ldi rb2, 0x16;
ldi rb5, 0x19;
ldi rb6, 0x12;
ldi rb7, 0x13;
ldi rb8, 0x11;

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

## Read the data vectors into ra4..ra19 since we use the registers in
## GENSCHEDULE
ldi ra49, 0x1200
or ra4, ra48, 0;            nop
or ra5, ra48, 0;            nop
or ra6, ra48, 0;            nop
or ra7, ra48, 0;            nop
or ra8, ra48, 0;            nop
or ra9, ra48, 0;            nop
or ra10, ra48, 0;           nop
or ra11, ra48, 0;           nop
or ra12, ra48, 0;           nop
or ra13, ra48, 0;           nop
or ra14, ra48, 0;           nop
or ra15, ra48, 0;           nop
or ra16, ra48, 0;           nop
or ra17, ra48, 0;           nop
or ra18, ra48, 0;           nop
or ra19, ra48, 0;           nop


## 4 loops of 16 = 64 iterations
ldi ra1, 4
mainloop:

ldi ra49, 0x1200
## 16 loops of compression
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
    sub ra1, ra1, 1;        nop
    brr.zf ra39, done
    NOP
    NOP
    NOP
    ldi rb49, 0x1200
    GENSCHEDULE_ALL
    brr ra39, mainloop
done:
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
