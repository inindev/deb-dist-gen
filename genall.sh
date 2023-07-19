#!/bin/sh


# Copyright (C) 2023, John Clark <inindev@gmail.com>

set -e

for s in gen_*.sh; do
    sh "$s"
done

