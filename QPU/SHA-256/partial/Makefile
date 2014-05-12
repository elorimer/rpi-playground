MBOX_C = /opt/vc/src/hello_pi/hello_fft/mailbox.c
MBOX_INC = -I/opt/vc/src/hello_pi/hello_fft

sha256: sha256.cpp qpufuncs.cpp
	g++ -O3 -o sha256 sha256.cpp qpufuncs.cpp $(MBOX_C) $(MBOX_INC)
