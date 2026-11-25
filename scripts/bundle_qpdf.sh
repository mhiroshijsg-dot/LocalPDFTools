#!/bin/zsh
# qpdf を .app に同梱する。Xcode のビルドの最後（「qpdf を同梱」の段）で毎回走る。
# Xcode の ⌘R でも配る .app と同じ中身になるので、同梱し忘れなどの不具合をすぐ見つけられる。
#
# 入れるもの:
#   Contents/Helpers/qpdf          同梱の qpdf（Homebrew のものを写し、ライブラリの参照先を .app の中に向け直す）
#   Contents/Frameworks/*.dylib    qpdf が使うライブラリ（libqpdf・libjpeg・libcrypto）
#   Contents/Resources/ThirdPartyLicenses/  同梱したもののライセンス
#
# Xcode が渡す値: TARGET_BUILD_DIR・WRAPPER_NAME・EXPANDED_CODE_SIGN_IDENTITY
set -euo pipefail

APP=$TARGET_BUILD_DIR/$WRAPPER_NAME
SIGN_IDENTITY=${EXPANDED_CODE_SIGN_IDENTITY:--}
[[ -n "$SIGN_IDENTITY" ]] || SIGN_IDENTITY=-

QPDF_BIN=${QPDF_BIN:-/opt/homebrew/bin/qpdf}
[[ -x "$QPDF_BIN" ]] || { echo "error: qpdf が見つかりません（$QPDF_BIN）。brew install qpdf を実行してください" >&2; exit 1; }
QPDF_BIN=${QPDF_BIN:A}                     # シンボリックリンクをたどった実体
QPDF_PREFIX=${QPDF_BIN:h:h}                # 例: /opt/homebrew/Cellar/qpdf/12.4.2_1
QPDF_LIBDIR=$QPDF_PREFIX/lib               # @rpath/libqpdf.*.dylib の在りか

FW=$APP/Contents/Frameworks
HELPER=$APP/Contents/Helpers/qpdf
LICENSES=$APP/Contents/Resources/ThirdPartyLicenses
mkdir -p "${HELPER:h}" "$FW" "$LICENSES"

echo "qpdf を同梱: $QPDF_BIN"
# Homebrew のファイルは書き込み禁止なので、前回の分は上書きせずに消してから写す
rm -f "$HELPER"
cp "$QPDF_BIN" "$HELPER"
chmod u+w "$HELPER"

typeset -A copied
# file が参照する Homebrew のライブラリを Frameworks に写し、参照先を @rpath/名前 に書き換える（再帰）
bundle_deps() {
  local file=$1 dep name src
  for dep in ${(f)"$(otool -L "$file" | tail -n +2 | awk '{print $1}')"}; do
    [[ $dep == /opt/homebrew/* || $dep == /usr/local/* || $dep == @rpath/* || $dep == @loader_path/* ]] || continue
    name=${dep:t}
    if [[ -z ${copied[$name]:-} ]]; then
      if [[ $dep == /* ]]; then src=$dep; else src=$QPDF_LIBDIR/$name; fi
      [[ -f $src ]] || { echo "error: ライブラリが見つかりません: $dep（$src）" >&2; exit 1; }
      copied[$name]=1
      rm -f "$FW/$name"
      cp "${src:A}" "$FW/$name"
      chmod u+w "$FW/$name"
      install_name_tool -id "@rpath/$name" "$FW/$name" 2>/dev/null
      bundle_deps "$FW/$name"
    fi
    [[ $dep == "@rpath/$name" ]] || install_name_tool -change "$dep" "@rpath/$name" "$file" 2>/dev/null
  done
}
bundle_deps "$HELPER"

# qpdf の rpath（@loader_path/../lib）を、.app の Frameworks に向け直す
for rp in ${(f)"$(otool -l "$HELPER" | awk '/LC_RPATH/{getline; getline; print $2}')"}; do
  install_name_tool -delete_rpath "$rp" "$HELPER" 2>/dev/null
done
install_name_tool -add_rpath "@executable_path/../Frameworks" "$HELPER" 2>/dev/null

# Homebrew への参照が残っていたら、他の Mac では動かない
if otool -L "$HELPER" "$FW"/*.dylib | grep -E '/opt/homebrew|/usr/local'; then
  echo "error: Homebrew のライブラリへの参照が残っています" >&2; exit 1
fi

for formula in qpdf jpeg-turbo openssl@4; do
  dir=/opt/homebrew/opt/$formula
  for f in "$dir"/(LICENSE|NOTICE|COPYING)*(N); do
    [[ -f $f ]] && cp -f "$f" "$LICENSES/${formula}-${f:t}"
  done
done

# 中身から先に署名する（.app 全体の署名は、このあと Xcode が行う）
codesign --force --sign "$SIGN_IDENTITY" "$FW"/*.dylib
codesign --force --sign "$SIGN_IDENTITY" "$HELPER"

# 同梱の qpdf が単独で動くか
"$HELPER" --version | head -1
