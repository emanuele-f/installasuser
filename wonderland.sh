#!/bin/bash
#
# Emanuele Faranda                                               25-Feb-2015
#
# A script to setup and enter proot environment
#

# Settings
ROOTDIR="./sysroot"
UNIONDIR="./rootfs"
PKGCACHE="./pkgcache"
PKGDIRNAME="debget"

function util_lookup()
{
    # looks for $1 command and tries to download it
    # Sets REPLY variable
    REPLY="`which $1`"
    if [ ! -x "$REPLY" ]; then
        REPLY="$TOOLDIR/usr/bin/$1"
        if [ ! -x "$REPLY" ]; then
            "$CMD_DEBGET" -b /tmp -w "$TOOLDIR" -i $1
            [ $? -ne 0 ] && exit 1
            [ ! -x "$REPLY" ] && echo "Cannot find '$1' executable" && exit 1
        fi
    fi

}

# make absolute
UNIONDIR="`readlink -f \"$UNIONDIR\"`"
ROOTDIR="`readlink -f \"$ROOTDIR\"`"
PKGCACHE="`readlink -f \"$PKGCACHE\"`"
MYDIR="`dirname \"$0\"`"
MYDIR="`readlink -f \"$MYDIR\"`"
TOOLDIR="./tools"
CMD_DEBGET="$MYDIR/debget.sh"

# Setup
[ ! -d "$ROOTDIR"  ] && mkdir -p "$ROOTDIR"
[ ! -d "$UNIONDIR"  ] && mkdir -p "$UNIONDIR"
[ ! -d "$PKGCACHE"  ] && mkdir -p "$PKGCACHE"
[ ! -d "$ROOTDIR/$PKGDIRNAME"  ] && mkdir -p "$ROOTDIR/$PKGDIRNAME"
[ ! -d "$TOOLDIR" ] && mkdir -p "$TOOLDIR"

# Additional deps
util_lookup 'unionfs-fuse'
CMD_UNIONFS="$REPLY"
util_lookup 'proot'
CMD_PROOT="`readlink -f \"$REPLY\"`"

mkdir -p "$ROOTDIR/usr/bin"
touch "$ROOTDIR/usr/bin/debget"
diff "$CMD_DEBGET" "$ROOTDIR/usr/bin/debget" >/dev/null
if [ $? -ne 0 ]; then
    # Install debget
    cp "$CMD_DEBGET" "$ROOTDIR/usr/bin/debget"
    chmod +x "$ROOTDIR/usr/bin/debget"
fi

# Mount the union
grep "$UNIONDIR" /etc/mtab >/dev/null
[ $? -eq 0 ] && fusermount -u "$UNIONDIR"
"$CMD_UNIONFS" "$ROOTDIR"=RW:/=RO "$UNIONDIR"
[ $? -ne 0 ] && exit 1

# make user-changes-directory available at /sysroot
# make package cache available at /debget/_pool
cd /
"$CMD_PROOT" -r "$UNIONDIR"\
    -b "$ROOTDIR":/sysroot\
    -b "$PKGCACHE":/debget/_pool\
    -b "/dev":/dev\
    -b "/sys":/sys\
    -b "/tmp":/tmp\
    -b "/proc":/proc\
    /bin/bash

# Umount
fusermount -u "$UNIONDIR"
rmdir "$UNIONDIR"
