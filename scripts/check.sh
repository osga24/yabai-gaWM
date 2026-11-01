#!/bin/sh
set -eu
ROOT=$(CDPATH= cd "$(dirname "$0")/.." && pwd)
for script in "$ROOT/scripts/"*.sh "$ROOT/config/yabai/yabairc" "$ROOT/optional/sketchybar/yabai-workspace.sh"; do sh -n "$script"; done
python3 "$ROOT/tests/resize.py"
"$ROOT/scripts/install.sh" --dry-run
STAGING=$(mktemp -d /private/tmp/gawm-install.XXXXXX)
trap 'rm -rf "$STAGING"' EXIT HUP INT TERM
GAWM_CONFIG_ROOT="$STAGING" "$ROOT/scripts/install.sh" --apply
if GAWM_CONFIG_ROOT="$STAGING" "$ROOT/scripts/install.sh" --apply >/dev/null 2>&1; then
 echo 'Installer did not refuse existing files' >&2; exit 1
fi
GAWM_CONFIG_ROOT="$STAGING" "$ROOT/scripts/install.sh" --apply --force
cmp "$ROOT/config/skhd/skhdrc" "$STAGING/skhd/skhdrc"
codesign --verify --strict "$STAGING/yabai/tools/SpaceSwitch.app"
echo 'Passed shell checks, resize cases, staging installation and overwrite guard.'
