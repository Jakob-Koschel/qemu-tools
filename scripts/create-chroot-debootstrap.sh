#!/usr/bin/env bash
# Copyright 2016 syzkaller project authors. All rights reserved.
# Use of this source code is governed by Apache 2 LICENSE that can be found in the LICENSE file.

# create-chroot.sh creates a minimal Debian Linux image.

set -eux

if [ -z "$CHROOT" ]; then
  echo "CHROOT need to be set!"
  exit 1
fi

# Variables affected by options
ARCH=$(uname -m)
DISTRIBUTION=debian
RELEASE=bullseye
FEATURE=minimal
MIRROR=http://deb.debian.org/debian/

# Display help function
display_help() {
    echo "Usage: $0 [option...] " >&2
    echo
    echo "   -a, --arch                 Set architecture"
    echo "   -d, --distribution         Set which distribution (ubuntu/debian) to create"
    echo "   -r, --release              Set which release to create"
    echo "   -f, --feature              Check what packages to install in the image, options are minimal, full"
    echo "   -h, --help                 Display help message"
    echo
}

while true; do
    if [ $# -eq 0 ];then
	echo $#
	break
    fi
    case "$1" in
        -h | --help)
            display_help
            exit 0
            ;;
        -a | --arch)
	    ARCH=$2
            shift 2
            ;;
        -d | --distribution)
	    DISTRIBUTION=$2
            shift 2
            ;;
        -r | --release)
	    RELEASE=$2
            shift 2
            ;;
        -f | --feature)
	    FEATURE=$2
            shift 2
            ;;
        -*)
            echo "Error: Unknown option: $1" >&2
            exit 1
            ;;
        *)  # No more options
            break
            ;;
    esac
done

# Handle cases where qemu and Debian use different arch names
case "$ARCH" in
    arm64)
        ARCH=aarch64
        DEBARCH=arm64
        ;;
    x86_64)
        DEBARCH=amd64
        ;;
    *)
        DEBARCH=$ARCH
        ;;
esac

case "$DISTRIBUTION" in
    ubuntu)
        if [ "$DEBARCH" == amd64 ]; then
            MIRROR=http://archive.ubuntu.com/ubuntu/
        else
            MIRROR=http://ports.ubuntu.com/ubuntu-ports
        fi
        ;;
    debian)
        MIRROR=http://deb.debian.org/debian/
        ;;
    *)
        echo "unknown distribution"
        exit 1
        ;;
esac

# Create a minimal Debian distribution in a directory.
PREINSTALL_PKGS=openssh-server,curl,tar,time,strace,sudo,less,make,git,vim,tmux

# Foreign architecture

FOREIGN=false
if [ $ARCH != $(uname -m) ]; then
    # i386 on an x86_64 host is exempted, as we can run i386 binaries natively
    if [ $ARCH != "i386" -o $(uname -m) != "x86_64" ]; then
        FOREIGN=true
    fi
fi

if [ $FOREIGN = "true" ]; then
    # Check for according qemu static binary
    if ! which qemu-$ARCH-static; then
        echo "Please install qemu static binary for architecture $ARCH (package 'qemu-user-static' on Debian/Ubuntu/Fedora)"
        exit 1
    fi
    # Check for according binfmt entry
    if [ ! -r /proc/sys/fs/binfmt_misc/qemu-$ARCH ]; then
        echo "binfmt entry /proc/sys/fs/binfmt_misc/qemu-$ARCH does not exist"
        exit 1
    fi
fi

ADD_PACKAGES="${ADD_PACKAGES:-}"
PREINSTALL_PKGS=$PREINSTALL_PKGS","$ADD_PACKAGES

sudo rm -rf $CHROOT
sudo mkdir -p $CHROOT
sudo chmod 0755 $CHROOT

# 1. debootstrap stage

COMPONENTS="main,contrib,non-free"
if [ "$DISTRIBUTION" == ubuntu ]; then
    COMPONENTS="$COMPONENTS,universe"
fi
DEBOOTSTRAP_PARAMS="--arch=$DEBARCH --include=$PREINSTALL_PKGS --components=$COMPONENTS $RELEASE $CHROOT"
if [ $FOREIGN = "true" ]; then
    DEBOOTSTRAP_PARAMS="--foreign $DEBOOTSTRAP_PARAMS"
fi

sudo debootstrap $DEBOOTSTRAP_PARAMS $MIRROR

# 2. debootstrap stage: only necessary if target != host architecture

if [ $FOREIGN = "true" ]; then
    sudo cp $(which qemu-$ARCH-static) $CHROOT/$(which qemu-$ARCH-static)
    sudo chroot $CHROOT /bin/bash -c "/debootstrap/debootstrap --second-stage"
fi
