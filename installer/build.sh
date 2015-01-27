#!/bin/bash
[ -e ~/.makepkg.conf ] || cat > ~/.makepkg.conf <<'EOF'
PACKAGER="Peter Wu <peter@lekensteyn.nl>"
MAKEFLAGS="-j$(nproc)"
# See also http://stackoverflow.com/a/27076307/427545
  DEBUG_CFLAGS+=" -ggdb -fno-omit-frame-pointer"
DEBUG_CXXFLAGS+=" -ggdb -fno-omit-frame-pointer"
OPTIONS+=(debug)
EOF

# Non-interactive
exec </dev/null
error() {
    printf '\e[31;1m%s\e[m\n' "$@"
    exit 1
}

cd /shared || exit 1
if [ -f commands -a -x commands ]; then
    ./commands || error "command returned exit code $?"
elif [ -e PKGBUILD ]; then
    if [ -f buildrc ]; then
        # can be used to load additional environment variables or more generally
        # invoke commands before running makepkg.
        . ./buildrc
    fi
    # Hide stdout to avoid clogging journald. Use tail -F build.log instead
    script -f -e -c \
        'time makepkg -s --noconfirm' \
        build.log >/dev/null
    rc=$?
    pacman -Q > package-versions.txt
    ls -l *.pkg.tar.*
    [ $rc -eq 0 ] || error "makepkg returned exit code $rc"
    [ -e .noshutdown ] || sudo shutdown -h now
else
    error "Expecting PKGBUILD or an executable 'commands', found none!"
fi
