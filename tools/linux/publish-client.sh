#!/usr/bin/env bash
# Build a self-contained Linux client (no .NET install needed on the target) and pack it.
#   tools/linux/publish-client.sh [linux-x64|linux-arm64]
set -euo pipefail
RID="${1:-linux-x64}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT="$ROOT/publish-linux/wabibabusy-client-$RID"  # not publish/: the Windows installer packs that whole folder

rm -rf "$OUT"
dotnet publish "$ROOT/WaBiBaBuSy.Client.Linux/WaBiBaBuSy.Client.Linux.csproj" \
    -c Release -r "$RID" --self-contained -o "$OUT"
# Normalise permissions (publish leaves .NET's 0744 libraries next to 0644 files): everything world-readable,
# only the launcher, the install script and native libraries executable
find "$OUT" -type d -exec chmod 755 {} +
find "$OUT" -type f -exec chmod 644 {} +
chmod 755 "$OUT/wabibabusy-client" "$OUT/packaging/install.sh"
find "$OUT" -type f -name '*.so' -exec chmod 755 {} +
# root-owned in the archive, so extracting it as root doesn't leave files owned by the CI runner's uid
tar -czf "$OUT.tar.gz" --owner=0 --group=0 --numeric-owner -C "$ROOT/publish-linux" "wabibabusy-client-$RID"
echo "Done: $OUT.tar.gz"
echo "On each Linux machine: tar xzf $(basename "$OUT").tar.gz && bash wabibabusy-client-$RID/packaging/install.sh"
