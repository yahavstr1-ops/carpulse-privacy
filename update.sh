#!/bin/bash
HERE="$(cd "$(dirname "$0")" && pwd)"
APP="$HOME/Downloads/carpulse-ios"
if [ ! -d "$APP" ]; then echo "לא מצאתי את התיקייה $APP"; exit 1; fi
cp "$HERE/index.html" "$APP/www/index.html"
cp "$HERE/index.html" "$APP/index.html"
cp "$HERE/ios-capacitor.config.json" "$APP/capacitor.config.json"
# פונט Heebo בתוך האפליקציה. אם ההורדה נכשלת, האפליקציה נשארת עם פונט המערכת.
FNDIR="$APP/www/fonts"; mkdir -p "$FNDIR"
for f in hebrew latin; do
  curl -fsSL --max-time 60 "https://cdn.jsdelivr.net/npm/@fontsource-variable/heebo@5/files/heebo-$f-wght-normal.woff2" -o "$FNDIR/heebo-$f.woff2" && [ -s "$FNDIR/heebo-$f.woff2" ] && echo "font $f: ok" || { rm -f "$FNDIR/heebo-$f.woff2"; echo "font $f: skipped"; }
done
# Firebase מקומי בתוך האפליקציה: עולה מהר גם כשהרשת איטית. אם ההורדה נכשלת, נשאר הקישור הרגיל.
FBDIR="$APP/www/fb"; mkdir -p "$FBDIR"; FBOK=1
for f in app auth firestore; do
  if ! curl -fsSL --max-time 60 "https://www.gstatic.com/firebasejs/10.12.2/firebase-$f-compat.js" -o "$FBDIR/$f.js" || [ ! -s "$FBDIR/$f.js" ]; then FBOK=0; fi
done
if [ "$FBOK" = 1 ]; then
  perl -pi -e 's#https://www\.gstatic\.com/firebasejs/10\.12\.2/firebase-(app|auth|firestore)-compat\.js#fb/$1.js#g' "$APP/www/index.html"
  echo "firebase: local copy"
else
  rm -rf "$FBDIR"; echo "firebase: using CDN"
fi
# אייקון האפליקציה החדש
AI="$APP/ios/App/App/Assets.xcassets/AppIcon.appiconset"
if [ -d "$AI" ]; then
  for f in "$AI"/*.png; do [ -e "$f" ] && sips -z $(sips -g pixelHeight "$f" | awk '/pixelHeight/{print $2}') $(sips -g pixelWidth "$f" | awk '/pixelWidth/{print $2}') "$HERE/icon-1024.png" --out "$f" >/dev/null; done
fi
for f in icon-192.png icon-512.png; do cp "$HERE/$f" "$APP/www/$f" 2>/dev/null; done
PL="$APP/ios/App/App/Info.plist"
if [ -f "$PL" ]; then
for K in NSCalendarsUsageDescription NSCalendarsWriteOnlyAccessUsageDescription NSCalendarsFullAccessUsageDescription; do
/usr/libexec/PlistBuddy -c "Delete :$K" "$PL" >/dev/null 2>&1
/usr/libexec/PlistBuddy -c "Add :$K string CarPulse מוסיף ליומן תזכורות לטסט, לביטוח ולטיפול" "$PL"
done
/usr/libexec/PlistBuddy -c "Delete :NSBluetoothAlwaysUsageDescription" "$PL" >/dev/null 2>&1
/usr/libexec/PlistBuddy -c "Add :NSBluetoothAlwaysUsageDescription string CarPulse מתחבר למתאם OBD בבלוטות׳ כדי לקרוא תקלות ונתוני רכב" "$PL"
fi
cd "$APP"
npm install @capacitor-community/bluetooth-le@^8.0.0 @capacitor/share@^8.0.1 @capacitor/app@^8.0.0 @capacitor/haptics@^8.0.0 @capacitor/filesystem@^8.0.0 @capacitor-community/in-app-review@^8.0.0
npx cap sync ios
npx cap open ios
echo "====== הכל מוכן. ב-Xcode: Product > Clean Build Folder, מחיקת האפליקציה מהאייפון, ▶ ======"
