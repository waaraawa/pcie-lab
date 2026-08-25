obj-m += edu_pci.o

KDIR ?= $(abspath ../../local/wsl/linux-6.12.101)

.PHONY: all clean

all:
	$(MAKE) -C $(KDIR) M=$(CURDIR) modules

clean:
	$(MAKE) -C $(KDIR) M=$(CURDIR) clean
