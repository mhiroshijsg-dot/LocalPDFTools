#!/bin/zsh
# 配る形（Release）の .app と、GitHub の Releases に載せる zip を作る。
# 出力: このリポジトリの build/LocalPDFTools.app と build/LocalPDFTools-<バージョン>.zip（毎回作り直す）、
#       build/dSYMs/LocalPDFTools-<バージョン>-<ID の頭 8 文字>/（クラッシュレポートを読むための dSYM。版ごとに残る）
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

VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")

echo "== クラッシュレポートを読むための dSYM を残す"
# MEMO(2026-11-27・by claude): 落ちたときのレポート（.ips）には、落ちた場所が番号でしか書かれていない。
# 関数の名前と行に直すには、その .app と同じビルドでできた dSYM が要る。DerivedData の dSYM は次のビルドで
# 上書きされるので、版の番号と ID（UUID・.ips にも書かれる）を付けたフォルダに写して残す。同じ ID は同じ中身なので上書きしてよい。
uuid_of() { dwarfdump --uuid "$1" | awk '{print $2}' }
check_dsym() {  # $1 = dSYM、$2 = その dSYM が対応するはずの .app の中のプログラム
    [[ "$(uuid_of "$1")" == "$(uuid_of "$2")" ]] || { echo "dSYM が .app と合いません: $1" >&2; exit 1 }
}
check_dsym "$BUILT.dSYM" "$APP/Contents/MacOS/LocalPDFTools"
check_dsym "${BUILT:h}/PDFEngine.framework.dSYM" "$APP/Contents/Frameworks/PDFEngine.framework/PDFEngine"
APP_UUID=$(uuid_of "$APP/Contents/MacOS/LocalPDFTools")
DSYMS=build/dSYMs/LocalPDFTools-$VERSION-${APP_UUID[1,8]}
rm -rf "$DSYMS"
mkdir -p "$DSYMS"
ditto "$BUILT.dSYM" "$DSYMS/LocalPDFTools.app.dSYM"
ditto "${BUILT:h}/PDFEngine.framework.dSYM" "$DSYMS/PDFEngine.framework.dSYM"

echo "== 同梱の qpdf が単独で動くか"
"$APP/Contents/Helpers/qpdf" --version | head -1

echo "== 配布用の zip"
# MEMO(2026-11-25・by claude): ditto で固めると、署名や .app の中の情報が崩れない（Finder の「圧縮」と同じ形）
ZIP=build/LocalPDFTools-$VERSION.zip
rm -f "$ZIP"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"
shasum -a 256 "$ZIP"

echo "できました（バージョン $VERSION）"
echo "  .app: ${APP:A}"
echo "  zip : ${ZIP:A}"
echo "  dSYM: ${DSYMS:A}（配らない。クラッシュレポートを読むときに使う）"
