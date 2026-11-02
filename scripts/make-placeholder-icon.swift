#!/usr/bin/env swift
//
//  make-placeholder-icon.swift
//  Hidden Bar Plus
//
//  Renders the placeholder app icon (a menu bar with a chevron and a "+" badge)
//  into the asset catalog, the About-screen logo and the README image.
//
//      swift scripts/make-placeholder-icon.swift .
//
//  Replace the output with real artwork whenever you have it; this script only
//  exists so the project has a distinct icon from day one.
//

import AppKit

let root = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ".")

func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: CGColorSpaceCreateDeviceRGB(), components: [r, g, b, a])!
}

/// Draws the icon in a 1024-unit coordinate space scaled to `pixels`.
func draw(in ctx: CGContext, pixels: Int) {
    let s = CGFloat(pixels) / 1024
    ctx.scaleBy(x: s, y: s)

    // Big Sur-style rounded square with the standard transparent margin.
    let plate = CGRect(x: 100, y: 100, width: 824, height: 824)
    let plateHolder = CGPath(roundedRect: plate, cornerWidth: 185, cornerHeight: 185, transform: nil)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 24, color: color(0, 0, 0, 0.35))
    ctx.addPath(plateHolder)
    ctx.setFillColor(color(0.13, 0.15, 0.22))
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(plateHolder)
    ctx.clip()
    let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                              colors: [color(0.16, 0.19, 0.30), color(0.09, 0.11, 0.17)] as CFArray,
                              locations: [0, 1])!
    ctx.drawLinearGradient(gradient, start: CGPoint(x: plate.minX, y: plate.maxY),
                           end: CGPoint(x: plate.maxX, y: plate.minY), options: [])

    // The "menu bar": a translucent strip across the upper third.
    let bar = CGRect(x: plate.minX, y: 600, width: plate.width, height: 150)
    ctx.setFillColor(color(1, 1, 1, 0.12))
    ctx.fill(bar)
    ctx.setFillColor(color(1, 1, 1, 0.25))
    ctx.fill(CGRect(x: plate.minX, y: bar.minY - 4, width: plate.width, height: 4))

    // Chevron (the expand/collapse arrow) on the left of the bar.
    ctx.setStrokeColor(color(1, 1, 1, 0.95))
    ctx.setLineWidth(38)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    ctx.move(to: CGPoint(x: 330, y: 720))
    ctx.addLine(to: CGPoint(x: 270, y: 675))
    ctx.addLine(to: CGPoint(x: 330, y: 630))
    ctx.strokePath()

    // Three visible "icons" to the right of the chevron.
    ctx.setFillColor(color(1, 1, 1, 0.95))
    for x in [470, 580, 690] {
        ctx.fillEllipse(in: CGRect(x: CGFloat(x) - 24, y: 675 - 24, width: 48, height: 48))
    }

    // Faded icons below the bar: what got hidden.
    ctx.setFillColor(color(1, 1, 1, 0.18))
    for x in [250, 360, 470, 580] {
        ctx.fillEllipse(in: CGRect(x: CGFloat(x) - 24, y: 470 - 24, width: 48, height: 48))
    }
    ctx.restoreGState()

    // "+" badge, bottom right, overlapping the plate edge.
    let badge = CGRect(x: 600, y: 150, width: 300, height: 300)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -8), blur: 18, color: color(0, 0, 0, 0.35))
    ctx.setFillColor(color(0.98, 0.62, 0.11))
    ctx.fillEllipse(in: badge)
    ctx.restoreGState()
    ctx.setStrokeColor(color(1, 1, 1, 1))
    ctx.setLineWidth(46)
    ctx.setLineCap(.round)
    ctx.move(to: CGPoint(x: badge.midX - 85, y: badge.midY))
    ctx.addLine(to: CGPoint(x: badge.midX + 85, y: badge.midY))
    ctx.move(to: CGPoint(x: badge.midX, y: badge.midY - 85))
    ctx.addLine(to: CGPoint(x: badge.midX, y: badge.midY + 85))
    ctx.strokePath()
}

func png(pixels: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let gc = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = gc
    gc.cgContext.setAllowsAntialiasing(true)
    gc.cgContext.interpolationQuality = .high
    draw(in: gc.cgContext, pixels: pixels)
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

func write(_ data: Data, _ relative: String) throws {
    let url = root.appendingPathComponent(relative)
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try data.write(to: url)
    print("wrote \(relative)")
}

let appIcon = "hidden/Assets.xcassets/AppIcon.appiconset"
let sizes: [(String, Int)] = [
    ("icon_16@1x.png", 16), ("icon_16@2x.png", 32),
    ("icon_32@1x.png", 32), ("icon_32@2x.png", 64),
    ("icon_128@1x.png", 128), ("icon_128@2x.png", 256),
    ("icon_256@1x.png", 256), ("icon_256@2x.png", 512),
    ("icon_512@1x.png", 512), ("icon_512@2x.png", 1024),
]
do {
    var cache: [Int: Data] = [:]
    for (name, pixels) in sizes {
        if cache[pixels] == nil { cache[pixels] = png(pixels: pixels) }
        try write(cache[pixels]!, "\(appIcon)/\(name)")
    }
    let large = cache[1024]!
    try write(large, "hidden/Assets.xcassets/ic_logo.imageset/ic_logo.png")
    try write(large, "img/icon_512@2x.png")
} catch {
    FileHandle.standardError.write("failed: \(error)\n".data(using: .utf8)!)
    exit(1)
}
