#!/bin/zsh

set -euo pipefail

script_directory="${0:A:h}"
repository_root="${script_directory:h}"
application_bundle="${repository_root}/dist/HarnessDock.app"
dmg_root="${repository_root}/dist/HarnessDock-dmg-root"
dmg_path="${repository_root}/dist/HarnessDock-arm64-unsigned.dmg"

if [[ ! -d "${application_bundle}" ]]; then
    print -u2 "Missing ${application_bundle}; run scripts/build_app.sh first."
    exit 1
fi

rm -rf -- "${dmg_root}" "${dmg_path}"
mkdir -p "${dmg_root}"
cp -R "${application_bundle}" "${dmg_root}/HarnessDock.app"
ln -s /Applications "${dmg_root}/Applications"

hdiutil create \
    -volname "HarnessDock" \
    -srcfolder "${dmg_root}" \
    -ov \
    -format UDZO \
    "${dmg_path}"

shasum -a 256 "${dmg_path}" | tee "${dmg_path}.sha256"
print "Built ${dmg_path}"
