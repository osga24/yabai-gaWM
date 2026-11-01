#!/bin/sh
focused=$(/opt/homebrew/bin/yabai -m query --spaces --space 2>/dev/null | /opt/homebrew/bin/jq -er '.index') || exit 0
if [ "$1" = "$focused" ]; then
 /opt/homebrew/bin/sketchybar --set "$NAME" background.drawing=on icon.color=0xff202024
else
 /opt/homebrew/bin/sketchybar --set "$NAME" background.drawing=off icon.color=0xffe5e7eb
fi
