#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 || ! $1 =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "usage: $0 <version> (for example: 2.0.0)" >&2
  exit 64
fi

version=$1
downloads_dir=${RESONANCE_DOWNLOADS_DIR:-/opt/resonance/downloads}

declare -A releases=(
  [Resonance-Setup-current-x64.exe]="Resonance-Setup-${version}-x64.exe"
  [Resonance-windows-x64-current.zip]="Resonance-windows-x64-${version}.zip"
  [Resonance-android-current.apk]="Resonance-android-${version}-release-debug-signed.apk"
  [Resonance-ios-current.ipa]="Resonance-ios-unsigned-${version}.ipa"
)

for artifact in "${releases[@]}"; do
  if [[ ! -f "${downloads_dir}/${artifact}" ]]; then
    echo "missing release artifact: ${downloads_dir}/${artifact}" >&2
    exit 66
  fi
done

for link in "${!releases[@]}"; do
  temporary=".${link}.tmp.$$"
  ln -s "${releases[$link]}" "${downloads_dir}/${temporary}"
  mv -Tf "${downloads_dir}/${temporary}" "${downloads_dir}/${link}"
done

echo "Promoted Resonance ${version} download links in ${downloads_dir}"
