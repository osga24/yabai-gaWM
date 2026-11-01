#!/bin/sh
# Preview by default. Install selected files only; never start/stop services here.
set -eu
ROOT=$(CDPATH= cd "$(dirname "$0")/.." && pwd)
apply=false
force=false
for arg in "$@"; do
 case "$arg" in --apply) apply=true;; --force) force=true;; --dry-run) apply=false;; *) echo 'Usage: install.sh [--apply] [--force]' >&2; exit 2;; esac
done
CONFIG_ROOT="${GAWM_CONFIG_ROOT:-$HOME/.config}"
[ "$(id -u)" -ne 0 ] || { echo 'Run as your normal login user, not sudo.' >&2; exit 1; }
[ -x "$ROOT/build/wm-compat" ] && [ -x "$ROOT/build/SpaceSwitch.app/Contents/MacOS/space-switch" ] || { echo 'Run ./scripts/build.sh first.' >&2; exit 1; }
printf 'Destination: %s/{yabai,skhd}\n' "$CONFIG_ROOT"
if ! "$apply"; then echo 'Preview only. Use --apply to install; --force permits replacing existing selected files.'; exit 0; fi
if ! "$force"; then
 for dest in "$CONFIG_ROOT/yabai/yabairc" "$CONFIG_ROOT/skhd/skhdrc" "$CONFIG_ROOT/yabai/tools/SpaceSwitch.app" "$CONFIG_ROOT/yabai/tools/wm-compat" "$CONFIG_ROOT/yabai/tools/space-step.sh" "$CONFIG_ROOT/yabai/README.md" "$CONFIG_ROOT/yabai/tools/space-switch-src" "$CONFIG_ROOT/yabai/tools/wm-compat-src" "$CONFIG_ROOT/yabai/tools/yabai-close-fix"; do
  [ ! -e "$dest" ] || { printf 'Already exists: %s (review, then use --force)\n' "$dest" >&2; exit 1; }
 done
fi
mkdir -p "$CONFIG_ROOT/yabai/tools/space-switch-src" "$CONFIG_ROOT/yabai/tools/wm-compat-src" "$CONFIG_ROOT/yabai/tools/yabai-close-fix" "$CONFIG_ROOT/skhd"
cp "$ROOT/config/yabai/yabairc" "$CONFIG_ROOT/yabai/yabairc"
cp "$ROOT/config/skhd/skhdrc" "$CONFIG_ROOT/skhd/skhdrc"
cp "$ROOT/build/wm-compat" "$CONFIG_ROOT/yabai/tools/wm-compat"
cp "$ROOT/scripts/space-step.sh" "$CONFIG_ROOT/yabai/tools/space-step.sh"
# Replace only this bundle, preserving its signed file contents.
rm -rf "$CONFIG_ROOT/yabai/tools/SpaceSwitch.app"
cp -R "$ROOT/build/SpaceSwitch.app" "$CONFIG_ROOT/yabai/tools/"
cp "$ROOT/src/space-switch/"* "$CONFIG_ROOT/yabai/tools/space-switch-src/"
cp "$ROOT/src/wm-compat/"* "$CONFIG_ROOT/yabai/tools/wm-compat-src/"
cp "$ROOT/patches/macos27-window-events.patch" "$CONFIG_ROOT/yabai/tools/yabai-close-fix/"
cp "$ROOT/README.md" "$CONFIG_ROOT/yabai/README.md"
chmod +x "$CONFIG_ROOT/yabai/yabairc" "$CONFIG_ROOT/yabai/tools/wm-compat" "$CONFIG_ROOT/yabai/tools/space-step.sh"
echo 'Installed. Grant Accessibility, then start/restart yabai and reload skhd yourself. See README.'
