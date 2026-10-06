#!/bin/zsh
# 编译并组装“阶段日志.app”（放在上一层文件夹里）。用法：./build.sh
set -euo pipefail
cd "$(dirname "$0")"
ROOT="$(cd .. && pwd)"
APP="$ROOT/阶段日志.app"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "编译 App…"
swiftc -O -o "$TMP/PhaseLog" main.swift -framework Cocoa -framework WebKit

echo "生成图标…"
swiftc -O -o "$TMP/makeicon" icon.swift -framework Cocoa
"$TMP/makeicon" "$TMP/icon_1024.png"
mkdir "$TMP/AppIcon.iconset"
for s in 16 32 128 256 512; do
  sips -z $s $s "$TMP/icon_1024.png" --out "$TMP/AppIcon.iconset/icon_${s}x${s}.png" >/dev/null
  sips -z $((s*2)) $((s*2)) "$TMP/icon_1024.png" --out "$TMP/AppIcon.iconset/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$TMP/AppIcon.iconset" -o "$TMP/AppIcon.icns"
cp "$TMP/icon_1024.png" ./icon_1024.png

echo "组装 $APP"
[[ "$APP" == *.app ]] && rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$TMP/PhaseLog" "$APP/Contents/MacOS/PhaseLog"
cp Info.plist "$APP/Contents/Info.plist"
cp "$TMP/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
codesign --force --deep --sign - "$APP"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP" || true
touch "$APP"
echo "完成：$APP"
