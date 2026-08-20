#!/bin/zsh

set -euo pipefail

script_directory="${0:A:h}"
repository_root="${script_directory:h}"
module_cache="${repository_root}/.build/clang-module-cache"

cd "${repository_root}"
mkdir -p "${module_cache}"

run_flags=(run --disable-sandbox DsHarnessCoreChecks)

if [[ "$(xcode-select -p)" == "/Library/Developer/CommandLineTools" ]]; then
    newest_sdk="$(ls -d /Library/Developer/CommandLineTools/SDKs/MacOSX*.sdk 2>/dev/null | sort -V | tail -1 || true)"
    if [[ -n "${newest_sdk}" ]]; then
        env SDKROOT="${newest_sdk}" CLANG_MODULE_CACHE_PATH="${module_cache}" \
            swift "${run_flags[@]}"
    else
        env CLANG_MODULE_CACHE_PATH="${module_cache}" swift "${run_flags[@]}"
    fi
else
    env CLANG_MODULE_CACHE_PATH="${module_cache}" swift "${run_flags[@]}"
fi
