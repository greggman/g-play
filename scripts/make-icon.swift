// Renders the app icon: the g-play.svg design on a purple gradient, with
// the G shaded orange to coral around the ring.
// swift scripts/make-icon.swift PlayIt/Resources/Assets.xcassets/AppIcon.appiconset/icon-1024.png
import AppKit

let args = CommandLine.arguments
let out = args[1]
let contentScale = args.count > 2 ? CGFloat(Double(args[2])!) : 0.8
let size = 1024
let space = CGColorSpace(name: CGColorSpace.sRGB)!
func color(_ hex: UInt32) -> CGColor {
  CGColor(red: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255, blue: CGFloat(hex & 255) / 255, alpha: 1)
}
let c = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                  bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
let s = CGFloat(size)
let background = CGGradient(colorsSpace: space, colors: [color(0x2B1250), color(0x120A24)] as CFArray, locations: [0, 1])!
c.drawLinearGradient(background, start: CGPoint(x: 0, y: s), end: CGPoint(x: s, y: 0), options: [])
// SVG coordinates (256 square, y down), scaled into the middle of the icon.
c.translateBy(x: 0, y: s); c.scaleBy(x: 1, y: -1)
let k = s * contentScale / 256
c.translateBy(x: s * (1 - contentScale) / 2, y: s * (1 - contentScale) / 2)
c.scaleBy(x: k, y: k)
let startColor: UInt32 = 0xFF9F43  // orange, at the G's upper end
let endColor: UInt32 = 0xFF4D6D  // coral, at the round end
func mix(_ t: CGFloat) -> CGColor {
  func ch(_ v: UInt32, _ shift: UInt32) -> CGFloat { CGFloat((v >> shift) & 255) }
  return CGColor(red: (ch(startColor, 16) + (ch(endColor, 16) - ch(startColor, 16)) * t) / 255,
                 green: (ch(startColor, 8) + (ch(endColor, 8) - ch(startColor, 8)) * t) / 255,
                 blue: (ch(startColor, 0) + (ch(endColor, 0) - ch(startColor, 0)) * t) / 255, alpha: 1)
}

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
c.addPath(ring); c.clip(using: .evenOdd)
// Shade around the ring, from the upper end counterclockwise to the round
// end, in thin wedges.
let center = CGPoint(x: 128, y: 128)
let startAngle = atan2(-160.0, 84.0)  // toward the wedge's upper corner
let endAngle = atan2(126.75 - 128, 226.25 - 128) - 2 * CGFloat.pi
let slices = 720
for i in 0..<slices {
  let t0 = CGFloat(i) / CGFloat(slices), t1 = CGFloat(i + 1) / CGFloat(slices)
  let a0 = startAngle + (endAngle - startAngle) * t0
  let a1 = startAngle + (endAngle - startAngle) * t1 - 0.003
  c.move(to: center)
  c.addLine(to: CGPoint(x: center.x + cos(a0) * 200, y: center.y + sin(a0) * 200))
  c.addLine(to: CGPoint(x: center.x + cos(a1) * 200, y: center.y + sin(a1) * 200))
  c.closePath()
  c.setFillColor(mix(t0)); c.fillPath()
}
c.restoreGState()
// Round end.
let dotR: CGFloat = 16 * 1.39062
c.setFillColor(mix(1))
c.fillEllipse(in: CGRect(x: 226.25 - dotR, y: 126.75 - dotR, width: 2 * dotR, height: 2 * dotR))
// Play triangle.
func tf(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: -0.836207 * y + 289.034, y: 0.836207 * x - 28.0345) }
c.move(to: tf(186, 128)); c.addLine(to: tf(244, 224)); c.addLine(to: tf(128, 224)); c.closePath()
c.setFillColor(color(0xFFFFFF)); c.fillPath()

let rep = NSBitmapImageRep(cgImage: c.makeImage()!)
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
