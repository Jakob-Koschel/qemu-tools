# qemu-tools

## Dependencies
Install [go-task](https://taskfile.dev/#/installation) as a task-runner.
```
sudo sh -c "$(curl -ssL https://taskfile.dev/install.sh)" -- -d -b ~/.local/bin
```

debootstrap:
```
sudo apt update && sudo apt install debootstrap
```

parted:
```
sudo apt update && sudo apt install parted
```

mkfs.vfat:
```
sudo apt update && sudo apt install dosfstools
```

qemu:
```
sudo apt update && sudo apt install qemu-system-arm qemu-system-x86
```

## Create the image

```
task create-image-arm64 # for an arm64 image
task create-image-x86_64 # for an x86_64 image
```

## Start qemu
```
task qemu-arm64 # for an arm64 image
task qemu-x86_64 # for an x86_64 image
```

## Old info

What is the simplest way to install ubuntu within a qemu image?

1. Create a qcow2 image:
```
qemu-img create -f qcow2 disk.qcow2 30G
```

2. Start qemu to instal Ubuntu on the image (boot menu is enabled to change the order if necessary):
```
qemu-system-x86_64 \
    -echr 17 \
    -nodefaults \
    -smp cpus=4,sockets=1,cores=4,threads=1 \
    -machine q35,vmport=off \
    -m 4096 \
    -name "Ubunut Server x86_64" \
    -vga none \
    -nographic \
    -serial mon:stdio \
    -boot menu=on \
    -cdrom ubuntu-22.04-live-server-amd64.iso \
    -hda ./disk.qcow2
```

3. Follow the instructions to install Ubuntu ;)

4. To start the the Ubuntu machine (simply no boot menu and cdrom anymore):
```
qemu-system-x86_64 \
    -echr 17 \
    -nodefaults \
    -smp cpus=4,sockets=1,cores=4,threads=1 \
    -machine q35,vmport=off \
    -m 4096 \
    -name "Ubunut Server x86_64" \
    -vga none \
    -nographic \
    -serial mon:stdio \
    -hda ./disk.qcow2
```

## Resizing image if necessary:
To resize the qcow2 image:
```
qemu-img resize disk.qcow2 50G
```

Now you still need to increase the size of the partitions & co within the VM:

To list block devices:
```
lsblk
````

To increase the parition (DOUBLE CHECK DEVICE & PARTITON NUMBER):
```
sudo apt install cloud-guest-utils
sudo growpart /dev/sda 3
```

To resize the logical volume (name should also pop up with `df -h`):
```
sudo lvextend -r -l +100%FREE /dev/ubuntu-vg/ubuntu-lv
```
