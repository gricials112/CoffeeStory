import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import Foundation

let size = 1024
let cs = CGColorSpaceCreateDeviceRGB()
guard let ctx = CGContext(data: nil, width: size, height: size,
                          bitsPerComponent: 8, bytesPerRow: 0, space: cs,
                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { exit(1) }

func color(_ hex: UInt, _ a: CGFloat = 1) -> CGColor {
    CGColor(red: CGFloat((hex >> 16) & 0xff) / 255,
            green: CGFloat((hex >> 8) & 0xff) / 255,
            blue: CGFloat(hex & 0xff) / 255, alpha: a)
}

let S = CGFloat(size)
// 背景渐变（浓缩深褐）
let grad = CGGradient(colorsSpace: cs,
                      colors: [color(0x2A1A11), color(0x5A3A24)] as CFArray,
                      locations: [0, 1])!
ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: S), end: CGPoint(x: S, y: 0), options: [])

let c = CGPoint(x: S / 2, y: S / 2)
let r = S * 0.30
let lw = S * 0.085

// 萃取环轨道
ctx.setLineCap(.round)
ctx.setLineWidth(lw)
ctx.setStrokeColor(color(0xC2761B, 0.28))
ctx.addArc(center: c, radius: r, startAngle: 0, endAngle: .pi * 2, clockwise: false)
ctx.strokePath()

// 萃取环进度（金色，约 75%）
ctx.setStrokeColor(color(0xE6C25E))
let start = CGFloat.pi / 2          // 顶部（CG 坐标 y 向上）
ctx.addArc(center: c, radius: r, startAngle: start, endAngle: start - .pi * 1.5, clockwise: true)
ctx.strokePath()

// 中心咖啡豆
ctx.saveGState()
ctx.translateBy(x: c.x, y: c.y)
ctx.rotate(by: .pi / 5)
let bw = r * 0.60, bh = r * 0.92
ctx.setFillColor(color(0xF3E9DB))
ctx.addEllipse(in: CGRect(x: -bw, y: -bh, width: bw * 2, height: bh * 2))
ctx.fillPath()
// 豆纹
ctx.setStrokeColor(color(0x4A2E1B))
ctx.setLineWidth(lw * 0.5)
let crease = CGMutablePath()
crease.move(to: CGPoint(x: 0, y: bh * 0.82))
crease.addCurve(to: CGPoint(x: 0, y: -bh * 0.82),
                control1: CGPoint(x: bw * 0.95, y: bh * 0.2),
                control2: CGPoint(x: -bw * 0.95, y: -bh * 0.2))
ctx.addPath(crease)
ctx.strokePath()
ctx.restoreGState()

guard let img = ctx.makeImage() else { exit(1) }
let url = URL(fileURLWithPath: CommandLine.arguments[1])
guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else { exit(1) }
CGImageDestinationAddImage(dest, img, nil)
CGImageDestinationFinalize(dest)
print("wrote \(url.path)")
