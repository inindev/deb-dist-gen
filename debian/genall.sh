#!/bin/sh

# Copyright (C) 2023, John Clark <inindev@gmail.com>

set -e

cd "$(dirname "$(realpath "$0")")"

for s in gen_*.sh; do
    sh "$s"
done

