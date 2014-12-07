
# Output directory for initrd.gz and bzImage
destdir ?= .
# Initial ramdisk temp dir
idir    ?= $(destdir)/ird

all: $(destdir)/initrd.gz $(destdir)/bzImage
$(idir)/%: %
	install -Dm755 $< $@

$(idir)/bin/sh:
	ln -s busybox $@

$(idir)/bin/busybox: /bin/busybox
	install -Dm755 $< $@

# Ignore sound
#KDIRS = kernel mm security lib arch crypto \
#	fs/9p fs/fscache net/9p \
#	fs/ext4 fs/jbd2 fs/mbcache.ko* \
#	isofs squashfs \
#	drivers
# ... grr too much work to filter useless ones
ARCHROOT = /media/AArch
ifdef ARCHROOT
KVER = $(notdir $(lastword $(sort $(wildcard $(ARCHROOT)/lib/modules/3.*))))
KIMAGE = $(ARCHROOT)/boot/vmlinuz-linux
else
KVER = $(shell uname -r)
KIMAGE = /boot/vmlinuz-$(KVER)
endif

$(destdir)/bzImage: $(KIMAGE)
	cp -v $< $@
$(idir)/lib/modules/$(KVER): \
	$(ARCHROOT)/lib/modules/$(KVER)/kernel \
	$(ARCHROOT)/lib/modules/$(KVER)/modules.dep
	mkdir -p $@
	cp -r $^ $@

FILES = init init-arch bin/busybox bin/sh
FILES += lib/modules/$(KVER)

$(destdir)/initrd.gz: $(addprefix $(idir)/,$(FILES))
	(cd $(idir) && find . | cpio --owner=root:root -H newc -o) | gzip -9 > $@.new
	mv $@.new $@

run: boot-archbuild all
	./boot-archbuild -vnc :0

.PHONY: clean
clean:
	rm -vf $(destdir)/bzImage $(destdir)/initrd.gz
