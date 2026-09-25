#!/usr/bin/env bash
# Download a JevGate release for this runner, check its SHA-256 and put it on PATH.
set -euo pipefail

repo="Tech-Byte-Frontier/jevgate"
version="${JEVGATE_VERSION:-latest}"

case "$RUNNER_OS-$RUNNER_ARCH" in
    Linux-X64) target=x86_64-unknown-linux-musl ;;
    Linux-ARM64) target=aarch64-unknown-linux-musl ;;
    macOS-ARM64) target=aarch64-apple-darwin ;;
    macOS-X64) target=x86_64-apple-darwin ;;
    Windows-X64) target=x86_64-pc-windows-msvc ;;
    *) echo "::error::JevGate has no release binary for $RUNNER_OS $RUNNER_ARCH"; exit 1 ;;
esac

if [ "$version" = latest ]; then
    # …/releases/latest redirects to …/releases/tag/vX.Y.Z, without the API's rate limit.
    latest=$(curl -fsSLI --retry 3 -o /dev/null -w '%{url_effective}' "https://github.com/$repo/releases/latest")
    version="${latest##*/tag/}"
fi
version="${version#v}"

name="jevgate-$version-$target"
if [ "$RUNNER_OS" = Windows ]; then archive="$name.zip"; else archive="$name.tar.gz"; fi
dir="$RUNNER_TEMP/jevgate"
mkdir -p "$dir"
url="https://github.com/$repo/releases/download/v$version/$archive"
curl -fsSL --retry 3 -o "$dir/$archive" "$url" || { echo "::error::Could not download $url"; exit 1; }
curl -fsSL --retry 3 -o "$dir/$archive.sha256" "$url.sha256"

expected=$(cut -d ' ' -f 1 < "$dir/$archive.sha256")
# Hashed by its bare name: for a path with backslashes, as on Windows,
# sha256sum escapes its output line with a leading backslash.
if command -v sha256sum > /dev/null; then
    actual=$(cd "$dir" && sha256sum "$archive" | cut -d ' ' -f 1)
else
    actual=$(cd "$dir" && shasum -a 256 "$archive" | cut -d ' ' -f 1)
fi
[ "$expected" = "$actual" ] || { echo "::error::Checksum mismatch for $archive"; exit 1; }

if [ "$RUNNER_OS" = Windows ]; then
    unzip -q -o "$dir/$archive" -d "$dir"
else
    tar -xzf "$dir/$archive" -C "$dir"
fi
echo "$dir/$name" >> "$GITHUB_PATH"
"$dir/$name/jevgate" --version
