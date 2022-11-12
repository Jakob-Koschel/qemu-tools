#!/usr/bin/env bash

# KERNEL="$HOME/Developer/linux/master"
# KERNEL="${KERNEL}/arch/x86/boot/bzImage"
# KERNEL="vmlinuz"
# INITRD="initrd.img"
# APPEND="console=ttyS0 nokaslr nosmp maxcpus=1 rcu_nocbs=0 nmi_watchdog=0 ignore_loglevel modules=sd-mod,usb-storage,ext4 rootfstype=ext4 earlyprintk=serial net.ifnames=0"

if [ $(uname -m) != $ARCH ]; then
  # disable ACCEL if running different architecture
  unset ENABLE_ACCEL
fi

if [ -n "$ENABLE_ACCEL" ]; then
  # use the host cpu if accel is enabled
  QEMU_CPU=${QEMU_CPU:-host}
fi

if [ "$(uname)" == "Darwin" ]; then
  if [ -n "$ENABLE_ACCEL" ]; then ACCEL="hvf"; fi
  if [ -n "$ENABLE_EFI" ]; then
    if [ $ARCH = x86_64 ]; then
      # wget https://www.kraxel.org/repos/jenkins/edk2/edk2.git-ovmf-x64-0-20220719.209.gf0064ac3af.EOL.no.nore.updates.noarch.rpm
      # mkdir -p out/edk2.ovmf.x64
      # tar -xf edk2.git-ovmf-x64-0-20220719.209.gf0064ac3af.EOL.no.nore.updates.noarch.rpm -C out/edk2.ovmf.x64
      QEMU_BIOS="$PWD/out/edk2.ovmf.x64/usr/share/edk2.git/ovmf-x64/OVMF_CODE-pure-efi.fd"
    elif [ $ARCH = arm64 ]; then
      QEMU_BIOS=${QEMU_BIOS:-"/opt/homebrew/share/qemu/edk2-aarch64-code.fd"}
    fi
  fi
elif [ "$(expr substr $(uname -s) 1 5)" == "Linux" ]; then
  if [ -n "$ENABLE_ACCEL" ]; then ACCEL="kvm"; fi
  if [ -n "$ENABLE_EFI" ]; then
    if [ $ARCH = x86_64 ]; then
      QEMU_BIOS=${QEMU_BIOS:-"/usr/share/ovmf/OVMF.fd"}
    elif [ $ARCH = arm64 ]; then
      QEMU_BIOS=${QEMU_BIOS:-"/usr/share/qemu-efi-aarch64/QEMU_EFI.fd"}
    fi
  fi
else
  echo "unsupported host"
  exit 1
fi

if [ $ARCH = x86_64 ]; then
  QEMU_SYSTEM="${QEMU_SYSTEM:=qemu-system-x86_64}"
  QEMU_CPU="${QEMU_CPU:=qemu64,+smep,+smap}"
elif [ $ARCH = arm64 ]; then
  QEMU_SYSTEM="${QEMU_SYSTEM:=qemu-system-aarch64}"
  QEMU_CPU="${QEMU_CPU:=max}"
  QEMU_MACHINE="${QEMU_MACHINE:=virt}"
fi

DRIVE="file=./${IMAGE},format=raw"
# APPEND="${APPEND} root=/dev/sda2"

if [ -n "${ENABLE_SGX}" ]; then
  QEMU_CPU="host,+sgx-provisionkey"
  SGX_EPC="-object memory-backend-epc,id=mem1,size=64M,prealloc=on \
           -M sgx-epc.0.memdev=mem1,sgx-epc.0.node=0"
  QEMU_SYSTEM="sudo $QEMU_SYSTEM"
fi

set -x

$QEMU_SYSTEM \
  ${ACCEL:+ -accel ${ACCEL}} \
  ${QEMU_BIOS:+ -bios ${QEMU_BIOS}} \
  ${KERNEL:+ -kernel "${KERNEL}"} \
  ${INITRD:+ -initrd "${INITRD}"} \
  ${APPEND:+ -append "${APPEND}"} \
  ${DRIVE:+ -drive "${DRIVE}"} \
  ${QEMU_NET_DEVICE:+ -device "${QEMU_NET_DEVICE}"} \
  ${QEMU_NETDEV:+ -netdev "${QEMU_NETDEV}${QEMU_SSH_PORT:+,hostfwd=tcp::${QEMU_SSH_PORT}-:22}"} \
  ${HDA:+ -hda "${HDA}"} \
  ${ATTACH_GDB:+ -gdb tcp::${GDB_PORT}} \
  ${ATTACH_GDB:+ -S} \
  ${QEMU_MACHINE:+ -machine ${QEMU_MACHINE}} \
  -display none \
  -nographic \
  -smp ${QEMU_CORES:-1} \
  ${QEMU_CPU:+ -cpu ${QEMU_CPU}} \
  ${SGX_EPC} \
  ${QEMU_9P_SHARED_FOLDER:+ -fsdev local,id=test_dev,path=${QEMU_9P_SHARED_FOLDER},security_model=none} \
  ${QEMU_9P_SHARED_FOLDER:+ -device virtio-9p-pci,fsdev=test_dev,mount_tag=test_mount} \
  -m ${QEMU_MEMORY:-4096} \
  -echr 17 \
  -serial mon:stdio \
  ${ENABLE_SNAPSHOT:+ -snapshot} \
  -no-reboot

# to mount 9p inside qemu:
# mkdir -p /tmp/shared
# mount -t 9p -o trans=virtio test_mount /tmp/shared/ -oversion=9p2000.L,posixacl,msize=104857600,cache=loose
