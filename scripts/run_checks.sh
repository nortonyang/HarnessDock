#!/bin/zsh

set -euo pipefail

script_directory="${0:A:h}"
repository_root="${script_directory:h}"
module_cache="${repository_root}/.build/clang-module-cache"

cd "${repository_root}"
mkdir -p "${module_cache}"

npm --prefix "${repository_root}/plugins/harnessdock-pet" run check
node "${repository_root}/scripts/check-chat-enter.mjs"
node "${repository_root}/scripts/check-balance-interaction.mjs"
node "${repository_root}/scripts/check-harness-environment.mjs"
node "${repository_root}/scripts/check-pet-profile-migration.mjs"
plutil -lint "${repository_root}"/Resources/*.lproj/Localizable.strings

run_flags=(run --disable-sandbox HarnessDockCoreChecks)

if [[ "$(xcode-select -p)" == "/Library/Developer/CommandLineTools" ]]; then
    # Prefer the SDK that matches this macOS 14-targeted app when a Command
    # Line Tools update leaves an incompatible newer default SDK installed.
    build_sdk="/Library/Developer/CommandLineTools/SDKs/MacOSX15.sdk"
    if [[ ! -d "${build_sdk}" ]]; then
        build_sdk="$(ls -d /Library/Developer/CommandLineTools/SDKs/MacOSX*.sdk 2>/dev/null | sort -V | tail -1 || true)"
    fi
    if [[ -n "${build_sdk}" ]]; then
        env SDKROOT="${build_sdk}" CLANG_MODULE_CACHE_PATH="${module_cache}" \
            swift "${run_flags[@]}"
    else
        env CLANG_MODULE_CACHE_PATH="${module_cache}" swift "${run_flags[@]}"
    fi
else
    env CLANG_MODULE_CACHE_PATH="${module_cache}" swift "${run_flags[@]}"
fi
