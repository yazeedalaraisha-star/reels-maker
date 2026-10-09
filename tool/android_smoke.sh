#!/bin/bash
# يركب الـ apk على المحاكي ويشغله ويتأكد إنه ما وقع.
apk=$1
adb install -r "$apk" && echo "::notice::APK installed" || echo "::notice::APK INSTALL FAILED"
pkg=$(aapt dump badging "$apk" 2>/dev/null | sed -n "s/package: name='\([^']*\)'.*/\1/p")
[ -z "$pkg" ] && pkg=$(adb shell pm list packages | grep -i reels | head -1 | cut -d: -f2 | tr -d '\r')
echo "::notice::package=$pkg"
adb logcat -c
adb shell monkey -p "$pkg" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1
sleep 25
pid=$(adb shell pidof "$pkg" | tr -d '\r')
if [ -n "$pid" ]; then echo "::notice::APP alive pid=$pid"; else echo "::notice::APP NOT RUNNING"; fi
adb logcat -d -b crash | head -c 1500 | tr '\n' ' ' | sed 's/^/::notice::CRASH /'
echo
adb logcat -d | grep -E "FATAL|AndroidRuntime|flutter.*(Error|Exception)|E/flutter" | head -8 | sed 's/^/::notice::LOG /'
adb shell screencap -p /sdcard/s.png && adb pull /sdcard/s.png dist/screen.png >/dev/null 2>&1 || true
true
