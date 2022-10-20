#!/usr/bin/env bash
# Copyright 2016 syzkaller project authors. All rights reserved.
# Use of this source code is governed by Apache 2 LICENSE that can be found in the LICENSE file.

# create-chroot.sh creates a minimal Debian Linux image.

set -eux

if [ -z "$CHROOT" ]; then
  echo "CHROOT need to be set!"
  exit 1
fi

# If ADD_PACKAGE is not defined as an external environment variable, use our default packages
if [ -z ${ADD_PACKAGE+x} ]; then
    ADD_PACKAGE="make,git,vim,tmux"
fi

# Variables affected by options
ARCH=$(uname -m)
RELEASE=bullseye
FEATURE=minimal

# Display help function
display_help() {
    echo "Usage: $0 [option...] " >&2
    echo
    echo "   -a, --arch                 Set architecture"
    echo "   -d, --distribution         Set on which debian distribution to create"
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
    ppc64le)
        DEBARCH=ppc64el
        ;;
    aarch64)
        DEBARCH=arm64
        ;;
    arm)
        DEBARCH=armel
        ;;
    x86_64)
        DEBARCH=amd64
        ;;
    *)
        DEBARCH=$ARCH
        ;;
esac

# Create a minimal Debian distribution in a directory.
# PREINSTALL_PKGS=linux-image-amd64,grub-pc
PREINSTALL_PKGS=linux-image-$DEBARCH,grub-efi-$DEBARCH

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

# If full feature is chosen, install more packages
if [ $FEATURE = "full" ]; then
    PREINSTALL_PKGS=$PREINSTALL_PKGS","$ADD_PACKAGE
fi

sudo rm -rf $CHROOT
sudo mkdir -p $CHROOT
sudo chmod 0755 $CHROOT

# 1. debootstrap stage

# TODO allow ubuntu and also think about adding arch-bootstrap for example
DEBOOTSTRAP_PARAMS="--arch=$DEBARCH --include=$PREINSTALL_PKGS --components=main,contrib,non-free $RELEASE $CHROOT"
if [ $FOREIGN = "true" ]; then
    DEBOOTSTRAP_PARAMS="--foreign $DEBOOTSTRAP_PARAMS"
fi

sudo debootstrap $DEBOOTSTRAP_PARAMS

# 2. debootstrap stage: only necessary if target != host architecture

if [ $FOREIGN = "true" ]; then
    sudo cp $(which qemu-$ARCH-static) $CHROOT/$(which qemu-$ARCH-static)
    sudo chroot $CHROOT /bin/bash -c "/debootstrap/debootstrap --second-stage"
fi

# Set some defaults and enable promtless ssh to the machine for root.
# sudo sed -i '/^root/ { s/:x:/::/ }' $CHROOT/etc/passwd
# echo 'T0:23:respawn:/sbin/getty -L ttyS0 115200 vt100' | sudo tee -a $CHROOT/etc/inittab
# printf '\nauto eth0\niface eth0 inet dhcp\n' | sudo tee -a $CHROOT/etc/network/interfaces
# echo -en "127.0.0.1\tlocalhost\n" | sudo tee $CHROOT/etc/hosts
# echo "nameserver 8.8.8.8" | sudo tee -a $CHROOT/etc/resolve.conf
# echo "syzkaller" | sudo tee $CHROOT/etc/hostname

# ssh-keygen -f $RELEASE.id_rsa -t rsa -N ''
# sudo mkdir -p $CHROOT/root/.ssh/
# cat $RELEASE.id_rsa.pub | sudo tee $CHROOT/root/.ssh/authorized_keys
