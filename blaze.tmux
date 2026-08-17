#!/usr/bin/env bash
export modGlobals="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)/globals.sh"
source "$modGlobals"
"$modBlaze" reloadConfig
