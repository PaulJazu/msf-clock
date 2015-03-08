SOURCE=clock.asm
HEXFILE=clock_$(DEVICE).hex

ASM=gpasm
FLAGS=-p$(DEVICE) -o$(HEXFILE)

all: p16f877 p16f877a p16f887 p16f874 p16f874a p16f884

p16f877:
	$(eval DEVICE := 16f877)
	$(ASM) $(FLAGS) $(SOURCE)

p16f877a:
	$(eval DEVICE := 16f877a)
	$(ASM) $(FLAGS) $(SOURCE)

p16f887:
	$(eval DEVICE := 16f887)
	$(ASM) $(FLAGS) $(SOURCE)

p16f874:
	$(eval DEVICE := 16f874)
	$(ASM) $(FLAGS) $(SOURCE)

p16f874a:
	$(eval DEVICE := 16f874a)
	$(ASM) $(FLAGS) $(SOURCE)

p16f884:
	$(eval DEVICE := 16f884)
	$(ASM) $(FLAGS) $(SOURCE)

clean:
	rm -f *.o *.lst *.cod

