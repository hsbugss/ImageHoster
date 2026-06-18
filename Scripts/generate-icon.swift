#!/usr/bin/env swift

import AppKit
import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let assets = root.appendingPathComponent("Assets", isDirectory: true)
try FileManager.default.createDirectory(at: assets, withIntermediateDirectories: true)

let size = 1024
let rect = NSRect(x: 0, y: 0, width: size, height: size)
let image = NSImage(size: rect.size)

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(
        calibratedRed: CGFloat((hex >> 16) & 0xff) / 255,
        green: CGFloat((hex >> 8) & 0xff) / 255,
        blue: CGFloat(hex & 0xff) / 255,
        alpha: alpha
    )
}

func rounded(_ rect: NSRect, _ radius: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
}

func stroke(_ path: NSBezierPath, color: NSColor, width: CGFloat, lineCap: NSBezierPath.LineCapStyle = .round) {
    color.setStroke()
    path.lineWidth = width
    path.lineCapStyle = lineCap
    path.lineJoinStyle = .round
    path.stroke()
}

func fill(_ path: NSBezierPath, color: NSColor) {
    color.setFill()
    path.fill()
}

image.lockFocus()
NSGraphicsContext.current?.imageInterpolation = .high

let background = rounded(rect.insetBy(dx: 44, dy: 44), 216)
NSGraphicsContext.saveGraphicsState()
NSShadow().apply {
    $0.shadowOffset = NSSize(width: 0, height: -20)
    $0.shadowBlurRadius = 46
    $0.shadowColor = color(0x07141d, 0.35)
}
NSGradient(colors: [
    color(0x1aa6ff),
    color(0x1267f2),
    color(0x133a8f)
])!.draw(in: background, angle: -35)
NSGraphicsContext.restoreGraphicsState()

let glow = rounded(rect.insetBy(dx: 116, dy: 96), 168)
NSGradient(colors: [
    color(0x7ff7d6, 0.58),
    color(0xffffff, 0.05),
    color(0x0f4bd8, 0.0)
])!.draw(in: glow, angle: 50)

let bucketRect = NSRect(x: 214, y: 210, width: 596, height: 392)
let bucket = rounded(bucketRect, 96)
NSGraphicsContext.saveGraphicsState()
NSShadow().apply {
    $0.shadowOffset = NSSize(width: 0, height: -16)
    $0.shadowBlurRadius = 36
    $0.shadowColor = color(0x06111d, 0.28)
}
NSGradient(colors: [
    color(0xffffff, 0.95),
    color(0xdff6ff, 0.88)
])!.draw(in: bucket, angle: 90)
NSGraphicsContext.restoreGraphicsState()

stroke(bucket, color: color(0xffffff, 0.72), width: 12)

let bucketLip = rounded(NSRect(x: 244, y: 516, width: 536, height: 126), 62)
fill(bucketLip, color: color(0xf8fdff, 0.96))
stroke(bucketLip, color: color(0xb4e4ff, 0.9), width: 10)

for index in 0..<3 {
    let y = CGFloat(298 + index * 78)
    let line = NSBezierPath()
    line.move(to: NSPoint(x: 320, y: y))
    line.line(to: NSPoint(x: 704, y: y))
    stroke(line, color: color(0x5aaee9, 0.48), width: 22)
}

let cloud = NSBezierPath()
cloud.move(to: NSPoint(x: 342, y: 655))
cloud.curve(to: NSPoint(x: 438, y: 734), controlPoint1: NSPoint(x: 352, y: 708), controlPoint2: NSPoint(x: 388, y: 734))
cloud.curve(to: NSPoint(x: 575, y: 722), controlPoint1: NSPoint(x: 470, y: 808), controlPoint2: NSPoint(x: 548, y: 800))
cloud.curve(to: NSPoint(x: 690, y: 654), controlPoint1: NSPoint(x: 638, y: 724), controlPoint2: NSPoint(x: 682, y: 698))
cloud.curve(to: NSPoint(x: 644, y: 594), controlPoint1: NSPoint(x: 692, y: 618), controlPoint2: NSPoint(x: 670, y: 594))
cloud.line(to: NSPoint(x: 370, y: 594))
cloud.curve(to: NSPoint(x: 342, y: 655), controlPoint1: NSPoint(x: 336, y: 594), controlPoint2: NSPoint(x: 318, y: 626))
cloud.close()

NSGraphicsContext.saveGraphicsState()
NSShadow().apply {
    $0.shadowOffset = NSSize(width: 0, height: -8)
    $0.shadowBlurRadius = 18
    $0.shadowColor = color(0x0a3a72, 0.22)
}
fill(cloud, color: color(0xffffff, 0.96))
NSGraphicsContext.restoreGraphicsState()
stroke(cloud, color: color(0xb6edff, 0.9), width: 10)

let arrow = NSBezierPath()
arrow.move(to: NSPoint(x: 512, y: 432))
arrow.line(to: NSPoint(x: 512, y: 642))
stroke(arrow, color: color(0x1267f2), width: 52)

let arrowHead = NSBezierPath()
arrowHead.move(to: NSPoint(x: 424, y: 604))
arrowHead.line(to: NSPoint(x: 512, y: 700))
arrowHead.line(to: NSPoint(x: 600, y: 604))
stroke(arrowHead, color: color(0x1267f2), width: 52)

let sparkle1 = NSBezierPath()
sparkle1.move(to: NSPoint(x: 728, y: 744))
sparkle1.line(to: NSPoint(x: 728, y: 818))
sparkle1.move(to: NSPoint(x: 691, y: 781))
sparkle1.line(to: NSPoint(x: 765, y: 781))
stroke(sparkle1, color: color(0xffffff, 0.86), width: 18)

let sparkle2 = NSBezierPath()
sparkle2.move(to: NSPoint(x: 284, y: 704))
sparkle2.line(to: NSPoint(x: 284, y: 750))
sparkle2.move(to: NSPoint(x: 261, y: 727))
sparkle2.line(to: NSPoint(x: 307, y: 727))
stroke(sparkle2, color: color(0x90ffe2, 0.9), width: 12)

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Could not render icon PNG")
}

let output = assets.appendingPathComponent("AppIcon-1024.png")
try png.write(to: output)
print(output.path)

private extension NSShadow {
    func apply(_ configure: (NSShadow) -> Void) {
        configure(self)
        set()
    }
}
