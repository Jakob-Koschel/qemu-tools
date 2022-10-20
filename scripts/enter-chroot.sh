export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH
export HOME=/root
export TMP=/tmp
export TMPDIR=/tmp

if [ -z "$CHROOT" ]; then
  echo "DIR needs to be set!"
  exit 1
fi

for f in dev dev/pts proc sys ;
do
    if mountpoint -q $CHROOT/$f; then
        echo "$CHROOT/$f already mounted, force unmount? [yN]"
        read answer
        if [ "$answer" != "${answer#[Yy]}" ];
        then
            for f in sys proc dev/pts dev ; do sudo umount -lf $CHROOT/$f ; done
        fi
        exit 0
    else
        sudo mount -o bind /$f $CHROOT/$f ;
    fi
done

if [ -n "$1" ]; then
    # allow executing a range of commands
    cmds=$1
    set -- /bin/bash -l
    echo "chroot $CHROOT \"$@\" -c \"$cmds\""
    sudo chroot $CHROOT "$@" -c "$cmds"
else
    set -- /bin/bash -l
    sudo chroot $CHROOT "$@"
fi

for f in sys proc dev/pts dev ; do sudo umount -lf $CHROOT/$f ; done
