import AppKit
import CoreGraphics
import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let source = root.appendingPathComponent("Resources/IconSources/decaf-refined-proposals.png")
let selected = root.appendingPathComponent("Resources/IconSources/decaf-selected-bottom-left.png")
let assetRoot = root.appendingPathComponent("Resources/Assets.xcassets", isDirectory: true)
let appIconSet = assetRoot.appendingPathComponent("AppIcon.appiconset", isDirectory: true)
let iconset = root.appendingPathComponent("Resources/Decaf.iconset", isDirectory: true)
let icns = root.appendingPathComponent("Resources/Decaf.icns")

struct IconSlot {
    let size: String
    let scale: String
    let pixels: Int
    let idiom: String

    var filename: String {
        let suffix = scale == "2x" ? "@2x" : ""
        return "icon_\(size.replacingOccurrences(of: ".", with: "_"))\(suffix).png"
    }

    var iconsetFilename: String {
        switch pixels {
        case 16: "icon_16x16.png"
        case 32 where size == "16": "icon_16x16@2x.png"
        case 32: "icon_32x32.png"
        case 64: "icon_32x32@2x.png"
        case 128: "icon_128x128.png"
        case 256 where size == "128": "icon_128x128@2x.png"
        case 256: "icon_256x256.png"
        case 512 where size == "256": "icon_256x256@2x.png"
        case 512: "icon_512x512.png"
        case 1024: "icon_512x512@2x.png"
        default: filename
        }
    }
}

let slots = [
    IconSlot(size: "16", scale: "1x", pixels: 16, idiom: "mac"),
    IconSlot(size: "16", scale: "2x", pixels: 32, idiom: "mac"),
    IconSlot(size: "32", scale: "1x", pixels: 32, idiom: "mac"),
    IconSlot(size: "32", scale: "2x", pixels: 64, idiom: "mac"),
    IconSlot(size: "128", scale: "1x", pixels: 128, idiom: "mac"),
    IconSlot(size: "128", scale: "2x", pixels: 256, idiom: "mac"),
    IconSlot(size: "256", scale: "1x", pixels: 256, idiom: "mac"),
    IconSlot(size: "256", scale: "2x", pixels: 512, idiom: "mac"),
    IconSlot(size: "512", scale: "1x", pixels: 512, idiom: "mac"),
    IconSlot(size: "512", scale: "2x", pixels: 1024, idiom: "mac")
]

func cgImage(from url: URL) -> CGImage {
    guard let image = NSImage(contentsOf: url),
          let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        fatalError("Unable to load image at \(url.path)")
    }
    return cgImage
}

func writePNG(_ image: CGImage, to url: URL) throws {
    let rep = NSBitmapImageRep(cgImage: image)
    guard let data = rep.representation(using: .png, properties: [:]) else {
        fatalError("Unable to create PNG for \(url.path)")
    }
    try data.write(to: url)
}

func render(_ image: CGImage, pixels: Int, rounded: Bool = false) -> CGImage {
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
    guard let context = CGContext(
        data: nil,
        width: pixels,
        height: pixels,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        fatalError("Unable to create CGContext")
    }

    context.interpolationQuality = .high
    let canvas = CGRect(x: 0, y: 0, width: pixels, height: pixels)
    context.clear(canvas)

    if rounded {
        let radius = CGFloat(pixels) * 0.185
        context.addPath(CGPath(roundedRect: canvas, cornerWidth: radius, cornerHeight: radius, transform: nil))
        context.clip()
    }

    context.draw(image, in: canvas)
    guard let output = context.makeImage() else {
        fatalError("Unable to render image")
    }
    return output
}

let sheet = cgImage(from: source)
let tileWidth = sheet.width / 3
let tileHeight = sheet.height / 2
let bottomLeftTile = CGRect(x: 0, y: tileHeight, width: tileWidth, height: tileHeight)
guard let tile = sheet.cropping(to: bottomLeftTile) else {
    fatalError("Unable to crop bottom-left proposal tile")
}

// Crop away the proposal-sheet padding so the selected icon fills the app icon canvas.
let artworkRect = CGRect(
    x: CGFloat(tile.width) * 0.112,
    y: CGFloat(tile.height) * 0.038,
    width: CGFloat(tile.width) * 0.850,
    height: CGFloat(tile.height) * 0.850
)
guard let artwork = tile.cropping(to: artworkRect) else {
    fatalError("Unable to crop selected icon artwork")
}

let selected1024 = render(artwork, pixels: 1024, rounded: true)

try FileManager.default.createDirectory(at: selected.deletingLastPathComponent(), withIntermediateDirectories: true)
try writePNG(selected1024, to: selected)

try? FileManager.default.removeItem(at: appIconSet)
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: appIconSet, withIntermediateDirectories: true)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
try FileManager.default.createDirectory(at: assetRoot, withIntermediateDirectories: true)

for slot in slots {
    let rendered = render(selected1024, pixels: slot.pixels, rounded: true)
    try writePNG(rendered, to: appIconSet.appendingPathComponent(slot.filename))
    try writePNG(rendered, to: iconset.appendingPathComponent(slot.iconsetFilename))
}

let contents: [String: Any] = [
    "images": slots.map { slot in
        [
            "idiom": slot.idiom,
            "size": "\(slot.size)x\(slot.size)",
            "scale": slot.scale,
            "filename": slot.filename
        ]
    },
    "info": ["author": "xcode", "version": 1]
]
let data = try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
try data.write(to: appIconSet.appendingPathComponent("Contents.json"))
let assetContents = try JSONSerialization.data(withJSONObject: ["info": ["author": "xcode", "version": 1]], options: [.prettyPrinted, .sortedKeys])
try assetContents.write(to: assetRoot.appendingPathComponent("Contents.json"))

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", icns.path]
try iconutil.run()
iconutil.waitUntilExit()
if iconutil.terminationStatus != 0 {
    fatalError("iconutil failed")
}

print("Prepared AppIcon asset catalog and \(icns.path)")
