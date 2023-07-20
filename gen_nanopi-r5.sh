#!/bin/sh


# Copyright (C) 2023, John Clark <inindev@gmail.com>

set -e

main() {
    for model in 'r5c' 'r5s'; do
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
    local outfile="$outdir/make_debian_img_${model}.sh"

    echo "generating $outdir"
    rm -rf "$outdir"
    mkdir -p "$outdir/files"

    local scripts='header main disk file_fstab file_apt_sources file_wpa_supplicant_conf file_locale_cfg download is_param check_installed text root_check footer'
    for script in $scripts; do
        cat "scripts/$script.sh" >> "$outfile"
    done

    cp 'files/dtb_copy.sh' 'files/dtb_rm.sh' 'files/mk_extlinux.sh' "$outdir/files"

    # additional network config
    sed "/setup for expand fs/e cat files/network_${model}.cfg" 'files/rc.local' > "$outdir/files/rc.local-${model}"

    # device tree is not in kernel
    sed -i "/setup media/i\    # dtb\n    local dtb=\$(download \"\$cache\" \"\<REL_URL\>/rk3568-nanopi-${model}.dtb\")\n    [ -f \"\$dtb\" ] || { echo \"unable to fetch \$dtb\"; exit 4; }\n" "$outfile"
    sed -i '/setup extlinux boot/i\    # install device tree\n    install -Dm 644 \"\$dtb\" \"\$mountpt/boot/\$dtb\"\n' "$outfile"

    process_params "$params" "$outfile"

    # nanopi uboot files are decorated with model name
    sed -i "s|idbloader.img|idbloader-${model}.img|" "$outfile"
    sed -i "s|u-boot.itb|u-boot-${model}.itb|" "$outfile"
    sed -i "s|files/rc.local|files/rc.local-${model}|" "$outfile"
}

process_params() {
    local params="$1"
    local outfile="$2"

    # apply substitutions
    params="$(echo "$params" | sed -e '/^[[:blank:]]*$/d' -e 's/:[[:blank:]]\+/|/')"
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
    local files='dtb_copy.sh dtb_rm.sh mk_extlinux.sh'
    for file in $files; do
        sed -i "s|<DTB_FILE>|$dtb_file|g" "$outdir/files/$file"
    done
}

process_firmware() {
    local fw_files="$1"
    local outfile="$2"

    local fw_list
    for fw_file in $fw_files; do
        fw_list="$fw_list \"\$lfwbn/$fw_file\""
    done
    sed -i "s| <FIRMWARE>|$fw_list|" "$outfile"
}


main "$@"

