#!/bin/sh

set -e

rm -rf 'target_'*
sh 'debian/genall.sh'
sh 'dtb/genall.sh'

sudo rm -rf 'dists'
mkdir 'dists'

targets='rockpi-4c-plus odroid-m1 nanopi-r5 radxa-e25 rock-5b nanopc-t6'
for target in $targets; do
    git -C 'dists' clone "git@github.com:inindev/$target"
    cp -r "target_$target/"* "dists/$target"
done

