#!/usr/bin/env bash

set -e

if [[ -z "$IMAGE" || -z "$MNT" ]]; then
  echo "IMAGE and MNT need to be set!"
  exit 1
fi

LOOP_DEV=$(sudo losetup --show -f $IMAGE)
LOOP_PARTITION=${LOOP_DEV}p1

echo "LOOP_DEV: $LOOP_DEV"

sudo partprobe $LOOP_DEV

mkdir -p $MNT
sudo mount $LOOP_PARTITION $MNT

if [ -z "$COMMAND" ]; then
  echo "Press any key to continue"
  read
else
  echo "run: $COMMAND"
  eval $COMMAND
  # sometimes the device is still busy shortly after, breaking the umount
  sleep 1
fi

sudo umount $MNT
sudo losetup -d $LOOP_DEV

rm -rf $MNT
