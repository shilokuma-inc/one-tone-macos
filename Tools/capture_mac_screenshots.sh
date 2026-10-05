#!/bin/bash
set -euo pipefail

# App Store 用のスクリーンショット（macOS、表示サイズ APP_DESKTOP）を全言語・全画面ぶん撮る。
# iOS は Simulator で撮る Tools/capture_screenshots.sh を使う。
#
#   Tools/capture_mac_screenshots.sh [ja]
#
# 撮る画面は AppStore/screenshots.json、言語は AppStore/languages.json で決める（iOS と共通）。
# macOS 向けにビルドした .app を、画面ごとに起動引数「撮影モード」「撮る画面」「言語」付きで起動し直し
# （アプリ側は OneTone/ScreenshotDemo.swift。ウィンドウの中身は決まった大きさに固定される）、
# ウィンドウだけを screencapture で撮って、App Store が受け付ける寸法のキャンバスに合成する
# （Tools/mac_window.swift / Tools/compose_mac_screenshot.swift）。
#
# 寸法は実行したマシンのディスプレイの倍率で決まる: 1x なら 1440x900、Retina（2x）なら 2880x1800。
# どちらも App Store Connect の Mac の寸法として受け付けられる。
#
# 出力先: $SCREENSHOTS_DIR/APP_DESKTOP/<言語>/01_sine.png …（既定は build/screenshots）

LANGUAGES="${1:-}"
DISPLAY_TYPE="APP_DESKTOP"

ROOT_DIR="$(CDPATH='' cd -- "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

PROJECT="OneTone.xcodeproj"
SCHEME="${SCHEME:-OneTone}"
CONFIGURATION="${CONFIGURATION:-Debug}"
SCREENSHOTS_DIR="${SCREENSHOTS_DIR:-$ROOT_DIR/build/screenshots}"
# DerivedData はリポジトリ外に置く（手元の別のビルドと混ざらないようにする）
DERIVED_DATA="${DERIVED_DATA:-${RUNNER_TEMP:-${TMPDIR:-/tmp}}/OneToneMacScreenshotDerivedData}"
# キャンバスの大きさ（pt）。ディスプレイの倍率を掛けたピクセル数で出力される
CANVAS="${CANVAS:-1440x900}"
# ウィンドウが出るまで待つ上限、画面が落ち着くまで待つ上限、落ち着いたとみなすまでの最短の待ち（秒）
WINDOW_TIMEOUT="${WINDOW_TIMEOUT:-60}"
SETTLE_TIMEOUT="${SETTLE_TIMEOUT:-40}"
SETTLE_MINIMUM="${SETTLE_MINIMUM:-3}"

CONFIG="python3 Tools/app_store_config.py"

# MARK: - ビルド

# Upload ワークフローと同じく ad-hoc 署名にする。署名しないと entitlements（App Sandbox）が付かず、
# 配信するものと違う状態（サンドボックス外）で撮ることになる
echo "$SCHEME を macOS 向けにビルドします"
xcodebuild build \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -destination 'platform=macOS' \
    -derivedDataPath "$DERIVED_DATA" \
    -quiet \
    CODE_SIGN_STYLE=Manual \
    CODE_SIGN_IDENTITY=- \
    PROVISIONING_PROFILE_SPECIFIER=

SETTINGS="$(xcodebuild -showBuildSettings \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -destination 'platform=macOS' \
    -derivedDataPath "$DERIVED_DATA")"
BUILT_DIR="$(printf '%s\n' "$SETTINGS" | awk -F' = ' '/ BUILT_PRODUCTS_DIR /{print $2; exit}')"
APP_NAME="$(printf '%s\n' "$SETTINGS" | awk -F' = ' '/ FULL_PRODUCT_NAME /{print $2; exit}')"
EXECUTABLE_NAME="$(printf '%s\n' "$SETTINGS" | awk -F' = ' '/ EXECUTABLE_NAME /{print $2; exit}')"
APP_PATH="$BUILT_DIR/$APP_NAME"
EXECUTABLE="$APP_PATH/Contents/MacOS/$EXECUTABLE_NAME"
[ -x "$EXECUTABLE" ] || { echo "::error::$EXECUTABLE がありません" >&2; exit 1; }
# open で起動したプロセスのコマンドラインはシンボリックリンクを解決したパス（/var → /private/var など）になるので、
# PID を探すときはこちらで突き合わせる
EXECUTABLE_REAL="$(cd "$(dirname "$EXECUTABLE")" && pwd -P)/$EXECUTABLE_NAME"

# 補助ツールは swiftc で都度ビルドする（バイナリをリポジトリに置かない）
TOOLS_BIN="$(mktemp -d)"
xcrun swiftc -O Tools/mac_window.swift -o "$TOOLS_BIN/mac_window"
xcrun swiftc -O Tools/compose_mac_screenshot.swift -o "$TOOLS_BIN/compose_mac_screenshot"
xcrun swiftc -O Tools/remove_alpha.swift -o "$TOOLS_BIN/remove_alpha"

# MARK: - 撮影

APP_PID=""
cleanup() {
    if [ -n "$APP_PID" ]; then
        kill "$APP_PID" 2>/dev/null || true
    fi
    rm -rf "$TOOLS_BIN"
}
trap cleanup EXIT

