#!/bin/bash
set -euo pipefail

# チュートリアルの各ページに載せる画面を macOS / iOS それぞれ撮り、OneTone/Assets.xcassets/Tutorial に置く。
# UI を変えたら撮り直す。
#
#   Tools/capture_tutorial_screenshots.sh            # macOS と iOS の両方
#   Tools/capture_tutorial_screenshots.sh mac        # macOS だけ
#   Tools/capture_tutorial_screenshots.sh ios        # iOS だけ
#
# 撮影は App Store 用と同じ撮影モード（OneTone/ScreenshotDemo.swift）と撮影スクリプト
# （Tools/capture_mac_screenshots.sh / Tools/capture_screenshots.sh）で行い、撮る画面だけを環境変数 SCENES で差し替える。
# AppStore/screenshots.json（App Store 用の画面）は使わないし変えない。
#
# 画像セットは Tutorial-<ページ名>.imageset で、macOS 用（idiom: mac）と iOS 用（idiom: universal。iPhone で撮ったもの）の 2 枚を持つ。
# ページ名は TutorialPage.ID、撮影の場面は ScreenshotDemo.Scene の tutorial-<ページ名> と一致させる。
# アプリの容量を抑えるため、macOS は幅 MAC_WIDTH px、iOS は高さ IOS_HEIGHT px に縮める。

TARGETS="${1:-all}"

ROOT_DIR="$(CDPATH='' cd -- "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

PAGES="welcome playback frequency volume waveform"
ASSETS_DIR="OneTone/Assets.xcassets/Tutorial"
# 撮った画面を一時的に置く場所（リポジトリの外）
WORK_DIR="${WORK_DIR:-${TMPDIR:-/tmp}/OneToneTutorialScreenshots}"
# 言語を変えても UI は英語のみ。撮影スクリプトの言語の一覧から 1 つだけ選ぶ
LANGUAGE="${LANGUAGE:-ja}"
MAC_WIDTH="${MAC_WIDTH:-1280}"
IOS_HEIGHT="${IOS_HEIGHT:-1400}"

SCENES=""
for page in $PAGES; do
    SCENES="${SCENES}${page}"$'\t'"tutorial-${page}"$'\n'
done
SCENES="${SCENES%$'\n'}"
export SCENES

# 撮った PNG を縮めて画像セットに置く
place() {
    source_dir="$1"
    file_name="$2"
    shift 2
    for page in $PAGES; do
        imageset="$ASSETS_DIR/Tutorial-${page}.imageset"
        mkdir -p "$imageset"
        cp "$source_dir/${page}.png" "$imageset/$file_name"
        sips "$@" "$imageset/$file_name" >/dev/null
    done
}

case "$TARGETS" in
    all | mac | ios) ;;
    *) echo "使い方: $0 [all|mac|ios]" >&2; exit 1 ;;
esac

if [ "$TARGETS" = all ] || [ "$TARGETS" = mac ]; then
    # キャンバスを描き出す大きさ（ScreenshotDemo.renderSize）と同じにして、余白を付けない
    SCREENSHOTS_DIR="$WORK_DIR/mac" CANVAS=1280x800 Tools/capture_mac_screenshots.sh "$LANGUAGE"
    place "$WORK_DIR/mac/APP_DESKTOP/$LANGUAGE" mac.png --resampleWidth "$MAC_WIDTH"
fi

if [ "$TARGETS" = all ] || [ "$TARGETS" = ios ]; then
    SCREENSHOTS_DIR="$WORK_DIR/ios" Tools/capture_screenshots.sh APP_IPHONE_67 "$LANGUAGE"
    place "$WORK_DIR/ios/APP_IPHONE_67/$LANGUAGE" ios.png --resampleHeight "$IOS_HEIGHT"
fi

# 画像セットの定義。片方だけ撮り直したときも、両方の画像を指す形で書き直す
mkdir -p "$ASSETS_DIR"
cat >"$ASSETS_DIR/Contents.json" <<'JSON'
{
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
JSON
for page in $PAGES; do
    cat >"$ASSETS_DIR/Tutorial-${page}.imageset/Contents.json" <<'JSON'
{
  "images" : [
    {
      "filename" : "ios.png",
      "idiom" : "universal"
    },
    {
      "filename" : "mac.png",
      "idiom" : "mac"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
JSON
done

echo "$ASSETS_DIR に保存しました"
