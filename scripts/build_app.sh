#!/bin/zsh

set -euo pipefail

script_directory="${0:A:h}"
repository_root="${script_directory:h}"
application_bundle="${repository_root}/dist/HarnessDock.app"
contents_directory="${application_bundle}/Contents"
module_cache="${repository_root}/.build/clang-module-cache"
pet_plugin_source="${repository_root}/plugins/harnessdock-pet"

cd "${repository_root}"
mkdir -p "${module_cache}"

npm --prefix "${pet_plugin_source}" run build

# The manifest sandbox (sandbox-exec) is unnecessary for a local build and is
# blocked in some environments, so disable it explicitly.
build_flags=(-c release --product HarnessDock --disable-sandbox)

if [[ "$(xcode-select -p)" == "/Library/Developer/CommandLineTools" ]]; then
    # Some Command Line Tools updates leave a newer default SDK beside an
    # older compiler. The macOS 15 SDK fully supports this app's macOS 14
    # deployment target and avoids that compiler/SDK patch-version mismatch.
    build_sdk="/Library/Developer/CommandLineTools/SDKs/MacOSX15.sdk"
    if [[ ! -d "${build_sdk}" ]]; then
        build_sdk="$(ls -d /Library/Developer/CommandLineTools/SDKs/MacOSX*.sdk 2>/dev/null | sort -V | tail -1 || true)"
    fi
    if [[ -n "${build_sdk}" ]]; then
        env SDKROOT="${build_sdk}" CLANG_MODULE_CACHE_PATH="${module_cache}" \
            swift build "${build_flags[@]}"
    else
        env CLANG_MODULE_CACHE_PATH="${module_cache}" swift build "${build_flags[@]}"
    fi
else
    env CLANG_MODULE_CACHE_PATH="${module_cache}" swift build "${build_flags[@]}"
fi

rm -rf -- "${application_bundle}"
mkdir -p "${contents_directory}/MacOS" "${contents_directory}/Resources"
cp "${repository_root}/.build/release/HarnessDock" "${contents_directory}/MacOS/HarnessDock"
cp "${repository_root}/Resources/Info.plist" "${contents_directory}/Info.plist"
if [[ -f "${repository_root}/Resources/AppIcon.icns" ]]; then
    cp "${repository_root}/Resources/AppIcon.icns" "${contents_directory}/Resources/AppIcon.icns"
fi
for localization in "${repository_root}"/Resources/*.lproj; do
    if [[ -d "${localization}" ]]; then
        cp -R "${localization}" "${contents_directory}/Resources/"
    fi
done
bundled_pets="${repository_root}/Sources/HarnessDockApp/Resources/Pets"
if [[ -d "${bundled_pets}" ]]; then
    cp -R "${bundled_pets}" "${contents_directory}/Resources/Pets"
fi
bundled_plugin="${contents_directory}/Resources/Plugins/harnessdock-pet"
mkdir -p "${bundled_plugin}/lib"
cp "${pet_plugin_source}/package.json" "${bundled_plugin}/package.json"
cp "${pet_plugin_source}/README.md" "${bundled_plugin}/README.md"
cp "${pet_plugin_source}/cordis.patch.yml" "${bundled_plugin}/cordis.patch.yml"
cp "${pet_plugin_source}/lib/index.js" "${bundled_plugin}/lib/index.js"
cp "${pet_plugin_source}/lib/client.js" "${bundled_plugin}/lib/client.js"
cp "${pet_plugin_source}/lib/assets.json" "${bundled_plugin}/lib/assets.json"
chmod 755 "${contents_directory}/MacOS/HarnessDock"

if command -v codesign >/dev/null 2>&1; then
    codesign --force --sign - "${application_bundle}"
fi

plutil -lint "${contents_directory}/Info.plist"
print "Built ${application_bundle}"
