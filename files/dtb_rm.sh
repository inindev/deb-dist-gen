#!/bin/sh -e

# Copyright (C) 2023, John Clark <inindev@gmail.com>

# kernel post-remove hook: /etc/kernel/postrm.d
# script to delete the specified dtb file from
# /boot after a kernel is package removed

version="$1"
target="/boot/<DTB_FILE>-${version}"

# passing the kernel version is required
if [ -z "${version}" ]; then
	echo >&2 "dtb_rm.sh: ${DPKG_MAINTSCRIPT_PACKAGE:-kernel package} did not pass a version number"
	exit 2
fi

echo "dtb_rm.sh: cleaning up ${target}"
rm -f "${target}"

