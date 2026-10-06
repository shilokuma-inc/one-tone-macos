// iOS の代替アイコン（テーマカラーごと）を、既存の iOS 用アイコンから作る。
// 元のアイコンは白黒なので色相の回転では色が付かない。明るさに差し色を掛け合わせ、白い部分を差し色に、黒い部分を黒のまま残す。
// 差し色は ThemeColor.swift の値をそのまま使う（一緒にコンパイルする）。
//
//   swiftc -O -parse-as-library Tools/make_alternate_icons.swift OneTone/ThemeColor.swift OneTone/Theme.swift -o make_alternate_icons
//   ./make_alternate_icons OneTone/Assets.xcassets
//
// Assets.xcassets/AppIcon-<rawValue>.appiconset を作り直す（iOS 用の 1024px 1 枚。App Store 用にアルファ無し）。
// テーマを足したら実行し直し、project.pbxproj の ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES にも足す。

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

@main
struct MakeAlternateIcons {
    static func main() {
        let arguments = CommandLine.arguments
        guard arguments.count == 2 else {
            fail("使い方: make_alternate_icons <Assets.xcassets のパス>")
        }
        let catalog = URL(fileURLWithPath: arguments[1])
        let sourceURL = catalog.appendingPathComponent("AppIcon.appiconset/AppIcon_iOS_1024.png")
        guard let source = CGImageSourceCreateWithURL(sourceURL as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            fail("\(sourceURL.path) を読めませんでした")
        }
        let pixels = rgbPixels(of: image)
        for theme in ThemeColor.allCases {
            let name = theme.alternateIconName
            let directory = catalog.appendingPathComponent("\(name).appiconset")
            try? FileManager.default.removeItem(at: directory)
            do {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                let fileName = "\(name).png"
                try writePNG(tinted(pixels, accentHex: theme.accentHex), width: image.width, height: image.height,
                             to: directory.appendingPathComponent(fileName))
                try contentsJSON(fileName: fileName).write(to: directory.appendingPathComponent("Contents.json"))
            } catch {
                fail("\(directory.path) を作れませんでした: \(error)")
            }
            print(directory.path)
        }
    }

    /// 8bit RGB（アルファ無し）に描き直した画素
    static func rgbPixels(of image: CGImage) -> [UInt8] {
        var pixels = [UInt8](repeating: 0, count: image.width * image.height * 4)
        pixels.withUnsafeMutableBytes { buffer in
            let context = CGContext(
                data: buffer.baseAddress, width: image.width, height: image.height, bitsPerComponent: 8,
                bytesPerRow: image.width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
            )
            context?.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        }
        return pixels
    }

    /// 画素の明るさに差し色を掛け合わせる（白 → 差し色、黒 → 黒）
    static func tinted(_ pixels: [UInt8], accentHex: UInt32) -> [UInt8] {
        let accent = [Double((accentHex >> 16) & 0xFF), Double((accentHex >> 8) & 0xFF), Double(accentHex & 0xFF)]
        var result = pixels
        for index in stride(from: 0, to: pixels.count, by: 4) {
            let luminance = (0.2126 * Double(pixels[index]) + 0.7152 * Double(pixels[index + 1])
                + 0.0722 * Double(pixels[index + 2])) / 255
            for channel in 0..<3 {
                result[index + channel] = UInt8((accent[channel] * luminance).rounded())
            }
        }
        return result
    }

    static func writePNG(_ pixels: [UInt8], width: Int, height: Int, to url: URL) throws {
        var pixels = pixels
        let image = pixels.withUnsafeMutableBytes { buffer in
            CGContext(
                data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                bytesPerRow: width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
            )?.makeImage()
        }
        guard let image,
              let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            throw CocoaError(.fileWriteUnknown)
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw CocoaError(.fileWriteUnknown) }
    }

    /// iOS 用の single size（1024px）だけを持つアイコンセット。macOS のアイコンは変えない
    static func contentsJSON(fileName: String) -> Data {
        Data("""
        {
          "images" : [
            {
              "filename" : "\(fileName)",
              "idiom" : "universal",
              "platform" : "ios",
              "size" : "1024x1024"
            }
          ],
          "info" : {
            "author" : "xcode",
            "version" : 1
          }
        }

        """.utf8)
    }

    static func fail(_ message: String) -> Never {
        FileHandle.standardError.write(Data("\(message)\n".utf8))
        exit(1)
    }
}
