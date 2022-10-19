#!/usr/bin/env bash

# KERNEL="$HOME/Developer/linux/master"
# KERNEL="-kernel ${KERNEL}/arch/x86/boot/bzImage"
# APPEND="console=ttyS0 nokaslr nosmp maxcpus=1 rcu_nocbs=0 nmi_watchdog=0 ignore_loglevel modules=sd-mod,usb-storage,ext4 rootfstype=ext4 earlyprintk=serial"
MEMORY="8192"
QEMU_SYSTEM_x86_64="${QEMU_SYSTEM_x86_64:=qemu-system-x86_64}"
QEMU_CPU="${QEMU_CPU:=qemu64,+smep,+smap}"

HDA="file=./${IMAGE},format=raw"
# APPEND="${APPEND} root=/dev/sda"

if [ -n "${ENABLE_SGX}" ]; then
  QEMU_CPU="host,+sgx-provisionkey"
  SGX_EPC="-object memory-backend-epc,id=mem1,size=64M,prealloc=on \
           -M sgx-epc.0.memdev=mem1,sgx-epc.0.node=0"
  QEMU_SYSTEM_x86_64="sudo $QEMU_SYSTEM_x86_64"
fi

set -x

# 9p:
# -fsdev local,id=test_dev,path=$PWD/shared,security_model=none -device virtio-9p-pci,fsdev=test_dev,mount_tag=test_mount

$QEMU_SYSTEM_x86_64 \
  ${KERNEL:+ "${KERNEL}"} \
  ${APPEND:+ -append "${APPEND}"} \
  ${HDA:+ -drive "${HDA}"} \
  ${ATTACH_GDB:+ -gdb tcp::${GDB_PORT}} \
  ${ATTACH_GDB:+ -S} \
  ${ENABLE_KVM:+ -enable-kvm} \
  -display none \
  -nographic \
  -smp 1 \
  -cpu ${QEMU_CPU} \
  ${SGX_EPC} \
  -m ${MEMORY} \
  -echr 17 \
  -serial mon:stdio \
  -snapshot \
  -no-reboot
