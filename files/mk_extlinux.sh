#!/bin/sh

# Copyright (C) 2023, John Clark <inindev@gmail.com>

set -e

EXTL_MENU_ENABLE='auto'   # true, false, auto
EXTL_MENU_ITEMS=2         # max kernels in menu
EXTL_MENU_TIMEOUT=4       # timeout in seconds
EXLT_CMD_LINE='ro rootwait ipv6.disable=1'


# import release info
if [ -e /etc/os-release ]; then
    . /etc/os-release
elif [ -e /usr/lib/os-release ]; then
    . /usr/lib/os-release
fi

gen_menu_header() {
    local ver_count="$1"

    local mpv=0
    case "${EXTL_MENU_ENABLE}" in
      0|false)
        mpv=0
        ;;
      auto)
        [ ${ver_count} -gt 1 ] && mpv=1
        ;;
      *)
        mpv=1
        ;;
    esac

    echo '#'
    echo '# this is an automatically generated file'
    echo '# edit options at the top of the /boot/mk_extlinux.sh file'
    echo '# then run /boot/mk_extlinux.sh to rebuild'
    echo '#'
    echo
    echo 'menu title u-boot menu'
    echo "prompt ${mpv}"
    echo 'default l0'
    echo "timeout $((EXTL_MENU_TIMEOUT * 10))"
}

gen_menu_item() {
    local num="$1"
    local kver="$2"
    local prms="$3"

    local boot_dir=$([ "$(stat --printf %d /)" -eq "$(stat --printf %d /boot)" ] && echo '/boot')

    echo "label l${num}"
    echo "\tmenu label ${PRETTY_NAME} ${kver}"
    echo "\tlinux ${boot_dir}/vmlinuz-${kver}"
    echo "\tinitrd ${boot_dir}/initrd.img-${kver}"
    echo "\tfdt ${boot_dir}/<DTB_FILE>-${kver}"
    echo "\tappend ${prms}"
}

get_root_dev() {
    local rootdev="$(findmnt -fsno source '/')"
    if [ -z "${rootdev}" ]; then
        rootdev="$(cat /proc/cmdline | sed -re 's/.*root=([^[:space:]]*).*/\1/')"
    fi
    echo "${rootdev}"
}

main() {
    local kvers="$(linux-version list | linux-version sort --reverse | head -n ${EXTL_MENU_ITEMS})"
    local kver_count="$(echo "${kvers}" | wc -w)"

    local config="$(gen_menu_header ${kver_count})\n\n"

    local num=0
    local prms="root=$(get_root_dev) ${EXLT_CMD_LINE}"
    for kver in ${kvers}; do
        local entry="$(gen_menu_item "${num}" "${kver}" "${prms}")"
        num="$((num+1))"
        config="${config}\n${entry}\n"
    done

    mkdir -pv '/boot/extlinux'
    echo "${config}" > '/boot/extlinux/extlinux.conf'
    echo 'file /boot/extlinux/extlinux.conf updated successfully'
}

if [ 0 -ne $(id -u) ]; then
    echo 'this script must be run as root'
    exit 9
fi

main "$@"

