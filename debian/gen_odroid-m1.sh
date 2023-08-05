#!/bin/sh

# Copyright (C) 2023, John Clark <inindev@gmail.com>

set -e

main() {
    local params='
      DEB_DIST: bookworm
      HOSTNAME: odroidm1-arm64
      DTB_FILE: rk3568-odroid-m1.dtb
      REL_URL:  https://github.com/inindev/odroid-m1/releases/download/v12.0.1
      FIRMWARE: rockchip rtl_bt rtl_nic
    '

    local outdir='../target_odroid-m1/debian'
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

    process_params "$params" "$outfile"
}

. ./scripts/base.sh

