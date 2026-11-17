#!/usr/bin/env bash
# רץ אחרי "cap add android": אייקונים, צבע רקע והרשאות מיקום.
set -euo pipefail
RES=android/app/src/main/res
MAN=android/app/src/main/AndroidManifest.xml

# ImageMagick: משתמש במה שקיים, ואם אין - מתקין
if ! command -v magick >/dev/null 2>&1 && ! command -v convert >/dev/null 2>&1; then
  sudo apt-get update -y
  sudo apt-get install -y imagemagick
fi
IM=$(command -v magick || command -v convert)

declare -A LEGACY=( [mdpi]=48 [hdpi]=72 [xhdpi]=96 [xxhdpi]=144 [xxxhdpi]=192 )
declare -A FG=( [mdpi]=108 [hdpi]=162 [xhdpi]=216 [xxhdpi]=324 [xxxhdpi]=432 )
for d in "${!LEGACY[@]}"; do
  mkdir -p "$RES/mipmap-$d"
  "$IM" resources/icon-512.png -resize "${LEGACY[$d]}x${LEGACY[$d]}" "$RES/mipmap-$d/ic_launcher.png"
  cp "$RES/mipmap-$d/ic_launcher.png" "$RES/mipmap-$d/ic_launcher_round.png"
  "$IM" resources/icon-maskable-512.png -resize "${FG[$d]}x${FG[$d]}" "$RES/mipmap-$d/ic_launcher_foreground.png"
done

mkdir -p "$RES/values"
cat > "$RES/values/ic_launcher_background.xml" <<'XML'
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background">#1F86B8</color>
</resources>
XML

# הרשאות מיקום (חיפוש מוסכים לידי) — מוסיף רק אם חסר
for p in ACCESS_COARSE_LOCATION ACCESS_FINE_LOCATION READ_CALENDAR WRITE_CALENDAR POST_NOTIFICATIONS BLUETOOTH BLUETOOTH_ADMIN BLUETOOTH_SCAN BLUETOOTH_CONNECT; do
  grep -q "android.permission.$p" "$MAN" || \
    sed -i "s#</manifest>#    <uses-permission android:name=\"android.permission.$p\" />\n</manifest>#" "$MAN"
done
# התחברות עם Google: קובץ ההגדרות של Firebase והפעלת הרכיב של Google
if [ -f google-services.json ]; then
  cp google-services.json android/app/google-services.json
  grep -q "rgcfaIncludeGoogle" android/variables.gradle || sed -i "0,/ext {/s//ext {\n    rgcfaIncludeGoogle = true/" android/variables.gradle
  echo "google sign-in: configured"
else
  echo "google sign-in: google-services.json missing"
fi
# כיווץ וערפול קוד בגרסת release (דרישת Google Play). גרסת debug לא מושפעת
GR=android/app/build.gradle
if false; then # כבוי: R8 נכשל בבניית ה-AAB. לא מפעילים כיווץ קוד עד שיתוקן
  echo "R8 disabled"
  sed -i "s/minifyEnabled false/minifyEnabled true/" "$GR"
  sed -i "s/getDefaultProguardFile('proguard-android.txt')/getDefaultProguardFile('proguard-android-optimize.txt')/" "$GR"
  grep -q "CarPulse keep rules" android/app/proguard-rules.pro 2>/dev/null || cat >> android/app/proguard-rules.pro <<'PRO'
# CarPulse keep rules
-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod,SourceFile,LineNumberTable
-keep class com.getcapacitor.** { *; }
-keep @com.getcapacitor.annotation.CapacitorPlugin public class * { *; }
-keep public class * extends com.getcapacitor.Plugin { *; }
-keepclassmembers class * { @com.getcapacitor.PluginMethod public <methods>; }
-keepclassmembers class * { @android.webkit.JavascriptInterface <methods>; }
-keep class com.capacitorjs.** { *; }
-keep class io.capawesome.** { *; }
-keep class dev.barooni.** { *; }
-keep class com.carpulse.mobile.** { *; }
-dontwarn com.getcapacitor.**
PRO
  echo "code shrinking: enabled"
else
  echo "code shrinking: skipped"
fi
# פונט Heebo בתוך האפליקציה. אם ההורדה נכשלת, האפליקציה נשארת עם פונט המערכת.
FNDIR="www/fonts"; mkdir -p "$FNDIR"
for f in hebrew latin; do
  curl -fsSL --max-time 60 "https://cdn.jsdelivr.net/npm/@fontsource-variable/heebo@5/files/heebo-$f-wght-normal.woff2" -o "$FNDIR/heebo-$f.woff2" && [ -s "$FNDIR/heebo-$f.woff2" ] && echo "font $f: ok" || { rm -f "$FNDIR/heebo-$f.woff2"; echo "font $f: skipped"; }
done
# Firebase מקומי בתוך האפליקציה: עולה מהר גם כשהרשת איטית. אם ההורדה נכשלת, נשאר הקישור הרגיל.
FBDIR="www/fb"; mkdir -p "$FBDIR"; FBOK=1
for f in app auth firestore; do
  if ! curl -fsSL --max-time 60 "https://www.gstatic.com/firebasejs/10.12.2/firebase-$f-compat.js" -o "$FBDIR/$f.js" || [ ! -s "$FBDIR/$f.js" ]; then FBOK=0; fi
done
if [ "$FBOK" = 1 ]; then
  perl -pi -e 's#https://www\.gstatic\.com/firebasejs/10\.12\.2/firebase-(app|auth|firestore)-compat\.js#fb/$1.js#g' "www/index.html"
  echo "firebase: local copy"
else
  rm -rf "$FBDIR"; echo "firebase: using CDN"
fi
echo "prepare-android: done"
