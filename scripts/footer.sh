cd "$(dirname "$(readlink -f "$0")")"
check_mount_only "$@"
main "$@"

