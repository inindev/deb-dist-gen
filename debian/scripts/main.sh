main() {
    # file media is sized with the number between 'mmc_' and '.img'
    #   use 'm' for 1024^2 and 'g' for 1024^3
    local media='mmc_2g.img' # or block device '/dev/sdX'
    local deb_dist='<DEB_DIST>'
    local hostname='<HOSTNAME>'
    local acct_uid='debian'
    local acct_pass='debian'
    local extra_pkgs='curl, pciutils, sudo, unzip, wget, xxd, xz-utils, zip, zstd'

    if is_param 'clean' "$@"; then
        rm -rf cache*/var
        rm -f "$media"*
        rm -rf "$mountpt"
        rm -rf rootfs
        echo '\nclean complete\n'
        exit 0
    fi

    check_installed 'debootstrap' 'wget' 'xz-utils'

    if [ -f "$media" ]; then
        read -p "file $media exists, overwrite? <y/N> " yn
        if ! [ "$yn" = 'y' -o "$yn" = 'Y' -o "$yn" = 'yes' -o "$yn" = 'Yes' ]; then
            echo 'exiting...'
            exit 0
        fi
    fi

    # no compression if disabled or block media
    local compress=$(is_param 'nocomp' "$@" || [ -b "$media" ] && echo false || echo true)

    if $compress && [ -f "$media.xz" ]; then
        read -p "file $media.xz exists, overwrite? <y/N> " yn
        if ! [ "$yn" = 'y' -o "$yn" = 'Y' -o "$yn" = 'yes' -o "$yn" = 'Yes' ]; then
            echo 'exiting...'
            exit 0
        fi
    fi

    print_hdr "downloading files"
    local cache="cache.$deb_dist"

    # linux firmware
    local lfw=$(download "$cache" 'https://mirrors.edge.kernel.org/pub/linux/kernel/firmware/linux-firmware-20230210.tar.xz')
    local lfwsha='6e3d9e8d52cffc4ec0dbe8533a8445328e0524a20f159a5b61c2706f983ce38a'
    [ "$lfwsha" = $(sha256sum "$lfw" | cut -c1-64) ] || { echo "invalid hash for $lfw"; exit 5; }

    # u-boot
    local uboot_spl=$(download "$cache" '<REL_URL>/idbloader.img')
    [ -f "$uboot_spl" ] || { echo "unable to fetch $uboot_spl"; exit 4; }
    local uboot_itb=$(download "$cache" '<REL_URL>/u-boot.itb')
    [ -f "$uboot_itb" ] || { echo "unable to fetch: $uboot_itb"; exit 4; }

    # setup media
    if [ ! -b "$media" ]; then
        print_hdr "creating image file"
        make_image_file "$media"
    fi

    print_hdr "partitioning media"
    parition_media "$media"

    print_hdr "formatting media"
    format_media "$media"

    print_hdr "mounting media"
    mount_media "$media"

    print_hdr "configuring files"
    mkdir "$mountpt/etc"
    echo 'link_in_boot = 1' > "$mountpt/etc/kernel-img.conf"
    echo 'do_symlinks = 0' >> "$mountpt/etc/kernel-img.conf"

    # setup fstab
    local mdev="$(findmnt -no source "$mountpt")"
    local uuid="$(blkid -o value -s UUID "$mdev")"
    echo "$(file_fstab $uuid)\n" > "$mountpt/etc/fstab"

    # setup extlinux boot
    install -Dvm 754 'files/dtb_cp' "$mountpt/etc/kernel/postinst.d/dtb_cp"
    install -Dvm 754 'files/dtb_rm' "$mountpt/etc/kernel/postrm.d/dtb_rm"
    install -Dvm 754 'files/mk_extlinux' "$mountpt/boot/mk_extlinux"
    ln -svf '../../../boot/mk_extlinux' "$mountpt/etc/kernel/postinst.d/update_extlinux"
    ln -svf '../../../boot/mk_extlinux' "$mountpt/etc/kernel/postrm.d/update_extlinux"

    print_hdr "installing firmware"
    mkdir -p "$mountpt/usr/lib/firmware"
    local lfwn=$(basename "$lfw")
    local lfwbn="${lfwn%%.*}"
    tar -C "$mountpt/usr/lib/firmware" --strip-components=1 --wildcards -xavf "$lfw" <FIRMWARE>

    # install debian linux from deb packages (debootstrap)
    print_hdr "installing root filesystem from debian.org"

    # do not write the cache to the image
    mkdir -p "$cache/var/cache" "$cache/var/lib/apt/lists"
    mkdir -p "$mountpt/var/cache" "$mountpt/var/lib/apt/lists"
    mount -o bind "$cache/var/cache" "$mountpt/var/cache"
    mount -o bind "$cache/var/lib/apt/lists" "$mountpt/var/lib/apt/lists"

    local pkgs="linux-image-arm64, dbus, dhcpcd, libpam-systemd, openssh-server, systemd-timesyncd"
    pkgs="$pkgs, wireless-regdb, wpasupplicant"
    pkgs="$pkgs, $extra_pkgs"
    debootstrap --arch arm64 --include "$pkgs" --exclude "isc-dhcp-client" "$deb_dist" "$mountpt" 'https://deb.debian.org/debian/'

    umount "$mountpt/var/cache"
    umount "$mountpt/var/lib/apt/lists"

    # apt sources & default locale
    echo "$(file_apt_sources $deb_dist)\n" > "$mountpt/etc/apt/sources.list"
    echo "$(file_locale_cfg)\n" > "$mountpt/etc/default/locale"

    # wpa supplicant
    rm -rfv "$mountpt/etc/systemd/system/multi-user.target.wants/wpa_supplicant.service"
    echo "$(file_wpa_supplicant_conf)\n" > "$mountpt/etc/wpa_supplicant/wpa_supplicant.conf"
    cp -v "$mountpt/usr/share/dhcpcd/hooks/10-wpa_supplicant" "$mountpt/usr/lib/dhcpcd/dhcpcd-hooks"

    # enable ll alias
    sed -i '/alias.ll=/s/^#*\s*//' "$mountpt/etc/skel/.bashrc"
    sed -i '/export.LS_OPTIONS/s/^#*\s*//' "$mountpt/root/.bashrc"
    sed -i '/eval.*dircolors/s/^#*\s*//' "$mountpt/root/.bashrc"
    sed -i '/alias.l.=/s/^#*\s*//' "$mountpt/root/.bashrc"

    # motd (off by default)
    is_param 'motd' "$@" && [ -f '../etc/motd' ] && cp -f '../etc/motd' "$mountpt/etc"

    # hostname
    echo $hostname > "$mountpt/etc/hostname"
    sed -i "s/127.0.0.1\tlocalhost/127.0.0.1\tlocalhost\n127.0.1.1\t$hostname/" "$mountpt/etc/hosts"

    print_hdr "creating user account"
    chroot "$mountpt" /usr/sbin/useradd -m "$acct_uid" -s '/bin/bash'
    chroot "$mountpt" /bin/sh -c "/usr/bin/echo $acct_uid:$acct_pass | /usr/sbin/chpasswd -c YESCRYPT"
    chroot "$mountpt" /usr/bin/passwd -e "$acct_uid"
    (umask 377 && echo "$acct_uid ALL=(ALL) NOPASSWD: ALL" > "$mountpt/etc/sudoers.d/$acct_uid")

    print_hdr "installing rootfs expansion script to /etc/rc.local"
    install -Dvm 754 'files/rc.local' "$mountpt/etc/rc.local"

    # disable sshd until after keys are regenerated on first boot
    rm -fv "$mountpt/etc/systemd/system/sshd.service"
    rm -fv "$mountpt/etc/systemd/system/multi-user.target.wants/ssh.service"
    rm -fv "$mountpt/etc/ssh/ssh_host_"*

    # generate machine id on first boot
    rm -fv "$mountpt/etc/machine-id"

    # reduce entropy on non-block media
    [ -b "$media" ] || fstrim -v "$mountpt"

    umount "$mountpt"
    rm -rf "$mountpt"

    print_hdr "installing u-boot"
    dd bs=4K seek=8 if="$uboot_spl" of="$media" conv=notrunc
    dd bs=4K seek=2048 if="$uboot_itb" of="$media" conv=notrunc,fsync

    if $compress; then
        print_hdr "compressing image file"
        xz -z8v "$media"
        echo "\n${cya}compressed image is now ready${rst}"
        echo "\n${cya}copy image to target media:${rst}"
        echo "  ${cya}sudo sh -c 'xzcat $media.xz > /dev/sdX && sync'${rst}"
    elif [ -b "$media" ]; then
        echo "\n${cya}media is now ready${rst}"
    else
        echo "\n${cya}image is now ready${rst}"
        echo "\n${cya}copy image to media:${rst}"
        echo "  ${cya}sudo sh -c 'cat $media > /dev/sdX && sync'${rst}"
    fi
    echo
}

