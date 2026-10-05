# LEARNINGS — one-tone-macos 固有の知見

このリポジトリだけに当てはまる、ツールや環境の癖と回避策を溜める。全リポジトリ共通の知見は `~/.agents/LEARNINGS.md` に書く。

- 1 項目 = 1 つの箇条書き。日付（YYYY-MM-DD）を添える
- PC 固有の値（ローカルパス・Simulator の UDID）と秘密情報は書かない

## macOS のスクリーンショット撮影（Tools/capture_mac_screenshots.sh）

- App Sandbox 付きの `.app` の実行ファイルを直接起動すると、プロセスは生きるのにウィンドウが 1 つも作られない（メニューバー相当の 1512x33 のウィンドウだけが並ぶ）。`open -n -a <app> --args …` で起動する（2026-10-05）
- `-ApplePersistenceIgnoreState YES` を起動引数に付けると、SwiftUI の `WindowGroup` がウィンドウを 1 つも出さなくなる。ウィンドウの復元を切る目的でも付けない（2026-10-05）
- `open` で起動したプロセスのコマンドラインはシンボリックリンクを解決したパス（`/var/…` → `/private/var/…`）になる。`pgrep -f` で PID を探すときは `pwd -P` で解決したパスで突き合わせる（2026-10-05）
- 起動直後に `CGWindowListCopyWindowInfo` で取ったウィンドウ番号は、数秒後に無効になることがある（`screencapture: could not create image from window`）。番号は撮る直前に毎回引き直す（2026-10-05）
- アプリを `kill` した直後に次を `open` すると、次のウィンドウが出ないことがある。プロセスが消えるのを待ってから 1 秒ほど空ける（2026-10-05）
- macOS では起動時に最初の `TextField` へフォーカスが当たり、中の数字が選択された見た目で写る。撮影モードでは `@FocusState` を少し待ってから false にして外す（2026-10-05）
- ウィンドウの中身を 1280x800 pt に固定すると、タイトルバー込みで 1280x832 pt（Retina で 2560x1664 px）になり、2880x1800 のキャンバスに収まる（2026-10-05）

## iOS のスクリーンショット撮影（Tools/capture_screenshots.sh）

- `simctl terminate` の直後に `simctl launch` すると、アプリが出る前のホーム画面を「連続 2 枚が一致した」として撮ってしまうことがある。終了と起動の間に数秒空ける（`RELAUNCH_INTERVAL`）（2026-10-05）

## App Store Connect

- iOS と macOS を 1 ターゲット・同じ Bundle ID で配信していても、App Store Connect の `appStoreVersions` は `platform`（`IOS` / `MAC_OS`）ごとに別で、説明文・スクリーンショットの置き場（`appStoreVersionLocalizations`）も別。`filter[platform]` を省くと iOS しか見えない（2026-10-05）
