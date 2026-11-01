# yabai-gaWM

個人 macOS 原生 Spaces 視窗管理 workflow：**yabai + skhd + SpaceSwitch + wm-compat**，快捷鍵沿用 AeroSpace 習慣。

這是設定與可重建原始碼，不是官方 yabai 發行版。整理自 2026-11-01 的本機設定，保留已知問題，不保證所有 App 的行為。

## 元件

| 元件 | 用途 |
|---|---|
| yabai | 平鋪、焦點、交換、移窗、桌面資訊 |
| skhd | 全域快捷鍵 |
| SpaceSwitch | macOS 27 IOHID 手勢無動畫切桌面 |
| wm-compat | 方向感知縮放、BSP／Stack、跨螢幕移窗、浮動切換目標防護 |
| space-step.sh + jq | 選同螢幕左右桌面，再呼叫 SpaceSwitch |

目前快捷鍵不依賴 Python、AeroSpace、Spacetile 或 strafe App。SpaceSwitch 內含 strafe 衍生的底層手勢程式碼，保留 MIT／0BSD 授權。SketchyBar 是選用整合。

數字切桌面：skhd → SpaceSwitch → yabai 查詢 → 手勢事件。
左右切桌面：skhd → space-step.sh → yabai + jq → SpaceSwitch。
縮放／排列：skhd → wm-compat → yabai。一般方向焦點與送窗直接使用 yabai。

## 建置安裝

基礎環境：Apple silicon、macOS 27、Homebrew `/opt/homebrew`、yabai 7.1.25。其他環境未完整驗證。SIP 保持開啟，未載入 scripting addition。

先安裝 yabai、skhd、jq 與 Xcode Command Line Tools；目前工具使用 `/opt/homebrew/bin`，其他 Homebrew prefix 需先修改。

```bash
git clone https://github.com/osga24/yabai-gaWM.git
cd yabai-gaWM
./scripts/build.sh
./scripts/install.sh                 # 預覽，不寫入
./scripts/install.sh --apply          # 有既存檔案就拒絕覆蓋
./scripts/install.sh --apply --force  # 確認要替換後才使用
```

`--force` 覆寫此專案負責的設定、工具與 SpaceSwitch bundle，不備份、不刪除其他設定。安裝不自動啟停服務、不修改 SIP、不替換 Homebrew 的 yabai、不安裝 SketchyBar。先自行保存需要保留的設定。

安裝後在「系統設定 → 隱私權與安全性 → 輔助使用」允許 yabai、skhd 和 `~/.config/yabai/tools/SpaceSwitch.app`。重建 ad-hoc 簽章可能需要重新授權。SpaceSwitch 按需執行，不需常駐。

```bash
# 一般登入帳號執行，不要 sudo；start-service 註冊登入服務
yabai --start-service
skhd --start-service
# 已運行時重新載入
yabai --restart-service
skhd -r
```

不要同時啟動其他自動平鋪工具；舊 AeroSpace 自動登入需自行關閉。

## 快捷鍵

`⌥` Option／Alt、`⇧` Shift、`⌃` Control。

| 操作 | 按鍵 |
|---|---|
| 左／下／上／右焦點 | `⌥H/J/K/L` |
| 交換方向鄰居 | `⌥⇧H/J/K/L` |
| 在方向鄰居旁重新插入（warp） | `⌥⌃H/J/K/L` |
| 選左／右／上／下螢幕 | `⌥S/F/I/U` |
| 移窗到另一螢幕並嘗試跟隨 | `⌥⇧S/F/I/U` |
| 切到全域桌面 1–9 | `⌥1–9` |
| 送視窗到全域桌面 1–9 | `⌥⇧1–9` |
| 同螢幕上一個／下一個桌面，邊界停止 | `⌥P/N` |
| 上一個／下一個堆疊視窗，循環 | `⌥⇧P/N` |
| 切分割方向 | `⌥⇧R` |
| 浮動／納入排列 | `⌥⇧E` |
| 桌面內放大／還原，非原生全螢幕 | `⌥⇧M` |
| 均分大小 | `⌥⇧B` |
| 整個桌面 BSP／Stack | `⌥⇧C` |
| 縮小／放大，50 點步進 | `⌥⇧-`／`⌥⇧=` |
| Service mode | `⌥⇧;`；F 浮動、R 均分、Escape 離開 |
| 拖曳重排／大小 | `⌥＋左鍵`／`⌥＋右鍵` |

