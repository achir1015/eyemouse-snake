#!/bin/bash
# 在 Mac 上匯出 macOS 版（Intel＋Apple 晶片通用），ad-hoc 簽章後包成 DMG。可直接用 SSH 執行。
# 產出：~/Developer/eyemouse-snake-build/EyeMouseSnake-macOS.dmg
set -e
PROJ=~/Developer/eyemouse-snake
OUT=~/Developer/eyemouse-snake-build/macos
GODOT=~/Developer/godot/Godot.app/Contents/MacOS/Godot
NAME="眼動鼠貪吃蛇"

rm -rf "$OUT" && mkdir -p "$OUT"
"$GODOT" --headless --path "$PROJ" --import >/dev/null 2>&1 || true
"$GODOT" --headless --path "$PROJ" --export-release "macOS" "$OUT/EyeMouseSnake.app" 2>&1 | grep -E "ERROR|DONE" || true
# 內建攝影機眼動追蹤小程式（EyeCam）：用眼動鼠專案的 venv（Intel Mac 只能 mediapipe 0.10.21）打包，放進 .app/Contents/Resources/eyecam
PY=~/Developer/eyemouse/.venv/bin/python
(cd "$PROJ/eyecam" && "$PY" -m PyInstaller EyeCam.spec --noconfirm --distpath "$OUT/eyecam-dist" --workpath "$OUT/eyecam-work" >/dev/null 2>&1)
"$OUT/eyecam-dist/EyeCam/EyeCam" --selftest --out "$OUT/eyecam_selftest.txt" || true
grep -q "SELFTEST OK" "$OUT/eyecam_selftest.txt" || { cat "$OUT/eyecam_selftest.txt"; echo "EyeCam 自我測試失敗"; exit 1; }
cd "$OUT"
mv EyeMouseSnake.app "$NAME.app"
mkdir -p "$NAME.app/Contents/Resources/eyecam"
cp -R eyecam-dist/EyeCam/. "$NAME.app/Contents/Resources/eyecam/"
rm -rf eyecam-dist eyecam-work
xattr -cr "$NAME.app"
codesign --force --deep -s - "$NAME.app"
codesign --verify --deep "$NAME.app"
mkdir dmg && cp -R "$NAME.app" dmg/ && ln -s /Applications dmg/Applications
for i in 1 2 3 4 5; do hdiutil create -volname "$NAME" -srcfolder dmg -ov -format UDZO -size 1400m ../EyeMouseSnake-macOS.dmg >/dev/null && break; echo "hdiutil 重試 $i"; sleep 5; done
rm -rf dmg
ls -l ../EyeMouseSnake-macOS.dmg
