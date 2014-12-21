
# Output directory for initrd.gz and bzImage
destdir ?= .
# Initial ramdisk temp dir
idir    ?= $(destdir)/ird

all: $(destdir)/initrd.gz $(destdir)/bzImage
$(idir)/%: %
	install -Dm755 $< $@
$(idir)/installer: installer $(wildcard installer/*)
	rsync -ra --exclude='.*.sw?' $</ $@/

$(idir)/bin/sh:
	ln -sf busybox $@

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
	cp -va $< $@
$(idir)/lib/modules/$(KVER): \
	$(ARCHROOT)/lib/modules/$(KVER)/kernel \
	$(wildcard $(ARCHROOT)/lib/modules/$(KVER)/modules.*)
	mkdir -p $@
	rsync -ra $^ $@ --include=gpu/drm/ $$(printf ' --include=fs/%s\*\*\*' \
		fs/{9p,ext4,fscache,isofs,jbd2,squashfs}/ fs/mbcache.ko \
		gpu/drm/{drm_kms_helper,drm}.ko gpu/drm/ttm/ \
		scsi/{scsi,sr}_mod.ko \
		net/{9p/,sched/,virtio_net.ko} \
	) $$(printf ' --exclude=%s' \
		sound/ media/ staging/ wireless/ ethernet/ usb/ \
		infinibind/ isdn/ hwmon/ netfilter/ md/ \
		{fs,gpu,scsi,net}/\*\*)

FILES = init bin/busybox bin/sh
FILES += lib/modules/$(KVER)
FILES += installer

$(destdir)/initrd.gz: $(addprefix $(idir)/,$(FILES))
	(cd $(idir) && find . | cpio --owner=root:root -H newc -o) | gzip -9 > $@.new
	mv $@.new $@

run: boot-archbuild all
	./boot-archbuild share -vnc :0

.PHONY: clean run
clean:
	rm -vf $(destdir)/bzImage $(destdir)/initrd.gz
