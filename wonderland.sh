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

function usage()
{
	echo "Usage: `basename $0` [options]";
	echo "Options:";
	echo -e " -h\t\tshow this help";
	echo -e " -b [res] [pat]\tadd proot bind option: system [res] available at [pat]";
	exit 1
}

function add_proot_bind()
{
    # $1 : resource relative path
    # $2 : bind point | null -> same path

    res="`readlink -f \"$1\"`"
    if [ ! -z "$2" ]; then
        bpoint="$2"
    else
        bpoint="$res"
    fi

    if [ ! -e "$res" ]; then
        echo "Resource '$res' not found"
        exit 1
    fi
    BINDINGS="$BINDINGS -b $res:$bpoint"
}

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

# parse parameters
while [ ! -z "$1" ]; do
	case "$1" in
	-h) usage
		;;
	-b) [ -z "$2" -o -z "$3" ] && usage
		res="$2"
		to="$3"
        add_proot_bind "$2" "$3"
		shift
		shift
		;;
	*) 	usage
	esac
	shift
done

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

# System bindings - their modifications will affect actual system filesystem
add_proot_bind /dev
add_proot_bind /tmp
add_proot_bind /proc
add_proot_bind /sys
add_proot_bind /run

# Additional bound points
add_proot_bind "$ROOTDIR" /sysroot
add_proot_bind "$PKGCACHE" /debget/_pool

# Mount the union
grep "$UNIONDIR" /etc/mtab >/dev/null
[ $? -eq 0 ] && fusermount -u "$UNIONDIR"
"$CMD_UNIONFS" -o cow "$ROOTDIR"=RW:/=RO "$UNIONDIR"
[ $? -ne 0 ] && exit 1

# Enter the jail
cd /
"$CMD_PROOT" -r "$UNIONDIR" $BINDINGS /bin/bash

# Umount
fusermount -u "$UNIONDIR"
rmdir "$UNIONDIR"
