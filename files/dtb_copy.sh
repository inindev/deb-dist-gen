#!/bin/sh -e

# Copyright (C) 2023, John Clark <inindev@gmail.com>

# kernel post-install hook: /etc/kernel/postinst.d
# script to copy the specified dtb file to /boot
# after a new kernel is package installed

version="$1"
source1="/usr/lib/linux-image-${version}/rockchip/<DTB_FILE>"
source2="/boot/<DTB_FILE>"
target="/boot/<DTB_FILE>-${version}"

# passing the kernel version is required
if [ -z "${version}" ]; then
	echo >&2 "dtb_copy.sh: ${DPKG_MAINTSCRIPT_PACKAGE:-kernel package} did not pass a version number"
	exit 2
fi

if [ -f "${source1}" ]; then
	echo "dtb_copy.sh: installing ${source1} to ${target}"
	install -m 644 "${source1}" "${target}"
elif [ -f "${source2}" ]; then
	echo "dtb_copy.sh: linking ${source2} to ${target}"
	ln -sfv "${source2}" "${target}"
else
	echo >&2 "dtb_copy: neither ${source1} nor ${source2} not found"
	exit 3
fi

