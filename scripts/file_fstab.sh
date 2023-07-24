file_fstab() {
    local uuid="$1"

    cat <<-EOF
	# if editing the device name for the root entry, it is necessary
	# to regenerate the extlinux.conf file by running /boot/mk_extlinux

	# <device>					<mount>	<type>	<options>		<dump> <pass>
	UUID=$uuid	/	ext4	errors=remount-ro	0      1
	EOF
}

