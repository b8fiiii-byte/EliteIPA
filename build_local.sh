#!/bin/bash
# build_local.sh — بناء Elite IPA محلياً على جهاز ماك (اختياري)
# الاستخدام: bash build_local.sh
set -e

echo "==> تثبيت XcodeGen إن لزم"
command -v xcodegen >/dev/null 2>&1 || brew install xcodegen

echo "==> جلب محرك zsign"
[ -d zsign ] || git clone --depth 1 https://github.com/zhlynn/zsign.git zsign

echo "==> توليد مشروع Xcode"
xcodegen generate

echo "==> بناء التطبيق بدون توقيع"
xcodebuild \
  -project EliteIPA.xcodeproj \
  -scheme EliteIPA \
  -configuration Release \
  -sdk iphoneos \
  -derivedDataPath build \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  clean build

echo "==> تغليف الـ IPA"
rm -rf Payload EliteIPA.ipa
mkdir -p Payload
cp -r build/Build/Products/Release-iphoneos/EliteIPA.app Payload/
zip -r EliteIPA.ipa Payload
echo "==> تم: EliteIPA.ipa جاهز"