Service mode F/R 後需 Escape 離開。Stack 的 H/J/K/L 仍是方向焦點；用 Shift P/N 循環。桌面 10 未綁定。

## 目前設定

- BSP、auto 分割、初始比例 0.5、自動均分開啟，邊距及 gap 各 6 點。
- 視窗數量改變時自動均分可能重設手動比例。
- 唯一啟用的 App 例外是 System Settings 浮動；其他 App 浮動與自動分桌規則皆為註解。
- 浮動不會自動縮小已滿版的視窗。
- 桌面由 Mission Control 手動建立；yabai 使用跨螢幕全域 index。接拔螢幕與增刪桌面後可能變號，建議關閉「根據最近使用情況自動重新排列 Spaces」。

## 檔案

| 路徑 | 內容 |
|---|---|
| `config/yabai/yabairc` | 平鋪、間距、規則與事件 |
| `config/skhd/skhdrc` | 快捷鍵 |
| `src/wm-compat/` | 原生輔助工具 |
| `src/space-switch/` | 手勢切換工具、App metadata 與第三方授權 |
| `scripts/` | 建置、安裝與左右桌面腳本 |
| `patches/` | 選用 macOS 27 事件辨識補丁 |
| `optional/sketchybar/` | 僅桌面列的選用整合 |

安裝工具放在 `~/.config/yabai/tools/`，不依賴 checkout 位置。原始碼和補丁也會複製到該處供查閱；重建請在 repository 執行 `scripts/build.sh`。

## 已知限制

- macOS 27 上關窗留空有 [yabai #2828](https://github.com/asmvik/yabai/issues/2828) 回報，切換相容性見 [#2802](https://github.com/asmvik/yabai/issues/2802)。
- 先前本機使用 `patches/macos27-window-events.patch`，只把 macOS 27 映射到 26 的視窗事件分支；**不是完整的社群 #2828 修正**，不包含 order-out 處理。安裝腳本不套用它，見 [補丁說明](patches/README.md)。
- GPT 曾有焦點不同步、主視窗尺寸回報 0×0；浮動目標防護尚未證明全面修復。
- Chord 面板只在某桌面顯示、單視窗 Zen 抽動，根因未確認，本專案未包含確定修復。
- SpaceSwitch 使用私有事件格式，macOS 更新可能失效；跨多個桌面為連續切換，可能看到中間桌面。送出事件不代表已成功，工具會檢查桌面是否改變。
- Stack、視窗放大、原生全螢幕或 App 最小尺寸會限制縮放；防衝突鎖可能略過快速連按。
- 本機先前 10 個模擬縮放案例通過、呼叫查詢延遲由約 81ms 降至 8ms；不是端到端 GUI 速度或所有螢幕配置的保證。

## 驗證

建置後執行 `./scripts/check.sh`，包含 shell 語法、10 項縮放模擬、暫存目錄安裝、重複安裝拒絕及強制覆寫檢查。測試使用 Python 3；實際視窗管理不使用 Python。`GAWM_CONFIG_ROOT` 僅供暫存安裝驗證，正常 runtime 仍使用 `$HOME/.config`。測試不控制真實視窗，也不啟停服務。

## 排錯與維護

```bash
~/.config/yabai/tools/SpaceSwitch.app/Contents/MacOS/space-switch status
yabai -m query --spaces
yabai -m query --displays
yabai -m query --windows
yabai -m rule --list
tail -n 30 /tmp/yabai_$(id -un).err.log
tail -n 30 /tmp/skhd_$(id -un).err.log
```

關窗留空可嘗試 `yabai -m space --layout bsp`，但會將目前 Stack 改回 BSP。Homebrew 更新或重裝可能覆蓋自編譯 yabai，簽章變更後需注意輔助使用權限。

移除時先移除 skhd 中的工具快捷鍵，再刪本專案安裝的工具，勿刪自己的其他設定。已替換 yabai 者可用 `brew reinstall yabai` 恢復套件版。

## 授權

新增設定、腳本與 wm-compat 採 [MIT](LICENSE)。SpaceSwitch 的第三方程式碼保留 [原始授權與出處](src/space-switch/LICENSE)，包含 strafe、InstantSpaceSwitcher、iss 的權利聲明。yabai/skhd 各依其專案授權，本 repository 不提交編譯執行檔。
