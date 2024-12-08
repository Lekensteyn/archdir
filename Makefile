
# Source directory (containing /boot and /lib/modules),
# do not set ARCHROOT use the current kernel version,
# use an empty string for the latest kernel version in the current root.
ifdef ARCHROOT
KVER = $(notdir $(lastword $(sort $(wildcard $(ARCHROOT)/lib/modules/[0-9]*.*-arch*-*))))
else
KVER = $(shell uname -r)
endif

# Path to static busybox. Must provide at least modprobe.
BUSYBOX ?= $(lastword $(wildcard /bin/busybox $(ARCHROOT)/bin/busybox))

# Output directory for initrd.gz and bzImage
destdir ?= .
# Initial ramdisk temp dir
idir    ?= $(destdir)/ird


all: $(destdir) $(destdir)/initrd.gz $(destdir)/bzImage
tree:
	$(MAKE) destdir=$(destdir)/kernels/$(KVER) ARCHROOT=$(ARCHROOT) KVER=$(KVER)
	ln -sfn $(KVER) $(destdir)/kernels/current
	test -L $(destdir)/bzImage || ln -sfn kernels/current/bzImage $(destdir)/bzImage
	test -L $(destdir)/initrd.gz || ln -sfn kernels/current/initrd.gz $(destdir)/initrd.gz
$(destdir):
	mkdir -p $@
$(idir)/%: %
	install -Dm755 $< $@
$(idir)/%/:
	install -dm755 $@
$(idir)/installer: installer $(wildcard installer/*)
	rsync -ra --exclude='.*.sw?' $</ $@/

$(idir)/bin/sh: $(idir)/bin/
	ln -sf busybox $@

$(idir)/bin/busybox: $(BUSYBOX)
	@[ -n "$<" ] || { echo "Static binary /bin/busybox is not found!" >&2; exit 1; }
	install -Dm755 $< $@

# Ignore sound
#KDIRS = kernel mm security lib arch crypto \
#	fs/9p fs/fscache net/9p \
#	fs/ext4 fs/jbd2 fs/mbcache.ko* \
#	isofs squashfs \
#	drivers
# ... grr too much work to filter useless ones
KIMAGE = $(lastword $(wildcard \
	$(ARCHROOT)/boot/vmlinuz-linux \
	$(ARCHROOT)/lib/modules/$(KVER)/vmlinuz \
	$(ARCHROOT)/boot/vmlinuz-$(KVER)))
$(destdir)/bzImage: $(KIMAGE)
	cp -va $< $@
$(idir)/lib/modules/$(KVER): \
	$(ARCHROOT)/lib/modules/$(KVER)/kernel \
	$(wildcard $(ARCHROOT)/lib/modules/$(KVER)/modules.*)
	mkdir -p $@
	rsync -ra $^ $@ --include=gpu/drm/ \
		--include=drivers/char/ --include=drivers/char/hw_random/ \
		--include=drivers/input/ \
		--include=drivers/input/{keyboard,serio}/ \
		$$(printf ' --include=%s***' \
		char/hw_random/{rng-core,virtio-rng}.ko crypto/virtio/ \
		drivers/block/{virtio_blk,loop}.ko \
		drivers/input/{keyboard/atkbd,serio/{serio,libps2,i8042},vivaldi-fmap}.ko \
		fs/{9p,ext4,fscache,isofs,netfs,jbd2,squashfs}/ fs/mbcache.ko \
		fs/crypto/ \
		gpu/drm/{bochs_drm,drm_kms_helper,drm}.ko gpu/drm/ttm/ \
		scsi/{scsi,sr}_mod.ko \
		net/{9p/,sched/,virtio_net.ko,net_failover.ko,core/} \
	) $$(printf ' --exclude=%s' \
		sound/ media/ staging/ wireless/ ethernet/ usb/ \
		infiniband/ isdn/ hwmon/ netfilter/ md/ \
		drivers/{hid,iio,misc,mmc,platform,regulator,rtc,target}/ \
		drivers/{watchdog,i2c,mtd,bluetooth,mfd,power,nfc,leds,nvme}/ \
		drivers/{thunderbolt,atm,dma,spi,gpio,ata,crypto,tty}/ \
		drivers/{video,accessibility,extcon,firewire}/ \
		drivers/{message,edac,w1,xen,fpga,soundwire,ntb,hv,pcmcia}/ \
		drivers/{accel,vdpa,ufs,cxl,pinctrl,nvdimm,thermal,ptp,clk,memstick}/ \
		drivers/{block,char,input}/\*\*  \
		{fs,gpu,scsi,net}/\*\*)
	# busybox does not support zstd yet (Oct 2021), so remove compression.
	# See https://github.com/facebook/zstd/issues/2806
	find $@ -name '*.zst' -print0 | xargs -0 unzstd --rm

FILES = init bin/busybox bin/sh
FILES += lib/modules/$(KVER)
FILES += installer

$(destdir)/initrd.gz: $(addprefix $(idir)/,$(FILES))
	@cpio --version >/dev/null || { echo "Please install cpio!" >&2; exit 1; }
	(cd $(idir) && find . | cpio --owner=root:root -H newc -o) | gzip -9 > $@.new
	mv $@.new $@

run: boot-archbuild all
	./boot-archbuild share -vnc :0

.PHONY: clean run all tree
clean:
	rm -vf $(destdir)/bzImage $(destdir)/initrd.gz
