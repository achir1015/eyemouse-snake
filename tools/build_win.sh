#!/usr/bin/env bash
# 匯出 Windows 版＋Inno 安裝程式＋免安裝 zip，輸出到 ../build/release
# 用法：bash tools/build_win.sh
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="$(cd .. && pwd)"
GODOT="/e/從零建置 Godot 賽車遊戲/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"
ISCC="$LOCALAPPDATA/Programs/Inno Setup 6/ISCC.exe"
VERSION="$(grep -E '^config/version=' project.godot | cut -d'"' -f2)"
REL="$ROOT/build/release"
mkdir -p "$REL" "$ROOT/build/windows"
echo "== v$VERSION"
# 內建攝影機眼動追蹤小程式（EyeCam）：原始碼有變才重新打包
if [ ! -f "$ROOT/build/eyecam/EyeCam/EyeCam.exe" ] || [ eyecam/eyecam.py -nt "$ROOT/build/eyecam/EyeCam/EyeCam.exe" ]; then
  (cd eyecam && python -m PyInstaller EyeCam.spec --noconfirm --distpath "$ROOT/build/eyecam" --workpath "$ROOT/build/eyecam-work" >/dev/null 2>&1)
fi
"$ROOT/build/eyecam/EyeCam/EyeCam.exe" --selftest --out "$ROOT/build/eyecam_selftest.txt" || true
sleep 1
grep -q "SELFTEST OK" "$ROOT/build/eyecam_selftest.txt" || { echo "EyeCam 自我測試失敗"; exit 1; }
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
"$GODOT" --headless --path . --export-release "Windows" "$ROOT/build/windows/EyeMouseSnake.exe" 2>&1 | grep -E "ERROR" || true
for i in 1 2 3; do
  (cd platform/windows && "$ISCC" //Q //DAppVersion="$VERSION" installer.iss) && break
  echo "ISCC 失敗，重試 $i"; sleep 3
done
rm -f "$REL/EyeMouseSnake-Windows-portable.zip"; rm -rf "$ROOT/build/windows/eyecam"
(cd "$ROOT/build/windows" && powershell -NoProfile -Command "Copy-Item -Recurse -Force '$(cygpath -w "$ROOT/build/eyecam/EyeCam")' eyecam; Compress-Archive -Path EyeMouseSnake.exe,eyecam -DestinationPath '$(cygpath -w "$REL")\EyeMouseSnake-Windows-portable.zip'")
ls -la "$REL"
