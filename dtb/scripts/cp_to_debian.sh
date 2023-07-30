cp_to_debian() {
    local target="$1"
    local deb_dist=$(cat "../debian/make_debian_img.sh" | sed -n 's/\s*local deb_dist=.\([[:alpha:]]\+\)./\1/p')
    [ -z "$deb_dist" ] && return
    local cdir="../debian/cache.$deb_dist"
    echo '\ncopying to debian cache...'
    sudo mkdir -p "$cdir"
    sudo cp -v "$target" "$cdir"
}

