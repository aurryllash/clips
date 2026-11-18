#!/bin/bash
# Installs the latest Clips into /Applications.
#
#   curl -fsSL https://www.clipsapp.online/install.sh | bash
#
# Files downloaded with curl aren't marked as "downloaded from the internet",
# so macOS opens Clips without the "Apple could not verify" warning.
set -euo pipefail

DMG_URL="https://www.clipsapp.online/download"
APP_NAME="Clips.app"

bold() { printf "\033[1m%s\033[0m\n" "$1"; }
fail() { printf "\033[31mError:\033[0m %s\n" "$1" >&2; exit 1; }

[ "$(uname -s)" = "Darwin" ] || fail "Clips only runs on macOS."
MACOS_MAJOR=$(sw_vers -productVersion | cut -d. -f1)
[ "$MACOS_MAJOR" -ge 13 ] || fail "Clips needs macOS 13 or later (you have $(sw_vers -productVersion))."

# Install for everyone if /Applications is writable, otherwise just for this user.
DEST="${CLIPS_INSTALL_DIR:-/Applications}"
if [ ! -w "$DEST" ]; then
    DEST="$HOME/Applications"
    mkdir -p "$DEST"
fi

TMP=$(mktemp -d)
MOUNT="$TMP/mount"
cleanup() {
    hdiutil detach "$MOUNT" -quiet >/dev/null 2>&1 || true
    rm -rf "$TMP"
}
trap cleanup EXIT

bold "Downloading Clips…"
curl -fL --progress-bar "$DMG_URL" -o "$TMP/Clips.dmg" || fail "Download failed. Check your internet connection."

mkdir -p "$MOUNT"
hdiutil attach "$TMP/Clips.dmg" -nobrowse -readonly -mountpoint "$MOUNT" -quiet || fail "Couldn't open the downloaded disk image."
[ -d "$MOUNT/$APP_NAME" ] || fail "The download doesn't contain $APP_NAME."

# Quit the copy being replaced, if it's running.
if pgrep -f "$DEST/$APP_NAME/Contents/MacOS/Clips" >/dev/null; then
    bold "Quitting the running Clips…"
    pkill -f "$DEST/$APP_NAME/Contents/MacOS/Clips" || true
    sleep 1
fi

bold "Installing to ${DEST}…"
rm -rf "$DEST/$APP_NAME"
ditto "$MOUNT/$APP_NAME" "$DEST/$APP_NAME"
xattr -dr com.apple.quarantine "$DEST/$APP_NAME" 2>/dev/null || true

if [ -z "${CLIPS_NO_OPEN:-}" ]; then
    bold "Opening Clips…"
    open "$DEST/$APP_NAME"
fi

echo
bold "✅ Clips is installed."
echo "   Look for the paperclip in your menu bar, then press ⇧⌘V."
echo "   When asked, allow Clips in System Settings → Privacy & Security → Accessibility."
