#!/bin/sh

# Copyright (C) 2023, John Clark <inindev@gmail.com>

set -e

main() {
    local outdir='target_nanopi-r5'
    echo "generating $outdir"
    rm -rf "$outdir"
    mkdir -p "$outdir"

    local outfile="$outdir/make_dtb.sh"
    local script scripts='header main cp_to_debian is_param check_installed text footer'
    for script in $scripts; do
        cat "scripts/$script.sh" >> "$outfile"
    done

    cp -r 'patches_nanopi-r5' "$outdir/patches"

    local linux_latest="$(wget -qO - 'https://cdn.kernel.org/pub/linux/kernel/v6.x/sha256sums.asc' | grep 'linux.*tar\.xz' | sort -Vk2 | tail -n1)"
    local linux_txz="${linux_latest#*  }"
    local linux_url="https://cdn.kernel.org/pub/linux/kernel/v6.x/$linux_txz"
    local linux_sha="${linux_latest%  *}"
    sed -i "s|<LINUX_URL>|$linux_url|" "$outfile"
    sed -i "s|<LINUX_SHA>|$linux_sha|" "$outfile"

    local dts_files='rk3568-nanopi-r5c rk3568-nanopi-r5s'
    sed -i "s|<DTS_FILES>|$dts_files|" "$outfile"

    local dts_links='rk3568-nanopi-r5s.dts rk3568-nanopi-r5c.dts rk3568-nanopi-r5s.dtsi rk3568.dtsi rk356x.dtsi rk3568-pinctrl.dtsi rockchip-pinconf.dtsi'
    sed -i "s|<DTS_LINKS>|$dts_links|" "$outfile"
}


cd "$(dirname "$(realpath "$0")")"
main "$@"

