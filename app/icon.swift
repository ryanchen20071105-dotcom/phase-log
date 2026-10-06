// 生成 App 图标（1024×1024 PNG）：白色圆角方块 + 三条黑线空心阶段条 + 黑色“今天”针
// 用法：swiftc -o makeicon icon.swift -framework Cocoa && ./makeicon icon_1024.png
import Cocoa

let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon_1024.png"
let S: CGFloat = 1024
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1024, pixelsHigh: 1024, bitsPerSample: 8,
                           samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                           bytesPerRow: 0, bitsPerPixel: 0)!
let gc = NSGraphicsContext(bitmapImageRep: rep)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = gc
let cg = gc.cgContext

func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xff) / 255, green: CGFloat((hex >> 8) & 0xff) / 255,
            blue: CGFloat(hex & 0xff) / 255, alpha: a)
}
// 以左上角为原点的矩形 → AppKit 坐标
func R(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> NSRect { NSRect(x: x, y: S - y - h, width: w, height: h) }
// 苹果图标的连续圆角，用超椭圆近似
func squircle(_ r: NSRect, _ n: CGFloat = 5) -> NSBezierPath {
    let p = NSBezierPath()
    for i in 0...720 {
        let t = CGFloat(i) / 720 * 2 * .pi, c = cos(t), s = sin(t)
        let pt = NSPoint(x: r.midX + r.width / 2 * copysign(pow(abs(c), 2 / n), c),
                         y: r.midY + r.height / 2 * copysign(pow(abs(s), 2 / n), s))
        if i == 0 { p.move(to: pt) } else { p.line(to: pt) }
    }
    p.close()
    return p
}

// 底板：阴影 + 白到浅灰的渐变
let body = squircle(R(100, 100, 824, 824))
cg.saveGState()
cg.setShadow(offset: CGSize(width: 0, height: -14), blur: 34, color: NSColor(white: 0, alpha: 0.30).cgColor)
rgb(0xffffff).setFill()
body.fill()
cg.restoreGState()
NSGradient(starting: rgb(0xffffff), ending: rgb(0xf0f1f4))!.draw(in: body, angle: -90)

// 三条阶段条：黑色描边、空心（参考线条风格的图标）
func bar(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat) {
    let h: CGFloat = 116, lw: CGFloat = 30
    let r = R(x + lw / 2, y + lw / 2, w - lw, h - lw)   // 往里缩半个线宽，外沿正好是 (x, y, w, h)
    let p = NSBezierPath(roundedRect: r, xRadius: (h - lw) / 2, yRadius: (h - lw) / 2)
    p.lineWidth = lw
    rgb(0x111111).setStroke()
    p.stroke()
}
bar(190, 292, 480)
bar(350, 454, 484)
bar(244, 616, 340)

// 黑色“今天”针（白色间隙让它和黑框交叉处分开）
let lx: CGFloat = 716, top: CGFloat = 240, bottom: CGFloat = 800
let line = NSBezierPath()
line.move(to: NSPoint(x: lx, y: S - top))
line.line(to: NSPoint(x: lx, y: S - bottom))
line.lineCapStyle = .round
line.lineWidth = 54          // 白色间隙：红线穿过黑框的地方断开，更干净
rgb(0xffffff).setStroke()
line.stroke()
line.lineWidth = 18
rgb(0x111111).setStroke()
line.stroke()
rgb(0xffffff).setFill()
NSBezierPath(ovalIn: NSRect(x: lx - 50, y: S - top - 50, width: 100, height: 100)).fill()
rgb(0x111111).setFill()
NSBezierPath(ovalIn: NSRect(x: lx - 34, y: S - top - 34, width: 68, height: 68)).fill()

NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
print("图标：\(out)")
