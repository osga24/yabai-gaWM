# 選用 SketchyBar 整合

主 yabairc 在安裝 SketchyBar 時發出 yabai_space_change 事件；沒有它也能用所有快捷鍵。

將 yabai-workspace.sh 複製到自己的 SketchyBar plugins/，自行在 sketchybarrc 加入：

```bash
sketchybar --add event yabai_space_change
for sid in 1 2 3 4 5 6 7 8 9; do
  sketchybar --add item "yabai.$sid" left \
    --set "yabai.$sid" icon="$sid" label.drawing=off \
      click_script="\"$HOME/.config/yabai/tools/SpaceSwitch.app/Contents/MacOS/space-switch\" $sid" \
      script="\"$CONFIG_DIR/plugins/yabai-workspace.sh\" $sid" \
    --subscribe "yabai.$sid" yabai_space_change system_woke
done
```

固定數字列不代表桌面存在。未打包個人的 AI 額度、音量、網速腳本，安裝腳本也不更改 SketchyBar。
