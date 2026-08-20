#!/bin/zsh

set -euo pipefail

script_directory="${0:A:h}"
repository_root="${script_directory:h}"
application_bundle="${repository_root}/dist/DsHarness.app"
contents_directory="${application_bundle}/Contents"
module_cache="${repository_root}/.build/clang-module-cache"

cd "${repository_root}"
mkdir -p "${module_cache}"

# The manifest sandbox (sandbox-exec) is unnecessary for a local build and is
# blocked in some environments, so disable it explicitly.
build_flags=(-c release --product DsHarness --disable-sandbox)

if [[ "$(xcode-select -p)" == "/Library/Developer/CommandLineTools" ]]; then
    newest_sdk="$(ls -d /Library/Developer/CommandLineTools/SDKs/MacOSX*.sdk 2>/dev/null | sort -V | tail -1 || true)"
    if [[ -n "${newest_sdk}" ]]; then
        env SDKROOT="${newest_sdk}" CLANG_MODULE_CACHE_PATH="${module_cache}" \
            swift build "${build_flags[@]}"
    else
        env CLANG_MODULE_CACHE_PATH="${module_cache}" swift build "${build_flags[@]}"
    fi
else
    env CLANG_MODULE_CACHE_PATH="${module_cache}" swift build "${build_flags[@]}"
fi

rm -rf -- "${application_bundle}"
mkdir -p "${contents_directory}/MacOS" "${contents_directory}/Resources"
cp "${repository_root}/.build/release/DsHarness" "${contents_directory}/MacOS/DsHarness"
cp "${repository_root}/Resources/Info.plist" "${contents_directory}/Info.plist"
if [[ -f "${repository_root}/Resources/AppIcon.icns" ]]; then
    cp "${repository_root}/Resources/AppIcon.icns" "${contents_directory}/Resources/AppIcon.icns"
fi
chmod 755 "${contents_directory}/MacOS/DsHarness"

if command -v codesign >/dev/null 2>&1; then
    codesign --force --sign - "${application_bundle}"
fi

plutil -lint "${contents_directory}/Info.plist"
print "Built ${application_bundle}"
