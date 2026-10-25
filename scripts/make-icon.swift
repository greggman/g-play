// Renders the app icon: swift scripts/make-icon.swift <output.png>
import AppKit

let size = 1024
let output = CommandLine.arguments.dropFirst().first ?? "icon-1024.png"
let space = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                    space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
let s = CGFloat(size)

let gradient = CGGradient(colorsSpace: space, colors: [
  CGColor(red: 0.98, green: 0.30, blue: 0.42, alpha: 1),
  CGColor(red: 0.55, green: 0.18, blue: 0.75, alpha: 1),
] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: s), end: CGPoint(x: s, y: 0), options: [])

// Play triangle.
ctx.setFillColor(CGColor(gray: 1, alpha: 1))
ctx.move(to: CGPoint(x: s * 0.38, y: s * 0.28))
ctx.addLine(to: CGPoint(x: s * 0.38, y: s * 0.72))
ctx.addLine(to: CGPoint(x: s * 0.74, y: s * 0.50))
ctx.closePath()
ctx.fillPath()

let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: output))
