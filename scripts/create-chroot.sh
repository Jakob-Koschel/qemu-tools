#!/usr/bin/env bash
# Copyright 2016 syzkaller project authors. All rights reserved.
# Use of this source code is governed by Apache 2 LICENSE that can be found in the LICENSE file.

# create-chroot.sh creates a minimal Debian Linux image + modifications.

set -eux

if [ -z "$CHROOT" ] || [-z "$DISTRIBUTION" ] || [ -z "$RELEASE" ] || [ -z "$ARCH" ]; then
  echo "ARCH, CHROOT, DISTRIBUTION and RELEASE need to be set!"
  exit 1
fi

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

scripts/create-chroot-debootstrap.sh --arch $ARCH --distribution $DISTRIBUTION --release $RELEASE

# automatically enable eth0 interface with dhcp
printf '\nauto eth0\niface eth0 inet dhcp\n' | sudo tee -a $CHROOT/etc/network/interfaces

CHROOT_HOSTNAME="${CHROOT_HOSTNAME:-}"
if [ -n "$CHROOT_HOSTNAME" ]; then
    echo $CHROOT_HOSTNAME | sudo tee $CHROOT/etc/hostname
fi

CHROOT_USERNAME="${CHROOT_USERNAME:-}"
if [ -n "$CHROOT_USERNAME" ]; then
    bash scripts/enter-chroot.sh "useradd -m -G sudo -s /bin/bash $CHROOT_USERNAME"
    echo "set password for $CHROOT_USERNAME:"
    bash scripts/enter-chroot.sh "passwd $CHROOT_USERNAME"

    rm out/$CHROOT_USERNAME.id_rsa*
    ssh-keygen -f out/$CHROOT_USERNAME.id_rsa -t rsa -N ''
    sudo mkdir -p $CHROOT/home/$CHROOT_USERNAME/.ssh/
    cat out/$CHROOT_USERNAME.id_rsa.pub | sudo tee $CHROOT/home/$CHROOT_USERNAME/.ssh/authorized_keys
    bash scripts/enter-chroot.sh "chown -R $CHROOT_USERNAME:$CHROOT_USERNAME /home/$CHROOT_USERNAME/.ssh"
else
    echo "set password for root:"
    bash scripts/enter-chroot.sh "passwd root"
fi

