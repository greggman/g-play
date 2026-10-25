// Renders the app icon (the g-play.svg design) on a dark background:
// swift scripts/make-icon.swift PlayIt/Resources/Assets.xcassets/AppIcon.appiconset/icon-1024.png 0E0E10
import AppKit

let args = CommandLine.arguments
let out = args[1]
let bgHex = UInt32(args[2], radix: 16)!
let contentScale = args.count > 3 ? CGFloat(Double(args[3])!) : 0.8
let size = 1024
let space = CGColorSpace(name: CGColorSpace.sRGB)!
func color(_ hex: UInt32) -> CGColor {
  CGColor(red: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255, blue: CGFloat(hex & 255) / 255, alpha: 1)
}
let c = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                  bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
let s = CGFloat(size)
c.setFillColor(color(bgHex)); c.fill(CGRect(x: 0, y: 0, width: s, height: s))
// SVG coordinates (256 square, y down), scaled into the middle of the icon.
c.translateBy(x: 0, y: s); c.scaleBy(x: 1, y: -1)
let k = s * contentScale / 256
c.translateBy(x: s * (1 - contentScale) / 2, y: s * (1 - contentScale) / 2)
c.scaleBy(x: k, y: k)
let orange = color(0xFF9A00)

// Ring: outer circle minus inner circle.
let ring = CGMutablePath()
ring.addEllipse(in: CGRect(x: 7.5, y: 7.5, width: 241, height: 241))
ring.addEllipse(in: CGRect(x: 51, y: 52, width: 154, height: 154))
c.saveGState()
// Wedge cut out of the ring at the upper right.
let wedge = CGMutablePath()
wedge.move(to: CGPoint(x: 128, y: 128)); wedge.addLine(to: CGPoint(x: 212, y: -32)); wedge.addLine(to: CGPoint(x: 288, y: 128)); wedge.closeSubpath()
let keep = CGMutablePath()
keep.addRect(CGRect(x: -100, y: -100, width: 500, height: 500)); keep.addPath(wedge)
c.addPath(keep); c.clip(using: .evenOdd)
c.addPath(ring); c.setFillColor(orange); c.fillPath(using: .evenOdd)
c.restoreGState()
// Round end.
let dotR: CGFloat = 16 * 1.39062
c.setFillColor(orange)
c.fillEllipse(in: CGRect(x: 226.25 - dotR, y: 126.75 - dotR, width: 2 * dotR, height: 2 * dotR))
// Play triangle.
func tf(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: -0.836207 * y + 289.034, y: 0.836207 * x - 28.0345) }
c.move(to: tf(186, 128)); c.addLine(to: tf(244, 224)); c.addLine(to: tf(128, 224)); c.closePath()
c.setFillColor(color(0xFFFFFF)); c.fillPath()

let rep = NSBitmapImageRep(cgImage: c.makeImage()!)
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
