#!/bin/sh
# Render the app icons and in-app images from the SVGs in this directory.
# Needs rsvg-convert (librsvg) and magick (ImageMagick 7). The outputs are committed,
# so this only has to run when the artwork changes.
set -eu

cd "$(dirname "$0")"
APP=../app
RES=$APP/android/app/src/main/res

png() { rsvg-convert -w "$2" -h "$3" "$1" -o "$4"; }

# 1x, 2x and 3x for Flutter's resolution-aware assets
for scale in 1 2 3; do
    dir=$APP/assets/images
    [ "$scale" = 1 ] || dir=$dir/$scale.0x
    mkdir -p "$dir"
    png icon.svg $((96 * scale)) $((96 * scale)) "$dir/logo.png"
    png flag_cs.svg $((24 * scale)) $((16 * scale)) "$dir/flag_cs.png"
    png flag_en.svg $((32 * scale)) $((16 * scale)) "$dir/flag_en.png"
done

for density in mdpi:48 hdpi:72 xhdpi:96 xxhdpi:144 xxxhdpi:192; do
    name=${density%%:*}
    size=${density##*:}
    mkdir -p "$RES/mipmap-$name"
    png icon.svg "$size" "$size" "$RES/mipmap-$name/ic_launcher.png"
    png icon-foreground.svg $((size * 9 / 4)) $((size * 9 / 4)) "$RES/mipmap-$name/ic_launcher_foreground.png"
done
mkdir -p "$RES/mipmap-anydpi-v26" "$RES/values"
cat > "$RES/mipmap-anydpi-v26/ic_launcher.xml" <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
    <monochrome android:drawable="@mipmap/ic_launcher_foreground"/>
</adaptive-icon>
EOF
cat > "$RES/values/ic_launcher_background.xml" <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background">#387FF2</color>
</resources>
EOF

tmp=$(mktemp -d)
for size in 16 24 32 48 64 128 256; do
    png icon.svg "$size" "$size" "$tmp/$size.png"
done
magick "$tmp"/16.png "$tmp"/24.png "$tmp"/32.png "$tmp"/48.png "$tmp"/64.png "$tmp"/128.png "$tmp"/256.png \
    "$APP/windows/runner/resources/app_icon.ico"

# macOS: the artwork takes 824 of 1024 px, as in Apple's icon grid
iconset=$APP/macos/Runner/Assets.xcassets/AppIcon.appiconset
for size in 16 32 64 128 256 512 1024; do
    inner=$((size * 824 / 1024))
    png icon.svg "$inner" "$inner" "$tmp/mac.png"
    magick "$tmp/mac.png" -background none -gravity center -extent "${size}x${size}" "$iconset/app_icon_$size.png"
done
# maskable web icons: the foreground on the blue background, like Android's adaptive icon
web=$APP/web
png icon.svg 32 32 "$web/favicon.png"
for size in 192 512; do
    png icon.svg "$size" "$size" "$web/icons/Icon-$size.png"
    png icon-foreground.svg "$size" "$size" "$tmp/foreground.png"
    magick "$tmp/foreground.png" -background '#387FF2' -flatten "$web/icons/Icon-maskable-$size.png"
done
rm -r "$tmp"

mkdir -p ../packaging/linux "$APP/fastlane/metadata/android/en-US/images"
cp icon.svg ../packaging/linux/one.jiri.easydict.svg
png icon.svg 512 512 "$APP/fastlane/metadata/android/en-US/images/icon.png"
