#!/bin/sh

# Copyright (C) 2023, John Clark <inindev@gmail.com>

set -e

main() {
    local model models='r5c r5s'
    for model in $models; do
        main_model "$model"
    done
}

main_model() {
    local model="$1"

    local params="
      DEB_DIST: bookworm
      HOSTNAME: nanopi-${model}-arm64
      DTB_FILE: rk3568-nanopi-${model}.dtb
      REL_URL:  https://github.com/inindev/nanopi-r5/releases/download/v12.0
      FIRMWARE: rockchip rtl_nic
    "

    local outdir="target_nanopi-${model}"
    local outfile="$outdir/make_debian_img.sh"

    echo "generating $outdir"
    rm -rf "$outdir"
    mkdir -p "$outdir/files"

    local script scripts='header main disk file_fstab file_apt_sources file_wpa_supplicant_conf file_locale_cfg download is_param check_installed text root_check footer'
    for script in $scripts; do
        cat "scripts/$script.sh" >> "$outfile"
    done

    [ -f extlinux-menu/mk_extlinux ] || git submodule update --init --recursive
    cp 'extlinux-menu/dtb_cp' 'extlinux-menu/dtb_rm' 'extlinux-menu/mk_extlinux' "$outdir/files"

    # additional network config
    sed "/setup for expand fs/e cat configs/network_${model}.cfg" 'configs/rc.local' > "$outdir/files/rc.local"

    # device tree is not in kernel
    sed -i "/setup media/i\    # dtb\n    local dtb=\$(download \"\$cache\" \"\<REL_URL\>/rk3568-nanopi-${model}.dtb\")\n    [ -f \"\$dtb\" ] || { echo \"unable to fetch \$dtb\"; exit 4; }\n" "$outfile"
    sed -i '/linux from deb packages/i\    # install device tree\n    install -m 644 \"\$dtb\" \"\$mountpt/boot\"\n' "$outfile"

    process_params "$params" "$outfile"

    # nanopi uboot and motd files are decorated with model name
    sed -i "s|idbloader.img|idbloader-${model}.img|" "$outfile"
    sed -i "s|u-boot.itb|u-boot-${model}.itb|" "$outfile"
    sed -i "s|\.\./etc/motd|\.\./etc/motd-${model}|g" "$outfile"
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


cd "$(dirname "$(realpath "$0")")"
main "$@"

