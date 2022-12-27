BUILDDIR := build
BOCHS := bochs
OUTPUT := $(BUILDDIR)/main.bin

all: $(OUTPUT)

$(BUILDDIR)/%.bin: %.asm | $(BUILDDIR)
	nasm $< -o $@

debug: $(OUTPUT)
	$(BOCHS) -qf ./.bochsrc

clean:
	rm -f $(OUTPUT)

$(BUILDDIR):
	mkdir -p $(BUILDDIR)