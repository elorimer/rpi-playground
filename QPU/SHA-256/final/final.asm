define(`MUTEX_ACQUIRE',     `or ra39, ra51, rb39;           nop')
define(`MUTEX_RELEASE',     `or ra51, ra39, ra39;           nop')
define(`NOP',   `nop ra39, ra39, ra39;      nop rb39, rb39, rb39')
##
# generate a schedule vector.  Call as
# GENSCHEDULE(register W_i-16, W_i-15, W_i-7, W_i-2, destination reg)
# these need to be a registers because we use small immediates
# uses temp registers r0 - r3
#

define(`FAKESCHEDULE',
`   or ra1, $1, $1;                 nop
    bra ra39, ZERO, ra0;
    NOP
    NOP
    NOP')

define(`GENSCHEDULE',
`
    ror rb33, $2, 7;                nop         # r1 = RotR(x, 7)
    ror rb34, $2, rb6;              nop         # r2 = RotR(x, 18)
    shr rb35, $2, 3;                nop         # r3 = x >> 3;
    xor rb33, r1, r2;               v8max ra32, $1, $1         # r1 = r1 ^ r2, r0 = W_i-16
    xor rb35, r1, r3;               nop         # r3 = r1 ^ r3
    add rb32, r0, r3;               nop         # r0 += r3          (W_i-16 + smsigma0(W_i-15))
    add rb32, r0, $3;               nop         # r0 += W_i-7
    ror rb33, $4, rb8;              nop         # r1 = RotR(x, 17)
    ror rb34, $4, rb7;              nop         # r2 = RotR(x, 19)
    xor rb33, r1, r2;               nop         # r1 = r1 ^ r2
    shr rb34, $4, 10;               nop         # r2 = x >> 10
    xor rb33, r1, r2;               nop         # r1 = r1 ^ r2
    add $1, r0, r1;                 nop         # r0 += smsigma1(W_i-2)
    ## move it into another register for reading
    add ra1, r0, r1;                nop
    ## branch back (ra0)
    bra ra39, ZERO, ra0
    NOP
    NOP
    NOP
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
define(`FAKESCHEDULE_ALL',
`
FAKESCHEDULE(`ra4')
FAKESCHEDULE(`ra5')
FAKESCHEDULE(`ra6')
FAKESCHEDULE(`ra7')
FAKESCHEDULE(`ra8')
FAKESCHEDULE(`ra9')
FAKESCHEDULE(`ra10')
FAKESCHEDULE(`ra11')
FAKESCHEDULE(`ra12')
FAKESCHEDULE(`ra13')
FAKESCHEDULE(`ra14')
FAKESCHEDULE(`ra15')
FAKESCHEDULE(`ra16')
FAKESCHEDULE(`ra17')
FAKESCHEDULE(`ra18')
FAKESCHEDULE(`ra19')')

# move the uniforms into registers
or ra31, ra32, 0;           nop        # address of K in ra31
or ra30, ra32, 0;           nop        # address of H in ra30
or rb29, ra32, 0;           nop        # address of data in rb29
or ra2, ra32, 0;            nop        # number of laps in ra2

or rb31, ra31, 0;           nop        ## save ra31 (K address) since we overwrite
                                       ## this in the main loop

# some rotation constants that don't fit in small immediates
ldi rb2, 0x16;
ldi rb5, 0x19;
ldi rb6, 0x12;
ldi rb7, 0x13;
ldi rb8, 0x11;

mainloop:
    ## Restore the K texture base address
    and ra31, rb31, rb31;       nop

## Lock the VPM mutex
MUTEX_ACQUIRE()

# VDR DMA read setup for data vectors (16x16)
# MODEW = 0, MPITCH = 3, ROWLEN = 16, NROWS = 16, VPITCH=1, VERT = 0, ADDRXY = 0
ldi ra49, 0x83001000

# Move the data vectors into place (0,0 in VPM)
or ra50, rb29, rb29;       nop

# wait for the DMA to complete
or rb39, ra50, 0;    nop

# read the data vectors into ra4 .. ra19
ldi ra49, 0x1200
or ra4, ra48, 0;        nop
or ra5, ra48, 0;        nop
or ra6, ra48, 0;        nop
or ra7, ra48, 0;        nop
or ra8, ra48, 0;        nop
or ra9, ra48, 0;        nop
or ra10, ra48, 0;        nop
or ra11, ra48, 0;        nop
or ra12, ra48, 0;        nop
or ra13, ra48, 0;        nop
or ra14, ra48, 0;        nop
or ra15, ra48, 0;        nop
or ra16, ra48, 0;        nop
or ra17, ra48, 0;        nop
or ra18, ra48, 0;        nop
or ra19, ra48, 0;        nop

# VDR DMA read setup for H vectors (16x8)
# MODEW = 0, MPITCH = 2, ROWLEN = 8, NROWS = 16, VPITCH=1, VERT = 0, ADDRXY = (16, 0)
ldi ra49, 0x82801000

# Move the data vectors into place (16,0 in VPM)
or ra50, ra30, 0;       nop

# wait for the DMA to complete
or rb39, ra50, 0;       nop

# configure the VPM for reading the H vectors 
ldi ra49, 0x801200

# read the H vectors into registers ra20..ra27 (this is a .. h) and rb20..rb27
# (We read them into rb registers so that we can write them back)
or ra20, ra48, 0;            v8max rb20, ra48, ra48
or ra21, ra48, 0;            v8max rb21, ra48, ra48
or ra22, ra48, 0;            v8max rb22, ra48, ra48
or ra23, ra48, 0;            v8max rb23, ra48, ra48
or ra24, ra48, 0;            v8max rb24, ra48, ra48
or ra25, ra48, 0;            v8max rb25, ra48, ra48
or ra26, ra48, 0;            v8max rb26, ra48, ra48
or ra27, ra48, 0;            v8max rb27, ra48, ra48

## Unlock the VPM mutex
MUTEX_RELEASE()


define(`COMPRESS_ITER',
`
    ## Compute T1, and T2

    # T1 += K[i]
    # move the data address in ra31 (K vector) increment the K[i] and do the
    # texture lookup
    # cannot put the .tmu on add because it is using a small immediate which
    # is a sig as well
    # (prefetching these, see below rb56 and .tmu))
    add ra31, ra31, 4;              nop
    add rb32, r4, ra27;             v8max ra1, rb0, rb0;

    # T1 += W[i]
    ## need another instruction here to avoid the RAW hazard
    add rb0, rb0, ra29;               nop
    ## this is a confusing overload of ra1 but we are running out of registers
    brr ra0, fakeschedule, ra1
    NOP
    NOP
    NOP
    add rb18, r0, ra1;              nop

    # T1 = CH(e,f,g) = (e & f) ^ (~e & g) (e = ra24, f = ra25, g = ra26
    or ra32, ra24, 0;           nop         # load e into r0
    and ra33, ra25, r0;         nop         # r1 = r0 & f  (e & f)
    not ra32, r0, 0;            v8max rb56, ra31, ra31         # r0 = ~r0 (~e)
    and ra32, r0, ra26;         nop         # r0 = r0 & g (~e & g)
    xor ra32, r0, r1;           nop         # r0 = r0 ^ r1 (e & f) ^ (~e & g)
    add rb18, rb18, r0;         v8max ra27, ra26, ra26         # T1 += 

    # T1 = sigma1(e) = RotR(e, 6) ^ RotR(e, 11) ^ RotR(e, 25)
    ror rb32, ra24, 6;          nop
    ror rb33, ra24, 11;         nop
    ror rb34, ra24, rb5;       nop
    xor rb32, r0, r1;           v8max ra26, ra25, ra25
    xor rb32, r0, r2;           v8max ra25, ra24, ra24

    # T1 = sigma1(e) + CH(e,f,g)
    add.tmu rb18, r0, rb18;         nop

    # T2 = sigma0(a) = ra20
    ror ra32, ra20, 2;          nop         # r0 = RotR(a, 2)
    ror ra33, ra20, 13;         nop         # r1 = RotR(a, 13)
    xor ra32, r0, r1;           nop         # r0 = RotR(a, 2) ^ RotR(a, 13)
    ror ra33, ra20, rb2;        nop         # r1 = RotR(a, 22)
    xor ra3, r0, r1;            v8max rb32, ra20, ra20      # T2 = r0 ^ r1, load a into r0

    add ra24, ra23, rb18;       nop

    # T2 += Maj(a,b,c) = 
    and ra33, r0, ra21;         nop         # r1 = a & b
    and ra34, r0, ra22;         nop         # r2 = a & c
    xor ra32, r1, r2;           v8max rb33, ra21, ra21      # r0 = r1 ^ r2, load b into r1

    and rb33, r1, ra22;         v8max ra23, ra22, ra22         # r1 = b & c

    xor rb32, r0, r1;           v8max ra22, ra21, ra21         # r0 = r0 ^ r1
    add ra3, ra3, r0;         nop         # T2 +=

    or ra21, ra20, 0;          nop
    add ra20, rb18, ra3;       nop
')
define(`COMPRESS_SCHED_ITER',
`
    ## Compute T1, and T2

    # T1 += K[i]
    # move the data address in ra31 (K vector) increment the K[i] and do the
    # texture lookup
    # cannot put the .tmu on add because it is using a small immediate which
    # is a sig as well
    # (prefetching these, see below rb56 and .tmu))
    add ra31, ra31, 4;              nop
    add rb32, r4, ra27;             v8max ra1, rb0, rb0;
    add rb18, r0, 0;                nop

    # T1 += W[i]
    ## this is a confusing overload of ra1 but we are running out of registers
    brr ra0, genschedule, ra1
    NOP
    NOP
    NOP
    add rb18, rb18, ra1;              nop
    add rb0, rb0, ra29;               nop

    # T1 = CH(e,f,g) = (e & f) ^ (~e & g) (e = ra24, f = ra25, g = ra26
    or ra32, ra24, 0;           nop         # load e into r0
    and ra33, ra25, r0;         nop         # r1 = r0 & f  (e & f)
    not ra32, r0, 0;            v8max rb56, ra31, ra31         # r0 = ~r0 (~e)
    and ra32, r0, ra26;         nop         # r0 = r0 & g (~e & g)
    xor ra32, r0, r1;           nop         # r0 = r0 ^ r1 (e & f) ^ (~e & g)
    add rb18, rb18, r0;         v8max ra27, ra26, ra26         # T1 += 

    # T1 = sigma1(e) = RotR(e, 6) ^ RotR(e, 11) ^ RotR(e, 25)
    ror rb32, ra24, 6;          nop
    ror rb33, ra24, 11;         nop
    ror rb34, ra24, rb5;        nop
    xor rb32, r0, r1;           v8max ra26, ra25, ra25
    xor rb32, r0, r2;           v8max ra25, ra24, ra24

    # T1 = sigma1(e) + CH(e,f,g)
    add.tmu rb18, r0, rb18;         nop

    # T2 = sigma0(a) = ra20
    ror ra32, ra20, 2;          nop         # r0 = RotR(a, 2)
    ror ra33, ra20, 13;         nop         # r1 = RotR(a, 13)
    xor ra32, r0, r1;           nop         # r0 = RotR(a, 2) ^ RotR(a, 13)
    ror ra33, ra20, rb2;        nop         # r1 = RotR(a, 22)
    xor ra3, r0, r1;            v8max rb32, ra20, ra20      # T2 = r0 ^ r1, load a into r0

    add ra24, ra23, rb18;       nop

    # T2 += Maj(a,b,c) = 
    and ra33, r0, ra21;         nop         # r1 = a & b
    and ra34, r0, ra22;         nop         # r2 = a & c
    xor ra32, r1, r2;           v8max rb33, ra21, ra21      # r0 = r1 ^ r2, load b into r1

    and rb33, r1, ra22;         v8max ra23, ra22, ra22         # r1 = b & c

    xor rb32, r0, r1;           v8max ra22, ra21, ra21         # r0 = r0 ^ r1
    add ra3, ra3, r0;         nop         # T2 +=

    or ra21, ra20, 0;          nop
    add ra20, rb18, ra3;       nop
')


ldi ra29, 40        ## fakeschedule table index increment
## First 16 times use fakeschedule lookups
ldi ra28, 0x10
or rb56, ra31, 0;           nop
xor.tmu rb0, rb0, rb0;          nop
firstloop:
    COMPRESS_ITER()
    sub ra28, ra28, 1;      nop
    brr.ze ra39, firstloop
NOP
NOP
NOP

ldi ra29, 144
## Next 48 times (16*3) use genschedule lookups
ldi rb19, 3
outerloop:
    ldi ra28, 0x10
    or rb56, ra31, 0;           nop
    xor.tmu rb0, rb0, rb0;          nop
    innerloop:
        COMPRESS_SCHED_ITER()
        sub ra28, ra28, 1;      nop
        brr.ze ra39, innerloop
    NOP
    NOP
    NOP

    ldi ra32, 1;
    sub rb19, rb19, r0;          nop
    brr.ze ra39, outerloop
NOP
NOP
NOP


## Lock the VPM mutex
MUTEX_ACQUIRE()

# configure the VPM to write the H vectors back into place 
# (stride=1, vert, Y=16, X=0)
ldi rb49, 0x1200

# write the vectors back (+=)
add rb48, ra20, rb20;           nop
add rb48, ra21, rb21;           nop
add rb48, ra22, rb22;           nop
add rb48, ra23, rb23;           nop
add rb48, ra24, rb24;           nop
add rb48, ra25, rb25;           nop
add rb48, ra26, rb26;           nop
add rb48, ra27, rb27;           nop

# configure the VPM for DMA back to the host
# nrows=16, rowlen=8, 16, 0, horiz=1
ldi rb49, 0x88084000

# write the H address again to store
or rb50, ra30, 0;           nop

# Wait for the DMA to complete
or rb39, rb50, ra39;       nop ra39, ra39, ra39

## Unlock the VPM mutex
MUTEX_RELEASE()

    sub ra2, ra2, 1;        nop
    brr.ze ra39, mainloop
NOP
NOP
NOP

# trigger a host interrupt to stop the program (not necessary with direct-exec)
or rb38, ra39, rb39;         nop ra39, ra39, ra39

finished:
nop.tend ra39, ra39, ra39;      nop rb39, rb39, rb39
NOP
NOP


## schedule code table
genschedule:
GENSCHEDULE_ALL()

fakeschedule:
FAKESCHEDULE_ALL()
