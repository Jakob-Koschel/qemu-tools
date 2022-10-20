#!/usr/bin/env bash

# create-image.sh creates a image based on a chroot environment.

set -eux

IMAGE_SIZE="${IMAGE_SIZE:-2047}"

if [ -z "$CHROOT" ]; then
  echo "CHROOT need to be set!"
  exit 1
fi

# Build a disk image
dd if=/dev/zero of=$IMAGE bs=1M seek=$IMAGE_SIZE count=1

# Set partition table to GPT (UEFI)
parted -s $IMAGE -- mktable gpt

# Create OS partition
parted -s $IMAGE -- mkpart EFI fat16 1MiB 10MiB
parted -s $IMAGE -- set 1 msftdata on

parted -s $IMAGE -- mkpart LINUX ext4 10MiB 100%

# setup loop device
LOOP_DEV=$(sudo losetup --show -f $IMAGE)
LOOP_PARTITION_EFI=${LOOP_DEV}p1
LOOP_PARTITION_LINUX=${LOOP_DEV}p2
sudo partprobe $LOOP_DEV
sudo mkfs.vfat -n EFI ${LOOP_PARTITION_EFI}
sudo mkfs.ext4 -F $LOOP_PARTITION_LINUX

sudo mkdir -p /mnt/$CHROOT
sudo mount -o loop $LOOP_PARTITION_LINUX /mnt/$CHROOT
sudo cp -a $CHROOT/. /mnt/$CHROOT/.
sudo umount /mnt/$CHROOT

sudo losetup -d $LOOP_DEV
