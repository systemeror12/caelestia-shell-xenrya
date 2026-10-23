#!/usr/bin/env bash

set -Eeuo pipefail

# Prepare a linked worktree's private build/ for linting and scripts/test-shell.sh.
# T3 Code runs this when it creates a worktree for a new thread.

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
build_dir="$repo_root/build"

# The main checkout is the live shell's config, and its build/ installs the
# plugin the live shell loads. Leave its configuration alone.
if [[ ! -f $repo_root/.git ]]; then
    printf 'Refusing to reconfigure the main checkout: %s\n' "$repo_root" >&2
    printf 'Run this script from a linked worktree.\n' >&2
    exit 64
fi

# Install into build/ so a stray `cmake --install` cannot replace the plugin the
# live shell loads from ~/.local. Precompiled headers add about 2.6 GB per
# worktree without making a clean build faster.
cmake -S "$repo_root" -B "$build_dir" -G Ninja \
    -DCMAKE_BUILD_TYPE=RelWithDebInfo \
    -DCMAKE_DISABLE_PRECOMPILE_HEADERS=ON \
    -DCMAKE_INSTALL_PREFIX="$build_dir/install"
cmake --build "$build_dir"
