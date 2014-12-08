#!/bin/bash
[ -e ~/.makepkg.conf ] || cat > ~/.makepkg.conf <<'EOF'
PACKAGER="Peter Wu <peter@lekensteyn.nl>"
MAKEFLAGS="-j$(nproc)"
# See also http://stackoverflow.com/a/27076307/427545
  DEBUG_CFLAGS+=" -ggdb -fno-omit-frame-pointer"
DEBUG_CXXFLAGS+=" -ggdb -fno-omit-frame-pointer"
OPTIONS+=(debug)
EOF

cd /shared || exit 1
if [ -e PKGBUILD ]; then
    makepkg -s --noconfirm
elif [ -f commands -a -x commands ]; then
    ./commands
else
    echo "Expecting PKGBUILD or an executable 'commands', found none!"
    exit 1
fi
rc=$?
if [ $rc -ne 0 ]; then
    printf '\e[31;1m%s\e[m\n' "** Command returned code $rc"
    exit $rc
fi
