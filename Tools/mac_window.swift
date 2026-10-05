// 指定したプロセスが表示している一番大きなウィンドウの番号（kCGWindowNumber）と大きさ（pt）を出す。
// `screencapture -l <番号>` でそのウィンドウだけを撮るために使う（Tools/capture_mac_screenshots.sh）。
//
//   swiftc -O Tools/mac_window.swift -o mac_window && ./mac_window <pid>
//
// 出力はタブ区切りで 1 行: <ウィンドウ番号>\t<幅 pt>\t<高さ pt>
// ウィンドウがまだ無ければ何も出さず 1 で終わる（呼び出し側が起動を待つ）。
// ウィンドウの一覧と大きさは Screen Recording の許可が無くても取れる（タイトルだけは隠される）。

import CoreGraphics
import Foundation

guard CommandLine.arguments.count == 2 else {
    FileHandle.standardError.write(Data("使い方: mac_window <pid> | mac_window --list\n".utf8))
    exit(2)
}

guard let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
    as? [[String: Any]] else {
    FileHandle.standardError.write(Data("ウィンドウの一覧を取れませんでした\n".utf8))
    exit(1)
}

// 診断用: 画面に出ている通常のウィンドウをすべて出す（撮影が失敗したときに、何が出ているかを見るため）
if CommandLine.arguments[1] == "--list" {
    for info in windows {
        guard let layer = info[kCGWindowLayer as String] as? Int, layer == 0,
              let bounds = info[kCGWindowBounds as String] as? [String: Double] else { continue }
        let owner = info[kCGWindowOwnerName as String] as? String ?? "?"
        let pid = info[kCGWindowOwnerPID as String] as? Int32 ?? 0
        print("\(owner) (pid \(pid)) \(Int(bounds["Width"] ?? 0))x\(Int(bounds["Height"] ?? 0))")
    }
    exit(0)
}

guard let pid = Int32(CommandLine.arguments[1]) else {
    FileHandle.standardError.write(Data("pid が数値ではありません: \(CommandLine.arguments[1])\n".utf8))
    exit(2)
}

// レイヤー 0 が通常のウィンドウ。メニューやツールチップなどは別のレイヤーに出る
let candidates = windows.compactMap { info -> (number: Int, width: Double, height: Double)? in
    guard let owner = info[kCGWindowOwnerPID as String] as? Int32, owner == pid,
          let layer = info[kCGWindowLayer as String] as? Int, layer == 0,
          let number = info[kCGWindowNumber as String] as? Int,
          let bounds = info[kCGWindowBounds as String] as? [String: Double],
          let width = bounds["Width"], let height = bounds["Height"],
          width > 100, height > 100 else {
        return nil
    }
    return (number, width, height)
}

guard let window = candidates.max(by: { $0.width * $0.height < $1.width * $1.height }) else {
    exit(1)
}
print("\(window.number)\t\(Int(window.width))\t\(Int(window.height))")
