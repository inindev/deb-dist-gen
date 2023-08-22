#!/bin/sh

# Copyright (C) 2023, John Clark <inindev@gmail.com>

set -e

main() {
    local params='
      DEB_DIST: bookworm
      HOSTNAME: rock4cp-arm64
      DTB_FILE: rk3399-rock-4c-plus.dtb
      REL_URL:  https://github.com/inindev/rockpi-4c-plus/releases/download/v12.0
      FIRMWARE: rockchip rtl_nic brcm/brcmfmac43455-sdio.AW-CM256SM.txt cypress/cyfmac43455-sdio.*
    '

    local outdir='../target_rockpi-4c-plus/debian'
    local outfile="$outdir/make_debian_img.sh"

    echo "generating $outdir"
    rm -rf "$outdir"
    mkdir -p "$outdir/files"

    local script scripts='header main disk file_fstab file_apt_sources file_wpa_supplicant_conf file_locale_cfg download is_param check_installed text root_check footer'
    for script in $scripts; do
        cat "scripts/$script.sh" >> "$outfile"
    done

    [ -f extlinux-menu/mk_extlinux ] || git submodule update --init --recursive
    cp 'extlinux-menu/dtb_cp' 'extlinux-menu/dtb_rm' 'extlinux-menu/mk_extlinux' 'configs/rc.local' "$outdir/files"

    # device tree and bluetooth firmware
    sed -i "/setup media/e cat configs/rock-4cp_fw-dtb-1.cfg" "$outfile"
    sed -i '/xavf "$lfw"/r configs/rock-4cp_fw-dtb-2.cfg' "$outfile"

    process_params "$params" "$outfile"
}

. ./scripts/base.sh

