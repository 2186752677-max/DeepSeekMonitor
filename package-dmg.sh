#!/bin/bash
set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="DeepSeekMonitor"
APP_BUNDLE="$PROJECT_DIR/$APP_NAME.app"
DMG_NAME="DeepSeekMonitor-1.0.0.dmg"
DMG_PATH="$PROJECT_DIR/$DMG_NAME"
ICONSET="/tmp/AppIcon.iconset"

echo "========================================="
echo " DeepSeek Monitor — DMG 打包脚本"
echo "========================================="

# ── Step 1: Build release binary ──────────────────────────────────────
echo ""
echo "[1/4] 构建 Release 版本..."
cd "$PROJECT_DIR"
swift build -c release --arch arm64 2>&1 | tail -1

EXEC=$(find "$PROJECT_DIR/.build" -name "$APP_NAME" -type f -perm +111 2>/dev/null | grep release | head -1)
if [ -z "$EXEC" ]; then
    echo "❌ 找不到编译产物，尝试其他路径..."
    EXEC=$(find "$PROJECT_DIR/.build" -name "$APP_NAME" -type f 2>/dev/null | grep release | head -1)
fi
echo "   可执行文件: $EXEC"

# ── Step 2: Create .app bundle ────────────────────────────────────────
echo ""
echo "[2/4] 创建 .app 捆绑包..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$EXEC" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
chmod +x "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

# Info.plist
cat > "$APP_BUNDLE/Contents/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>DeepSeekMonitor</string>
    <key>CFBundleIdentifier</key>
    <string>com.deepseek.monitor</string>
    <key>CFBundleName</key>
    <string>DeepSeek Monitor</string>
    <key>CFBundleDisplayName</key>
    <string>DeepSeek Monitor</string>
    <key>CFBundleVersion</key>
    <string>1.0.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

# PkgInfo
echo "APPL????" > "$APP_BUNDLE/Contents/PkgInfo"

echo "   .app bundle 创建完成"

# ── Step 3: Generate app icon ─────────────────────────────────────────
echo ""
echo "[3/4] 生成应用图标..."

rm -rf "$ICONSET"
mkdir -p "$ICONSET"

python3 << 'PYEOF'
from PIL import Image, ImageDraw, ImageFont
import os

SIZE = 1024
img = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
draw = ImageDraw.Draw(img)

cx = cy = SIZE // 2
max_radius = SIZE // 2 - 8

# Gradient background — smooth concentric circles
for i in range(max_radius, 0, -1):
    t = i / max_radius  # 0 at edge, 1 at center
    # Deep blue indigo gradient
    r = int(72 + (99 - 72) * t)
    g = int(86 + (130 - 86) * t)
    b = int(230 + (250 - 230) * t)
    a = int(180 + 75 * t)
    draw.ellipse([cx - i, cy - i, cx + i, cy + i], fill=(r, g, b, a))

# White "DS" lettering
font_size = SIZE // 3
try:
    font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", font_size)
except Exception:
    try:
        font = ImageFont.truetype("/System/Library/Fonts/SFNSDisplay-Bold.otf", font_size)
    except Exception:
        font = ImageFont.load_default()

bbox = draw.textbbox((0, 0), "DS", font=font)
tw = bbox[2] - bbox[0]
th = bbox[3] - bbox[1]
draw.text((cx - tw // 2, cy - th // 2 - 12), "DS", fill=(255, 255, 255, 255), font=font)

# Export to iconset
iconset = "/tmp/AppIcon.iconset"
for s in [16, 32, 64, 128, 256, 512, 1024]:
    resized = img.resize((s, s), Image.LANCZOS)
    resized.save(f"{iconset}/icon_{s}x{s}.png")
    if s <= 512:
        twice = s * 2
        resized2x = img.resize((twice, twice), Image.LANCZOS)
        resized2x.save(f"{iconset}/icon_{s}x{s}@2x.png")

print(f"   已生成 {len(os.listdir(iconset))} 个图标文件")
PYEOF

# Convert to .icns
iconutil -c icns "$ICONSET" -o "$APP_BUNDLE/Contents/Resources/AppIcon.icns" 2>&1
echo "   AppIcon.icns 已嵌入 .app"

# ── Step 4: Ad-hoc code sign ──────────────────────────────────────────
echo ""
echo "   代码签名..."

# Clean extended attributes and hidden files (fixes "resource fork" error)
find "$APP_BUNDLE" -name ".DS_Store" -delete 2>/dev/null || true
find "$APP_BUNDLE" -name "._*" -delete 2>/dev/null || true
xattr -cr "$APP_BUNDLE" 2>/dev/null || true

codesign --force --deep --sign - "$APP_BUNDLE" 2>&1 || echo "   (签名跳过，不影响使用)"

# ── Step 5: Create DMG ────────────────────────────────────────────────
echo ""
echo "[4/4] 打包 DMG..."

# Clean up old DMG
rm -f "$DMG_PATH"

# Create a temporary directory for DMG contents
DMG_SRC=$(mktemp -d)
cp -R "$APP_BUNDLE" "$DMG_SRC/"
ln -s /Applications "$DMG_SRC/Applications"

# Create the DMG
echo "   创建磁盘映像..."
hdiutil create \
    -volname "DeepSeek Monitor" \
    -srcfolder "$DMG_SRC" \
    -ov \
    -format UDZO \
    -imagekey zlib-level=9 \
    -fs HFS+ \
    "$DMG_PATH" 2>&1 | tail -1

# ── Cleanup ───────────────────────────────────────────────────────────
rm -rf "$DMG_SRC" "$ICONSET"

# ── Result ────────────────────────────────────────────────────────────
FILE_SIZE=$(du -h "$DMG_PATH" | cut -f1)

echo ""
echo "========================================="
echo " ✅ 打包完成！"
echo ""
echo " 📦 $DMG_NAME"
echo " 📏 大小: $FILE_SIZE"
echo " 📂 位置: $PROJECT_DIR"
echo ""
echo " 安装方式：双击 DMG → 拖拽到 Applications 文件夹"
echo "========================================="
