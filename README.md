# archdir
Bootstrap a QEMU/KVM VM for building Arch Linux packages.

Used by me (Lekensteyn) for a quick throw-away package.

## Setup
These files are related to the setup of the VM:

 - init: init script that will be embedded in the initrd.
 - installer/init-arch: initialize system once booted.
 - installer/build.sh: invoked when fully booted (builder.service).

Note: init-arch will pull my screenrc and SSH public key for ease of use (though
screen nor sshd are installed by default).

You can setup an arch mirror at the host machine, port 8001 (see `init-arch`).

## Preparation
Get the Arch Linux iso from https://www.archlinux.org/download/ and save it as
`archlinux.iso` in this directory (or create a symlink, recommended).

Prepare initrd and kernel, assuming that the host is running Arch Linux (using
current kernel image and modules):

    make tree

Otherwise, if the Arch installation root is elsewhere:

    make tree ARCHROOT=/media/Arch

You have to run this each time this repo is updated, or if you want to change
the kernel.

## Running
When run without arguments, it will simply boot. If the first argument is not an
option, it will be treated as the directory that is shared with the guest.
Further arguments are passed to QEMU. After the boot up is completed,
`/home/arch/build.sh` is executed (see `installer/build.sh`).

By default, 4G memory and all but one core is assigned to the guest (see
`boot-archbuild`).

Ctrl-C will not interrupt the VM, use Ctrl-`]` instead.

Typical headless usage (over SSH):

    $ ls -1
    lua53_compat.patch
    PKGBUILD
    vlc.install
    $ # Build everything in tmpfs instead of using 9p/VirtFS (for speed)
    $ echo 'sudo rm -rf /build && sudo cp -a . /build && cd /build' >buildrc
    $ ~/qemu/archdir/boot-archbuild . -vnc :0
    haveged: haveged starting up
    Local pacman packages mirror: http://10.0.2.2:8001
    gpg: etc/pacman.d/gnupg/trustdb.gpg: trustdb created
    gpg: no ultimately trusted keys found
    gpg: starting migration from earlier GnuPG versions
    ...(pacman init and package selection)...
    ==> Installing packages to .
    :: Synchronizing package databases...
     testing                   66.5 KiB  1548K/s 00:00 [######################] 100%
     core                     121.9 KiB  39.7M/s 00:00 [######################] 100%
     extra                   1805.5 KiB  2.97M/s 00:01 [######################] 100%
     community-testing          4.5 KiB  0.00B/s 00:00 [######################] 100%
     community                  2.9 MiB  3.04M/s 00:01 [######################] 100%

    ...(installing packages)...
    (138/139) installing pkg-config                    [######################] 100%
    (139/139) installing sudo                          [######################] 100%
    --2015-10-11 21:48:19--  https://lekensteyn.nl/files/screenrc
    Resolving lekensteyn.nl (lekensteyn.nl)... 178.21.112.251, 2a02:2308::360:1:1
    Connecting to lekensteyn.nl (lekensteyn.nl)|178.21.112.251|:443... connected.
    HTTP request sent, awaiting response... 200 OK
    Length: 243 [application/octet-stream]
    Saving to: 'STDOUT'

    -                   100%[=====================>]     243  --.-KB/s   in 0s

    2015-10-11 21:48:19 (86.2 MB/s) - written to stdout [243/243]

    --2015-10-11 21:48:19--  https://lekensteyn.nl/sshkeys.txt
    Resolving lekensteyn.nl (lekensteyn.nl)... 178.21.112.251, 2a02:2308::360:1:1
    Connecting to lekensteyn.nl (lekensteyn.nl)|178.21.112.251|:443... connected.
    HTTP request sent, awaiting response... 200 OK
    Length: 387 [text/plain]
    Saving to: 'STDOUT'

    -                   100%[=====================>]     387  --.-KB/s   in 0s

    2015-10-11 21:48:20 (70.2 MB/s) - written to stdout [387/387]

    haveged: haveged: Stopping due to signal 15

    [   33.642164] intel_rapl: no valid rapl domains found in package 0
    [   33.711685] intel_rapl: no valid rapl domains found in package 0
    [   33.765853] intel_rapl: no valid rapl domains found in package 0

    Arch Linux 4.2.3-1-ARCH (ttyS0)

    builder login: [  OK  ] Stopped target Timers.
    ...(lots of shutdown messages)...
    [  OK  ] Reached target Shutdown.
    [  OK  ] Unmounted Temporary Directory.
    [  OK  ] Reached target Unmount All Filesystems.
    [  OK  ] Reached target Final Step.
             Starting Power-Off...
    [  396.476765] cgroup: option or name mismatch, new: 0x0 "", old: 0x4 "systemd"
    [  396.846904] reboot: Power down
    $ ls -1
    build.log
    buildrc
    lua53_compat.patch
    package-versions.txt
    PKGBUILD
    vlc-2.2.1-8-x86_64.pkg.tar.xz
    vlc-debug-2.2.1-8-x86_64.pkg.tar.xz
    vlc.install

When the build process is started, you can watch the logs:

    tailf build.log

While the VM is booted above, you can connect with its VNC server:

    gvncviewer localhost:0

## Tips
Ctrl-Alt-2 in the VNC viewer opens the monitor. From there you can use any QEMU
HMP command. Quite useful is the `sendkey` command in case you are stuck in a
TTY and want to switch:

    (qemu) sendkey ctrl-alt-f1


Another buildrc for the `openssl` package which has PGP keys, loosen the cache
policy so that the build does not take absurdly long but still output object
files in the directory.

    gpg --keyserver pgp.mit.edu --recv-keys \
         $(. PKGBUILD; echo "${validpgpkeys[@]}") &&
    cd / && sudo umount shared &&
        sudo mount -t 9p -o cache=loose shared shared && cd shared
