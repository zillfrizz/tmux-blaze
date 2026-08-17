#!/usr/bin/env bash
export rootState="$HOME/.local/share/tmux-blaze"
rootCode="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
export modConcern="$rootCode"/concern.sh
export modSurface="$rootCode"/surface.sh
export modProject="$rootCode"/project.sh
export modBlaze="$rootCode"/blaze.sh
export modConfig="$rootCode"/config.sh
