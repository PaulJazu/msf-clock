SOURCE=clock.asm
HEXFILE=clock.hex
DEVICE=16f877a

ASM=gpasm
FLAGS=-p$(DEVICE) -o$(HEXFILE)

all:
	$(ASM) $(FLAGS) $(SOURCE)

clean:
	rm -f *.o *.lst *.cod

