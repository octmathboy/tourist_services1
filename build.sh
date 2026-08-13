#!/bin/bash

echo "=== تنظيف ملفات البناء القديمة ==="
flutter clean

echo "=== جلب الحزم البرمجية ==="
flutter pub get

echo "=== تجهيز ملفات أندرويد ==="
cd android

echo "=== بناء ملف APK للإصدار عبر Gradle مباشرة ==="
# استخدام خيار تفعيل البناء الفردي وتحديد الذاكرة لتجنب انهيار النظام
./gradlew assembleRelease \
  -Dorg.gradle.jvmargs="-Xmx1536M -XX:MaxMetaspaceSize=512m" \
  --no-daemon

echo "=== تمت العملية بنجاح! ==="
echo "موقع الملف الناتج:"
echo "android/app/build/outputs/apk/release/app-release.apk"