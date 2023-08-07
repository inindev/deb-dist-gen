#!/bin/sh

# Copyright (C) 2023, John Clark <inindev@gmail.com>

set -e

main() {
    local params='
      DEB_DIST: trixie
      HOSTNAME: nanopc-t6-arm64
      DTB_FILE: rk3588-nanopc-t6.dtb
      REL_URL:  https://github.com/inindev/nanopc-t6/releases/download/v13-6.5-rc5
      FIRMWARE: microchip/mscc* nvidia/tegra??? r8a779x* rockchip rtl_bt rtl_nic
    '

    local outdir='../target_nanopc-t6/debian'
    local outfile="$outdir/make_debian_img.sh"

    echo "generating $outdir"
    rm -rf "$outdir"
    mkdir -p "$outdir/files"

    local script scripts='header main disk file_fstab file_apt_sources file_wpa_supplicant_conf file_locale_cfg download is_param check_installed text root_check footer'
    for script in $scripts; do
        cat "scripts/$script.sh" >> "$outfile"
    done

    cp 'extlinux-menu/dtb_cp' 'extlinux-menu/dtb_rm' 'extlinux-menu/mk_extlinux' 'configs/rc.local' "$outdir/files"

    process_params "$params" "$outfile"

    # remove the kernel by substituting it with initramfs-tools
    sed -i 's/linux-image-arm64/initramfs-tools/' "$outfile"
}

. ./scripts/base.sh

