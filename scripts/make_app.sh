#!/bin/zsh
# 配る形（Release）の .app と、GitHub の Releases に載せる zip を作る。
# 出力: このリポジトリの build/LocalPDFTools.app と build/LocalPDFTools-<バージョン>.zip（毎回作り直す）
# 使い方: scripts/make_app.sh
#
# ビルドそのものは Xcode のプロジェクト（LocalPDFTools.xcodeproj）が行い、
# qpdf の同梱は Xcode のビルドの中で scripts/bundle_qpdf.sh が行う。ここでは仕上がりを確かめて写すだけ。
set -euo pipefail
cd "${0:A:h}/.."

DERIVED=build/DerivedData
echo "== ビルド（Release）"
# MEMO(2026-11-25・by claude): 同梱する Homebrew の qpdf は Apple Silicon 用だけなので、アプリも arm64 だけにする
# （プロジェクトの ARCHS = arm64）。Intel の Mac で起動できても PDF を処理できない、という形を作らないため。
xcodebuild -project LocalPDFTools.xcodeproj -scheme LocalPDFTools -configuration Release \
           -destination 'generic/platform=macOS' -derivedDataPath "$DERIVED" -quiet build

BUILT=$DERIVED/Build/Products/Release/LocalPDFTools.app
APP=build/LocalPDFTools.app
rm -rf "$APP"
ditto "$BUILT" "$APP"

echo "== 署名の確認"
codesign --verify --deep --strict "$APP"

echo "== 同梱の qpdf が単独で動くか"
"$APP/Contents/Helpers/qpdf" --version | head -1

VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")

echo "== 配布用の zip"
# MEMO(2026-11-25・by claude): ditto で固めると、署名や .app の中の情報が崩れない（Finder の「圧縮」と同じ形）
ZIP=build/LocalPDFTools-$VERSION.zip
rm -f "$ZIP"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"
shasum -a 256 "$ZIP"

echo "できました（バージョン $VERSION）"
echo "  .app: ${APP:A}"
echo "  zip : ${ZIP:A}"
