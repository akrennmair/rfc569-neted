PC=fpc
PCFLAGS=-Og
PROGRAM=neted

all: $(PROGRAM)

$(PROGRAM): neted.pas
	$(PC) $(PCFLAGS) -o$@ $<

gpc:
	$(MAKE) -f Makefile.gpc $(PROGRAM)

gpc-clean:
	$(MAKE) -f Makefile.gpc clean

clean:
	$(RM) $(PROGRAM) *.ppu *.o
