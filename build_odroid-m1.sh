#!/bin/sh


# Copyright (C) 2023, John Clark <inindev@gmail.com>

set -e

main() {
    local params='
      DEB_DIST: bookworm
      HOSTNAME: odroidm1-arm64
      DTB_FILE: rk3568-odroid-m1.dtb
      REL_URL: https://github.com/inindev/odroid-m1/releases/download/v12.0
    '

    local outdir='target'
    local outfile="$outdir/make_debian_img.sh"

    rm -rf "$outdir"
    mkdir -p "$outdir/files"

    local scripts='header main disk file_fstab file_apt_sources download is_param check_installed text root_check footer'
    for script in $scripts; do
        cat "scripts/$script.sh" >> "$outfile"
    done

    cp files/* "$outdir/files"

    process_params "$params" "$outfile"
}

process_params() {
    local params="$1"
    local outfile="$2"

    # apply substitutions
    params="$(echo "$params" | sed 's/:[[:blank:]]/|/')"
    for param in $params; do
        key=$(echo "$param" | sed 's/|.*//')
        val=$(echo "$param" | sed 's/.*|//')
        if [ 'DTB_FILE' = "$key" ]; then
            process_dtb "$val" "$(dirname "$outfile")/files"
        else
            sed -i "s|<$key>|$val|g" "$outfile"
        fi
    done
}

process_dtb() {
    local dtb_file="$1"
    local outdir="$2"

    local files='dtb_copy dtb_rm mk_extlinux.sh'
    for file in $files; do
        sed -i "s|<DTB_FILE>|$dtb_file|g" "$outdir/$file"
    done
}


main "$@"