# アプリを起動し、ウィンドウが出るまで待つ。ウィンドウの番号と幅（pt）を WINDOW_ID / WINDOW_WIDTH に入れる
launch_and_wait_window() {
    scene="$1"
    apple_language="$2"
    apple_locale="$3"
    # 実行ファイルを直接動かすと（少なくとも App Sandbox 付きでは）ウィンドウが作られないので、open で起動する。
    # -ApplePersistenceIgnoreState を付けると SwiftUI の WindowGroup がウィンドウを 1 つも出さなくなるので付けない
    open -n -a "$APP_PATH" --args \
        -screenshot-demo \
        -screenshot-scene "$scene" \
        -AppleLanguages "($apple_language)" \
        -AppleLocale "$apple_locale"

    # open は PID を返さないので、実行ファイルのパスで一番新しいプロセスを探す
    APP_PID=""
    elapsed=0
    while [ "$elapsed" -lt "$WINDOW_TIMEOUT" ]; do
        if [ -z "$APP_PID" ]; then
            APP_PID="$(pgrep -n -f "$EXECUTABLE_REAL" || true)"
        fi
        if [ -n "$APP_PID" ] && window="$("$TOOLS_BIN/mac_window" "$APP_PID")"; then
            WINDOW_ID="$(printf '%s' "$window" | cut -f1)"
            WINDOW_WIDTH="$(printf '%s' "$window" | cut -f2)"
            return 0
        fi
        sleep 1
        elapsed=$((elapsed + 1))
    done
    echo "::error::${WINDOW_TIMEOUT} 秒たってもウィンドウが出ませんでした（scene: ${scene}）" >&2
    return 1
}

# アプリを終了し、消えるまで待つ。終わり切る前に次を起動すると、次のウィンドウが出ないことがある
terminate_app() {
    if [ -n "$APP_PID" ]; then
        kill "$APP_PID" 2>/dev/null || true
        for _ in $(seq 1 20); do
            kill -0 "$APP_PID" 2>/dev/null || break
            sleep 0.5
        done
        APP_PID=""
        sleep 1
    fi
}

# ウィンドウだけを影無しで撮る。失敗（Screen Recording の許可が無いなど）は set -e で止まる。
# 起動直後はウィンドウが作り直されて番号が変わることがあるので、撮る直前に毎回引き直す
capture_window() {
    if window="$("$TOOLS_BIN/mac_window" "$APP_PID")"; then
        WINDOW_ID="$(printf '%s' "$window" | cut -f1)"
        WINDOW_WIDTH="$(printf '%s' "$window" | cut -f2)"
    fi
    screencapture -o -x -l "$WINDOW_ID" "$1"
}

# 起動直後はウィンドウが出てくる途中だったりするので、連続で撮った 2 枚が同じになるまで待つ。
# 撮影モードではタイトルの色相の回転や発光のゆらぎを止めているので、表示が終われば画面は変わらない
capture_when_settled() {
    output="$1"
    work="$(mktemp -d)"
    sleep "$SETTLE_MINIMUM"
    capture_window "$work/previous.png"
    elapsed="$SETTLE_MINIMUM"
    while [ "$elapsed" -lt "$SETTLE_TIMEOUT" ]; do
        sleep 2
        elapsed=$((elapsed + 2))
        capture_window "$work/current.png"
        if cmp -s "$work/previous.png" "$work/current.png"; then
            mv "$work/current.png" "$output"
            rm -rf "$work"
            return 0
        fi
        mv "$work/current.png" "$work/previous.png"
    done
    # 動いている途中の画面を正常な撮影結果として残すと、検証を通ってそのままアップロードされてしまう
    echo "::error::$(basename "$output") は ${SETTLE_TIMEOUT} 秒たっても画面が落ち着きませんでした" >&2
    rm -rf "$work"
    return 1
}

# プロセス置換の中で失敗しても set -e では止まらないので、先に取り出しておく
LANGUAGE_LIST="$($CONFIG languages "$LANGUAGES")"
SCENE_LIST="$($CONFIG scenes)"

while IFS=$'\t' read -r -u 3 language apple_language apple_locale store_locale; do
    destination="$SCREENSHOTS_DIR/$DISPLAY_TYPE/$language"
    # 撮り直しのたびに古い画像が混ざらないよう、言語ごとに作り直す
    rm -rf "$destination"
    mkdir -p "$destination"
    echo "::group::$DISPLAY_TYPE / ${language}（${store_locale}）"
    while IFS=$'\t' read -r -u 4 file scene; do
        launch_and_wait_window "$scene" "$apple_language" "$apple_locale"
        raw="$(mktemp -d)/window.png"
        capture_when_settled "$raw"
        terminate_app
        "$TOOLS_BIN/compose_mac_screenshot" "$raw" "$destination/$file.png" "$WINDOW_WIDTH" "$CANVAS"
        rm -rf "$(dirname "$raw")"
    done 4< <(printf '%s\n' "$SCENE_LIST")
    echo "::endgroup::"
done 3< <(printf '%s\n' "$LANGUAGE_LIST")

# MARK: - 検証

# 合成の時点でアルファは無いはずだが、iOS と同じ手順で描き直して確実に RGB にする
find "$SCREENSHOTS_DIR/$DISPLAY_TYPE" -name '*.png' -print0 | xargs -0 "$TOOLS_BIN/remove_alpha"

# App Store Connect は寸法が 1px でも違えば弾く。ディスプレイの倍率で 1440x900 か 2880x1800 になる
python3 Tools/verify_screenshots.py \
    --directory "$SCREENSHOTS_DIR/$DISPLAY_TYPE" \
    --sizes "$($CONFIG sizes "$DISPLAY_TYPE" | paste -sd, -)"

echo "$SCREENSHOTS_DIR/$DISPLAY_TYPE に保存しました"
