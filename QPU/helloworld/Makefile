MBOX_C = /opt/vc/src/hello_pi/hello_fft/mailbox.c
MBOX_INC = -I/opt/vc/src/hello_pi/hello_fft
FLAGS = -ldl

helloworld: driver.c qpu.c helloworld.bin
	g++ -g -O3 -o helloworld qpu.c driver.c $(MBOX_C) $(MBOX_INC) $(FLAGS)


helloworld.bin: helloworld.asm
	../assembler/qpu-assembler -o helloworld.bin < helloworld.asm 

clean:
	rm -f helloworld.bin
