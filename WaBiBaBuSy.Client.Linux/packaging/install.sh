#!/usr/bin/env bash
# Install the WaBiBaBuSy Linux client for the current user (no root needed).
#
#   ./packaging/install.sh [--args "<client options>"] [--no-autostart] [--gnome-extension] [--kwin-script]
#   ./packaging/install.sh --uninstall
#
# Run it from inside the published folder (dotnet publish ... -o <folder>).
# On KDE Plasma the KWin script that keeps the wallpaper above Plasma's desktop is installed automatically.
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="${XDG_DATA_HOME:-$HOME/.local/share}/wabibabusy-client"
BIN_LINK="$HOME/.local/bin/wabibabusy-client"
AUTOSTART="${XDG_CONFIG_HOME:-$HOME/.config}/autostart/wabibabusy-client.desktop"
EXT_UUID="wabibabusy-wallpaper@bibabu"
EXT_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/gnome-shell/extensions/$EXT_UUID"
KWIN_SCRIPT="wabibabusy-wallpaper"

CLIENT_ARGS=""
AUTOSTART_ENABLED=1
GNOME_EXT=0
KWIN=0
[[ "${XDG_CURRENT_DESKTOP:-}" == *KDE* ]] && KWIN=1
UNINSTALL=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --args) CLIENT_ARGS="$2"; shift 2 ;;
        --no-autostart) AUTOSTART_ENABLED=0; shift ;;
        --gnome-extension) GNOME_EXT=1; shift ;;
        --kwin-script) KWIN=1; shift ;;
        --uninstall) UNINSTALL=1; shift ;;
        -h|--help) sed -n '2,9p' "$0"; exit 0 ;;
        *) echo "Unknown option: $1" >&2; exit 2 ;;
    esac
done

if [[ $UNINSTALL -eq 1 ]]; then
    pkill -x wabibabusy-clie 2>/dev/null || true
    rm -rf "$DEST" "$BIN_LINK" "$AUTOSTART"
    if [[ -d "$EXT_DIR" ]]; then
        gnome-extensions disable "$EXT_UUID" 2>/dev/null || true
        rm -rf "$EXT_DIR"
    fi
    if command -v kpackagetool6 >/dev/null && kpackagetool6 --type KWin/Script --show "$KWIN_SCRIPT" >/dev/null 2>&1; then
        kwriteconfig6 --file kwinrc --group Plugins --key "${KWIN_SCRIPT}Enabled" --delete 2>/dev/null || true
        kpackagetool6 --type KWin/Script --remove "$KWIN_SCRIPT" >/dev/null 2>&1 || true
        dbus-send --session --type=method_call --dest=org.kde.KWin /KWin org.kde.KWin.reconfigure 2>/dev/null || true
    fi
    echo "WaBiBaBuSy client removed."
    exit 0
fi

if [[ ! -x "$SRC/wabibabusy-client" ]]; then
    echo "wabibabusy-client not found next to packaging/ — run this from the published folder." >&2
    exit 1
fi

# ── Native libraries the client loads at runtime ──
missing=()
for lib in libX11.so.6 libXrandr.so.2 libXext.so.6 libICE.so.6 libSM.so.6 libfontconfig.so.1; do
    ldconfig -p 2>/dev/null | grep -q "$lib" || missing+=("$lib")
done
if [[ ${#missing[@]} -gt 0 ]]; then
    echo "WARNING: missing libraries: ${missing[*]}"
    echo "  Fedora:        sudo dnf install libX11 libXrandr libXext libICE libSM fontconfig"
    echo "  Ubuntu/Debian: sudo apt install libx11-6 libxrandr2 libxext6 libice6 libsm6 libfontconfig1"
fi

# ── Copy the program ──
if [[ "$SRC" != "$DEST" ]]; then
    rm -rf "$DEST"
    mkdir -p "$DEST"
    cp -a "$SRC/." "$DEST/"
fi
chmod +x "$DEST/wabibabusy-client"
mkdir -p "$(dirname "$BIN_LINK")"
ln -sf "$DEST/wabibabusy-client" "$BIN_LINK"
echo "Installed to $DEST (command: wabibabusy-client)"

# ── Start with the desktop session ──
if [[ $AUTOSTART_ENABLED -eq 1 ]]; then
    mkdir -p "$(dirname "$AUTOSTART")"
    cat > "$AUTOSTART" <<EOF
[Desktop Entry]
Type=Application
Name=WaBiBaBuSy Client
Comment=Synchronized animated wallpaper (Linux client)
Exec=$DEST/wabibabusy-client $CLIENT_ARGS
X-GNOME-Autostart-enabled=true
X-KDE-autostart-after=panel
NoDisplay=true
EOF
    echo "Autostart entry: $AUTOSTART"
fi

# ── Optional GNOME Shell fallback extension ──
if [[ $GNOME_EXT -eq 1 ]]; then
    mkdir -p "$EXT_DIR"
    cp -a "$DEST/packaging/gnome-extension/$EXT_UUID/." "$EXT_DIR/"
    gnome-extensions enable "$EXT_UUID" 2>/dev/null \
        && echo "GNOME extension enabled." \
        || echo "GNOME extension copied — log out and back in, then run: gnome-extensions enable $EXT_UUID"
fi

# ── KDE Plasma: KWin script keeping the wallpaper above plasmashell's desktop (a desktop click raises that over it) ──
if [[ $KWIN -eq 1 ]]; then
    if command -v kpackagetool6 >/dev/null; then
        pkg="$DEST/packaging/kwin-script/$KWIN_SCRIPT"
        kpackagetool6 --type KWin/Script --upgrade "$pkg" >/dev/null 2>&1 \
            || kpackagetool6 --type KWin/Script --install "$pkg" >/dev/null
        kwriteconfig6 --file kwinrc --group Plugins --key "${KWIN_SCRIPT}Enabled" true
        dbus-send --session --type=method_call --dest=org.kde.KWin /KWin org.kde.KWin.reconfigure 2>/dev/null \
            && echo "KWin script enabled." \
            || echo "KWin script installed — log out and back in to load it."
    else
        echo "WARNING: kpackagetool6 not found (Plasma 6 needed) — KWin script not installed;"
        echo "  a click on the desktop can hide the wallpaper under Wayland until the client restarts."
    fi
fi

cat <<EOF

Next steps:
  * Firewall: allow mDNS (UDP 5353) so the server is found automatically
      Fedora: sudo firewall-cmd --permanent --add-service=mdns && sudo firewall-cmd --reload
      Ubuntu: sudo ufw allow 5353/udp
    or skip discovery with: wabibabusy-client --server <server-ip>
  * Check placement without a server: wabibabusy-client --demo   (Ctrl+C to quit)
EOF
