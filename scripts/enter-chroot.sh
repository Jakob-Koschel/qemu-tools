export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH
export HOME=/root
export TMP=/tmp
export TMPDIR=/tmp

if [ -z "$DIR" ]; then
  echo "DIR needs to be set!"
  exit 1
fi

for f in dev dev/pts proc sys ;
do
    if mountpoint -q $DIR/$f; then
        echo "$DIR/$f already mounted, force unmount? [yN]"
        read answer
        if [ "$answer" != "${answer#[Yy]}" ];
        then
            for f in sys proc dev/pts dev ; do sudo umount -lf $DIR/$f ; done
        fi
        exit 0
    else
        sudo mount -o bind /$f $DIR/$f ;
    fi
done

if [ -n "$1" ]; then
    # allow executing a range of commands
    cmds=$1
    set -- /bin/bash -l
    echo "chroot $DIR \"$@\" -c \"$cmds\""
    sudo chroot $DIR "$@" -c "$cmds"
else
    set -- /bin/bash -l
    sudo chroot $DIR "$@"
fi

for f in sys proc dev/pts dev ; do sudo umount -lf $DIR/$f ; done
