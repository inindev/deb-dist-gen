#!/bin/sh


# Copyright (C) 2023, John Clark <inindev@gmail.com>

set -e

main() {
    local params='
      DEB_DIST: bookworm
      HOSTNAME: rock4cp-arm64
      DTB_FILE: rk3399-rock-pi-4c-plus.dtb
      REL_URL:  https://github.com/inindev/rockpi-4c-plus/releases/download/v12.0
      FIRMWARE: rockchip rtl_nic brcm/brcmfmac43455-sdio.AW-CM256SM.txt cypress/cyfmac43455-sdio.*
    '

    local outdir='target_rock-4cp'
    local outfile="$outdir/make_debian_img.sh"

    echo "generating $outdir"
    rm -rf "$outdir"
    mkdir -p "$outdir/files"

    local script scripts='header main disk file_fstab file_apt_sources file_wpa_supplicant_conf file_locale_cfg download is_param check_installed text root_check footer'
    for script in $scripts; do
        cat "scripts/$script.sh" >> "$outfile"
    done

    cp 'files/dtb_cp' 'files/dtb_rm' 'files/mk_extlinux' 'files/rc.local' "$outdir/files"

    # device tree and bluetooth firmware
    sed -i "/setup media/e cat files/rock-4cp_fw-dtb-1.cfg" "$outfile"
    sed -i '/xavf "$lfw"/r files/rock-4cp_fw-dtb-2.cfg' "$outfile"

    process_params "$params" "$outfile"
}

process_params() {
    local params="$1"
    local outfile="$2"

    # apply substitutions
    params="$(echo "$params" | sed -e '/^[[:blank:]]*$/d' -e 's/:[[:blank:]]\+/|/')"
    local param key value
    echo "$params" | while read param; do
        key=$(echo "$param" | sed 's/|.*//')
        val=$(echo "$param" | sed 's/.*|//')
        case "$key" in
          DTB_FILE)
            process_dtb "$val" "$outfile" ;;
          FIRMWARE)
            process_firmware "$val" "$outfile" ;;
          *)
            sed -i "s|<$key>|$val|g" "$outfile" ;;
        esac
    done
}

process_dtb() {
    local dtb_file="$1"
    local outfile="$2"

    local outdir="$(dirname "$outfile")"
    local file files='dtb_cp dtb_rm mk_extlinux'
    for file in $files; do
        sed -i "s|<DTB_FILE>|$dtb_file|g" "$outdir/files/$file"
    done
}

process_firmware() {
    local fw_files="$1"
    local outfile="$2"

    local fw_file fw_list
    for fw_file in $fw_files; do
        fw_list="$fw_list \"\$lfwbn/$fw_file\""
    done
    sed -i "s| <FIRMWARE>|$fw_list|" "$outfile"
}


main "$@"

