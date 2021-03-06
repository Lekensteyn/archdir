#!/bin/bash
# Load env vars to ensure that pod2man is available in $PATH
. /etc/profile

[ -e ~/.makepkg.conf ] || cat > ~/.makepkg.conf <<'EOF'
PACKAGER="Peter Wu <peter@lekensteyn.nl>"
MAKEFLAGS="-j$(nproc)"
# See also http://stackoverflow.com/a/27076307/427545
  DEBUG_CFLAGS+=" -ggdb"
DEBUG_CXXFLAGS+=" -ggdb"
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
    sudo pacman-db-upgrade # Installed using pacman 4.1.2, runs 4.2
    # Output logs and packages to this directory by default
    BUILD_OUTDIR=$(pwd)
    if [ -f buildrc ]; then
        # can be used to load additional environment variables or more generally
        # invoke commands before running makepkg.
        . ./buildrc || error "buildrc returned exit code $?"
    fi
    # Hide stdout to avoid clogging journald. Use tail -F build.log instead
    PKGDEST=$BUILD_OUTDIR \
    script -f -e -c \
        'time makepkg -s --noconfirm' \
        "$BUILD_OUTDIR/build.log" >/dev/null
    rc=$?
    pacman -Q > "$BUILD_OUTDIR/package-versions.txt"
    ls -l "$BUILD_OUTDIR"/*.pkg.tar.*
    [ $rc -eq 0 ] || error "makepkg returned exit code $rc"
    [ -e .noshutdown ] || sudo shutdown -h now
else
    error "Expecting PKGBUILD or an executable 'commands', found none!"
fi
