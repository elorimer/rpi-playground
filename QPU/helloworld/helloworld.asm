# Load the value we want to add to the input into a register
ldi ra1, 0x1234

# Configure the VPM for writing
ldi rb49, 0xa00

# Add the input value (first uniform - rb32) and the register with the hard-coded
# constant into the VPM.
add rb48, ra1, rb32;       nop

## move 16 words (1 vector) back to the host (DMA)
ldi rb49, 0x88010000

## initiate the DMA (the next uniform - ra32 - is the host address to write to))
or rb50, ra32, 0;          nop

# Wait for the DMA to complete
or rb39, rb50, ra39;       nop

# trigger a host interrupt (writing rb38) to stop the program
or rb38, ra39, ra39;       nop

nop.tend ra39, ra39, ra39;       nop rb39, rb39, rb39
nop ra39, ra39, ra39;       nop rb39, rb39, rb39
nop ra39, ra39, ra39;       nop rb39, rb39, rb39
