make_image_file() {
    local filename="$1"
    rm -f "$filename"*
    local size="$(echo "$filename" | sed -rn 's/.*mmc_([[:digit:]]+[m|g])\.img$/\1/p')"
    truncate -s "$size" "$filename"
}

parition_media() {
    local media="$1"

    # partition with gpt
    cat <<-EOF | sfdisk "$media"
	label: gpt
	unit: sectors
	first-lba: 2048
	part1: start=32768, type=0FC63DAF-8483-4772-8E79-3D69D8477DE4, name=rootfs
	EOF
    sync
}

format_media() {
    local media="$1"
    local partnum="${2:-1}"

    # create ext4 filesystem
    if [ -b "$media" ]; then
        local rdn="$(basename "$media")"
        local sbpn="$(echo /sys/block/${rdn}/${rdn}*${partnum})"
        local part="/dev/$(basename "$sbpn")"
        mkfs.ext4 -L rootfs -vO metadata_csum_seed "$part" && sync
    else
        local lodev="$(losetup -f)"
        losetup -vP "$lodev" "$media" && sync
        mkfs.ext4 -L rootfs -vO metadata_csum_seed "${lodev}p${partnum}" && sync
        losetup -vd "$lodev" && sync
    fi
}

mount_media() {
    local media="$1"
    local partnum="1"

    if [ -d "$mountpt" ]; then
        echo "cleaning up mount points..."
        mountpoint -q "$mountpt/var/cache" && umount "$mountpt/var/cache"
        mountpoint -q "$mountpt/var/lib/apt/lists" && umount "$mountpt/var/lib/apt/lists"
        mountpoint -q "$mountpt" && umount "$mountpt"
    else
        mkdir -p "$mountpt"
    fi

    local success_msg
    if [ -b "$media" ]; then
        local rdn="$(basename "$media")"
        local sbpn="$(echo /sys/block/${rdn}/${rdn}*${partnum})"
        local part="/dev/$(basename "$sbpn")"
        mount -n "$part" "$mountpt"
        success_msg="partition ${cya}$part${rst} successfully mounted on ${cya}$mountpt${rst}"
    elif [ -f "$media" ]; then
        # hard-coded to p1
        mount -n -o loop,offset=16M "$media" "$mountpt"
        success_msg="media ${cya}$media${rst} partition 1 successfully mounted on ${cya}$mountpt${rst}"
    else
        echo "file not found: $media"
        exit 4
    fi

    if [ ! -d "$mountpt/lost+found" ]; then
        echo 'failed to mount the image file'
        exit 3
    fi

    echo "$success_msg"
}

check_mount_only() {
    local img
    local flag=false
    for item in "$@"; do
        case "$item" in
            mount) flag=true ;;
            *.img) img=$item ;;
            *.img.xz) img=$item ;;
        esac
    done
    ! $flag && return

    if [ ! -f "$img" ]; then
        if [ -z "$img" ]; then
            echo "no image file specified"
        else
            echo "file not found: ${red}$img${rst}"
        fi
        exit 3
    fi

    if [ "$img" = *.xz ]; then
        tmp=$(basename "$img" .xz)
        if [ -f "$tmp" ]; then
            echo "compressed file ${bld}$img${rst} was specified but uncompressed file ${bld}$tmp${rst} exists..."
            echo -n "mount ${bld}$tmp${rst}"
            read -p " instead? <Y/n> " yn
            if ! [ -z "$yn" -o "$yn" = 'y' -o "$yn" = 'Y' -o "$yn" = 'yes' -o "$yn" = 'Yes' ]; then
                echo 'exiting...'
                exit 0
            fi
            img=$tmp
        else
            echo -n "compressed file ${bld}$img${rst} was specified"
            read -p ', decompress to mount? <Y/n>' yn
            if ! [ -z "$yn" -o "$yn" = 'y' -o "$yn" = 'Y' -o "$yn" = 'yes' -o "$yn" = 'Yes' ]; then
                echo 'exiting...'
                exit 0
            fi
            xz -dk "$img"
            img=$(basename "$img" .xz)
        fi
    fi

    echo "mounting file ${yel}$img${rst}..."
    mount_media "$img"
    trap - EXIT INT QUIT ABRT TERM
    echo "media mounted, use ${grn}sudo umount $mountpt${rst} to unmount"

    exit 0
}

# ensure inner mount points get cleaned up
on_exit() {
    if mountpoint -q "$mountpt"; then
        mountpoint -q "$mountpt/var/cache" && umount "$mountpt/var/cache"
        mountpoint -q "$mountpt/var/lib/apt/lists" && umount "$mountpt/var/lib/apt/lists"

        read -p "$mountpt is still mounted, unmount? <Y/n> " yn
        if [ -z "$yn" -o "$yn" = 'y' -o "$yn" = 'Y' -o "$yn" = 'yes' -o "$yn" = 'Yes' ]; then
            echo "unmounting $mountpt"
            umount "$mountpt"
            sync
            rm -rf "$mountpt"
        fi
    fi
}
mountpt='rootfs'
trap on_exit EXIT INT QUIT ABRT TERM

