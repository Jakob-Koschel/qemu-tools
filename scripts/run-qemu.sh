#!/usr/bin/env bash

# KERNEL="$HOME/Developer/linux/master"
# KERNEL="${KERNEL}/arch/x86/boot/bzImage"
# APPEND="console=ttyS0 nokaslr nosmp maxcpus=1 rcu_nocbs=0 nmi_watchdog=0 ignore_loglevel modules=sd-mod,usb-storage,ext4 rootfstype=ext4 earlyprintk=serial"
MEMORY="8192"

if [ $ARCH = x86_64 ]; then
  QEMU_SYSTEM_x86_64="${QEMU_SYSTEM_x86_64:=qemu-system-x86_64}"
  QEMU_CPU="${QEMU_CPU:=qemu64,+smep,+smap}"
  BIOS="$PWD/out/OVMF.fd"
elif [ $ARCH = aarch64 ]; then
  QEMU_SYSTEM_x86_64="${QEMU_SYSTEM_x86_64:=qemu-system-aarch64}"
  QEMU_CPU="${QEMU_CPU:=max}"
  QEMU_MACHINE="${QEMU_MACHINE:=virt}"
  BIOS="/usr/share/qemu-efi-aarch64/QEMU_EFI.fd"
fi

DRIVE="file=./${IMAGE},format=raw"
# APPEND="${APPEND} root=/dev/sda2"

if [ -n "${ENABLE_SGX}" ]; then
  QEMU_CPU="host,+sgx-provisionkey"
  SGX_EPC="-object memory-backend-epc,id=mem1,size=64M,prealloc=on \
           -M sgx-epc.0.memdev=mem1,sgx-epc.0.node=0"
  QEMU_SYSTEM_x86_64="sudo $QEMU_SYSTEM_x86_64"
fi

set -x

$QEMU_SYSTEM_x86_64 \
  ${BIOS:+ -bios ${BIOS}} \
  ${KERNEL:+ -kernel "${KERNEL}"} \
  ${INITRD:+ -initrd "${INITRD}"} \
  ${APPEND:+ -append "${APPEND}"} \
  ${DRIVE:+ -drive "${DRIVE}"} \
  ${QEMU_NET_DEVICE:+ -device "${QEMU_NET_DEVICE}"} \
  ${QEMU_NETDEV:+ -netdev "${QEMU_NETDEV}${QEMU_SSH_PORT:+,hostfwd=tcp::${QEMU_SSH_PORT}-:22}"} \
  ${HDA:+ -hda "${HDA}"} \
  ${ATTACH_GDB:+ -gdb tcp::${GDB_PORT}} \
  ${ATTACH_GDB:+ -S} \
  ${ENABLE_KVM:+ -enable-kvm} \
  ${QEMU_MACHINE:+ -machine ${QEMU_MACHINE}} \
  -display none \
  -nographic \
  -smp 1 \
  ${QEMU_CPU:+ -cpu ${QEMU_CPU}} \
  ${SGX_EPC} \
  ${QEMU_9P_SHARED_FOLDER:+ -fsdev local,id=test_dev,path=${QEMU_9P_SHARED_FOLDER},security_model=none} \
  ${QEMU_9P_SHARED_FOLDER:+ -device virtio-9p-pci,fsdev=test_dev,mount_tag=test_mount} \
  -m ${MEMORY} \
  -echr 17 \
  -serial mon:stdio \
  -snapshot \
  -no-reboot

# to mount 9p inside qemu:
# mkdir -p /tmp/shared
# mount -t 9p -o trans=virtio test_mount /tmp/shared/ -oversion=9p2000.L,posixacl,msize=104857600,cache=loose
