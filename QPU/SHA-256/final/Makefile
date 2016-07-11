MBOX_C = /opt/vc/src/hello_pi/hello_fft/mailbox.c ../../helloworld/qpu.c
MBOX_INC = -I/opt/vc/src/hello_pi/hello_fft -I../../helloworld
FLAGS = -ldl

sha256: sha256.cpp qpufuncs.cpp sha256.bin
	g++ -O3 -o sha256 sha256.cpp qpufuncs.cpp $(MBOX_C) $(MBOX_INC) $(FLAGS)

sha256.bin: final.m4.asm
	../../assembler/qpu-assembler -o sha256.bin < final.m4.asm 

# Install m4 with 'sudo apt-get install m4' 
final.m4.asm: final.asm /usr/bin/m4
	m4 final.asm > final.m4.asm


