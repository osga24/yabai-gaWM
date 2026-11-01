# 選用 macOS 27 事件修正

基礎：官方 yabai v7.1.25，commit `02de172f8706c3e2eaa679478897d7346e82b564`。

`macos27-window-events.patch` 是本機的簡化修改，只讓 macOS 27 啟用 macOS 26 的事件處理分支。不是官方修正，不包含 #2828 的完整 order-out 處理，也未解決所有焦點、抽動或切桌面問題。

在官方 v7.1.25 checkout 可先執行 `git apply --check /path/to/macos27-window-events.patch`，確認後套用，執行 `make`、`make -C tests` 自行評估。本機原始建置的既有 2 項測試曾通過，但不是完整 GUI 測試。

本專案 build/install 腳本不編譯或替換 Homebrew 的 yabai。自行安裝修正版可能需重新授權輔助使用，Homebrew 更新會覆蓋它；不需要為本補丁關閉 SIP 或載入 scripting addition。

[上游討論 #2828](https://github.com/asmvik/yabai/issues/2828)
