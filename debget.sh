#!/bin/bash
#
# Emanuele Faranda                                               24-Feb-2015
#
# Package apt dependencies downloader and installer
#

function check_folder_structure()
{
    [ ! -d "$PKGDIR" ] && mkdir "$PKGDIR"
    [ ! -d "$PKGDIR/$PACKAGE" ] && mkdir "$PKGDIR/$PACKAGE"
    [ ! -d "$SYSROOT" ] && mkdir "$SYSROOT"
    [ ! -d "$PKGCACHE" ] && mkdir "$PKGCACHE"
}

function usage()
{
    echo "Usage:" `basename $0` "[options] package"
    echo "Downloads package and dependecies and stores into package cache."
    echo -e "\nOptions:"
    echo -e " -b [d]\tset the base PKGDIR parent directory"
    echo -e " -i\tinstall packages into the system root"
    echo -e " -f\tforce package download even if already existing in cache"
    echo -e " -d\tinstall deb files from existing package cache"
    echo -e " -w [d]\tset installation directory"
    #~ echo -e "\nCurrent configuration:"
    #~ echo -e " PKGDIR\t\t$PKGDIR"
    #~ echo -e " PKGCACHE\t$PKGCACHE"
    #~ echo -e " SYSROOT\t$SYSROOT"
    exit 1
}

function do_download()
{
	DEPS=`apt-get --print-uris --yes install $PACKAGE | grep ^\' | cut -d\' -f2`

	if [[ ! "$DEPS" ]]; then
		echo "Error"
		exit 1
	fi

	for DEP in $DEPS; do
		fname=`basename "$DEP"`
		if [[ ( $DO_FORCE_DOWNLOAD -eq 1 ) || ( ! -e "$PKGCACHE/$fname" ) ]]; then
			echo "Downloading", $fname
			wget $DEP -O "$PKGCACHE/$fname"
		else
			echo "Package '$fname' already exists"
		fi

		# Update link
		ln -sf "$PKGCACHE/$fname" "$PKGDIR/$PACKAGE/$fname"
	done
}

function do_install()
{
	for pack in `ls "$PKGDIR/$PACKAGE"`; do
        echo "Unpacking '$pack'..."
        pkg="$PKGDIR/$PACKAGE/$pack"

        # Do extract deb
        for f in `ar t "$pkg"`; do
            case $f in
                data.tar)
                    ar p "$PKGDIR/$PACKAGE/$pack" data.tar | tar -C "$SYSROOT" -xf -;;
                data.tar.xz)
                    ar p "$PKGDIR/$PACKAGE/$pack" data.tar.xz | tar -C "$SYSROOT" --xz -xf -;;
                data.tar.gz)
                    ar p "$PKGDIR/$PACKAGE/$pack" data.tar.gz | tar -C "$SYSROOT" --gzip -xf -;;
                data.tar.bz2)
                    ar p "$PKGDIR/$PACKAGE/$pack" data.tar.bz2 | tar -C "$SYSROOT" --bzip2 -xf -;;
                data.tar.lzma)
                    ar p "$PKGDIR/$PACKAGE/$pack" data.tar.lzma | tar -C "$SYSROOT" --lzma -xf -;;
            esac
        done
	done
}

DO_DOWNLOAD=1
DO_INSTALL=0
DO_FORCE_DOWNLOAD=0
PACKAGE=
# Default is /
BASEDIR=""

while [[ ! -z "$1" ]]; do
    case "$1" in
    -i)
        DO_INSTALL=1
        ;;
    -f)
        DO_FORCE_DOWNLOAD=1
        ;;
    -d)
        DO_DOWNLOAD=0
        DO_INSTALL=1
        ;;
    -b)
        shift
        [ -z "$1" ] && usage
        BASEDIR="`readlink -f \"$1\"`"
        ;;
    -w)
        shift
        [ -z "$1" ] && usage
        SYSROOT="`readlink -f \"$1\"`"
        ;;
    *)
        [ ! -z "$PACKAGE" ] && usage
        PACKAGE="$1"
    esac
    shift
done
if [[ -z "$PACKAGE" ]]; then
    usage
fi

# The directiory where .deb files are stored
PKGDIR="$BASEDIR/debget"
# The package cache directory
PKGCACHE="$PKGDIR/_pool"
# The root where packages will be installed
[ -z "$SYSROOT" ] && SYSROOT="$BASEDIR/sysroot"

check_folder_structure
[ $DO_DOWNLOAD -eq 1 ] && do_download
[ $DO_INSTALL -eq 1 ] && do_install
