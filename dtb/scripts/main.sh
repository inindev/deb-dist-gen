main() {
    local linux='<LINUX_URL>'
    local lxsha='<LINUX_SHA>'

    local lf="$(basename "$linux")"
    local lv="$(echo "$lf" | sed -nE 's/linux-(.*)\.tar\..z/\1/p')"

    if is_param 'clean' "$@"; then
        rm -f *.dtb *-top.dts
        find . -maxdepth 1 -type l -delete
        rm -rf "linux-$lv"
        echo '\nclean complete\n'
        exit 0
    fi

    check_installed 'device-tree-compiler' 'gcc' 'wget' 'xz-utils'

    [ -f "$lf" ] || wget "$linux"

    if [ "_$lxsha" != "_$(sha256sum "$lf" | cut -c1-64)" ]; then
        echo "invalid hash for linux source file: $lf"
        exit 5
    fi

    local rkpath="linux-$lv/arch/arm64/boot/dts/rockchip"
    if ! [ -d "linux-$lv" ]; then
        tar xavf "$lf" "linux-$lv/include/dt-bindings" "linux-$lv/include/uapi" "$rkpath"

        local patch patches="$(find patches -maxdepth 1 -name '*.patch' 2>/dev/null | sort)"
        for patch in $patches; do
            patch -p1 -d "linux-$lv" -i "../$patch"
        done
    fi

    if is_param 'links' "$@"; then
        local rkf rkfl='<DTS_LINKS>'
        for rkf in $rkfl; do
            ln -sfv "$rkpath/$rkf"
        done
        echo '\nlinks created\n'
        exit 0
    fi

    # build
    local dt dts='<DTS_FILES>'
    local fldtc='-Wno-interrupt_provider -Wno-unique_unit_address -Wno-unit_address_vs_reg -Wno-avoid_unnecessary_addr_size -Wno-alias_paths -Wno-graph_child_address -Wno-simple_bus_reg'
    for dt in $dts; do
        gcc -I "linux-$lv/include" -E -nostdinc -undef -D__DTS__ -x assembler-with-cpp -o "${dt}-top.dts" "$rkpath/${dt}.dts"
        dtc -I dts -O dtb -b 0 ${fldtc} -o "${dt}.dtb" "${dt}-top.dts"
        is_param 'cp' "$@" && cp_to_debian "${dt}.dtb"
        echo "\n${cya}device tree ready: ${dt}.dtb${rst}\n"
    done
}

