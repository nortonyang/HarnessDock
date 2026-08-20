#!/usr/bin/env swift
// Generates Resources/AppIcon.icns for the DS Harness macOS app.
// Renders the brand gradient + SF Symbol "sparkles" at every icon size and
// packs them with iconutil. Run from the repository root:
//   swift scripts/generate_icon.swift

import AppKit

let arguments = CommandLine.arguments
guard arguments.count >= 2 else {
    FileHandle.standardError.write(Data("usage: generate_icon.swift <output.icns>\n".utf8))
    exit(EXIT_FAILURE)
}
let outputURL = URL(fileURLWithPath: arguments[1]).standardizedFileURL
let iconsetURL = outputURL.deletingLastPathComponent()
    .appendingPathComponent("AppIcon.iconset")

try? FileManager.default.removeItem(at: iconsetURL)
try FileManager.default.createDirectory(
    at: iconsetURL,
    withIntermediateDirectories: true
)

// --- Draw the master 1024x1024 artwork -------------------------------------
let masterSize: CGFloat = 1024
let master = NSImage(size: NSSize(width: masterSize, height: masterSize))
master.lockFocus()

let bounds = NSRect(x: 0, y: 0, width: masterSize, height: masterSize)
let rounded = NSBezierPath(
    roundedRect: bounds.insetBy(dx: 12, dy: 12),
    xRadius: 186,
    yRadius: 186
)
let gradient = NSGradient(colors: [
    NSColor(red: 0.31, green: 0.40, blue: 0.97, alpha: 1),
    NSColor(red: 0.47, green: 0.28, blue: 0.94, alpha: 1),
])!
gradient.draw(in: rounded, angle: -48)
NSColor(white: 0.96, alpha: 0.06).setStroke()
rounded.lineWidth = 4
rounded.stroke()

if let symbol = NSImage(systemSymbolName: "sparkles", accessibilityDescription: nil) {
    let white = NSColor.white
    let palette = NSImage.SymbolConfiguration(paletteColors: [white])
    if let configured = symbol.withSymbolConfiguration(palette) {
        let side: CGFloat = 520
        let origin = (masterSize - side) / 2
        configured.draw(
            in: NSRect(x: origin, y: origin, width: side, height: side),
            from: .zero,
            operation: .sourceOver,
            fraction: 1
        )
    }
}

master.unlockFocus()

// --- Downscale into the iconset --------------------------------------------
let entries: [(points: Int, scale: Int, filename: String)] = [
    (16, 1, "icon_16x16.png"),
    (16, 2, "icon_16x16@2x.png"),
    (32, 1, "icon_32x32.png"),
    (32, 2, "icon_32x32@2x.png"),
    (128, 1, "icon_128x128.png"),
    (128, 2, "icon_128x128@2x.png"),
    (256, 1, "icon_256x256.png"),
    (256, 2, "icon_256x256@2x.png"),
    (512, 1, "icon_512x512.png"),
    (512, 2, "icon_512x512@2x.png"),
]

for entry in entries {
    let pixelSide = entry.points * entry.scale
    let scaled = NSImage(size: NSSize(width: pixelSide, height: pixelSide))
    scaled.lockFocus()
    NSGraphicsContext.current?.imageInterpolation = .high
    master.draw(
        in: NSRect(x: 0, y: 0, width: pixelSide, height: pixelSide),
        from: NSRect(x: 0, y: 0, width: masterSize, height: masterSize),
        operation: .copy,
        fraction: 1
    )
    scaled.unlockFocus()

    guard let tiff = scaled.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let png = bitmap.representation(using: .png, properties: [:])
    else {
        FileHandle.standardError.write(Data("failed to render \(entry.filename)\n".utf8))
        exit(EXIT_FAILURE)
    }
    try png.write(to: iconsetURL.appendingPathComponent(entry.filename))
}

// --- Pack with iconutil ----------------------------------------------------
let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconsetURL.path, "-o", outputURL.path]
iconutil.standardOutput = Pipe()
iconutil.standardError = Pipe()
try iconutil.run()
iconutil.waitUntilExit()
guard iconutil.terminationStatus == 0 else {
    FileHandle.standardError.write(Data("iconutil failed\n".utf8))
    exit(EXIT_FAILURE)
}

try? FileManager.default.removeItem(at: iconsetURL)
print("Wrote \(outputURL.path)")
