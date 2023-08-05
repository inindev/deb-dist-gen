#!/bin/sh

# Copyright (C) 2023, John Clark <inindev@gmail.com>

set -e

main() {
    local params='
      DEB_DIST: trixie
      HOSTNAME: rock5b-arm64
      DTB_FILE: rk3588-rock-5b.dtb
      REL_URL:  https://github.com/inindev/rock-5b/releases/download/v12.0-6.5-rc1
      FIRMWARE: microchip/mscc* nvidia/tegra??? r8a779x* rockchip rtl_bt rtl_nic
    '

    local outdir='../target_rock-5b/debian'
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

