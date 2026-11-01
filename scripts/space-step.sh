#!/bin/sh
# Previous/next Space on the focused display; do not wrap or cross displays.
set -eu
case "${1:-}" in prev|next) direction="$1";; *) echo 'Usage: space-step.sh prev|next' >&2; exit 2;; esac
spaces=$(/opt/homebrew/bin/yabai -m query --spaces)
target=$(printf '%s' "$spaces" | /opt/homebrew/bin/jq -er --arg direction "$direction" '
  . as $spaces |
  (map(select(."has-focus" == true)) | first) as $current |
  if $current == null then error("No focused Space") else
    [$spaces[] | select(.display == $current.display)] | sort_by(.index) |
    if $direction == "next" then
      (map(select(.index > $current.index)) | first | .index // empty)
    else
      (map(select(.index < $current.index)) | last | .index // empty)
    end
  end
') || exit 0
TOOLS_DIR=$(CDPATH= cd "$(dirname "$0")" && pwd)
exec "$TOOLS_DIR/SpaceSwitch.app/Contents/MacOS/space-switch" "$target"
