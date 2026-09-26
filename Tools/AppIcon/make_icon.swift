// Renders Nurikabe/Assets.xcassets/AppIcon.appiconset/AppIcon.png (1024×1024,
// opaque): a 5×5 chart, indigo sea around paper islands with serif numerals.
//   swiftc -o /tmp/nurikabe-icon Tools/AppIcon/make_icon.swift && /tmp/nurikabe-icon
// CoreGraphics rather than AppKit: `noneSkipLast` is an opaque RGBX context,
// so the PNG carries no alpha channel (App Store icons must not).
import CoreGraphics
import CoreText
import Foundation
import ImageIO
import UniformTypeIdentifiers

let size = 1024
let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                    space: CGColorSpace(name: CGColorSpace.sRGB)!,
                    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!

func color(_ hex: UInt32) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
}
let sea = color(0x233A5E), paper = color(0xFBF8F1), numeral = color(0x1B2C49), ochre = color(0xC98A1B)

// A real board: NurikabeGenerator 5×5 steady, seed 10 — legal and unique.
// '.' land, '#' sea, digits are clues.
let rows = ["#.2##",
            "####.",
            "#..#.",
            "##3#.",
            ".2##4"]
ctx.setFillColor(sea)
ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))
let margin = 92.0
let cell = (Double(size) - 2 * margin) / 5
let baseFont = CTFontCreateWithName("NewYorkLarge-Semibold" as CFString, cell * 0.62, nil)
for (r, row) in rows.enumerated() {
    for (c, ch) in row.enumerated() where ch != "#" {
        // CoreGraphics' origin is bottom-left.
        let rect = CGRect(x: margin + Double(c) * cell, y: Double(size) - margin - Double(r + 1) * cell,
                          width: cell, height: cell).insetBy(dx: 5, dy: 5)
        ctx.setFillColor(paper)
        ctx.addPath(CGPath(roundedRect: rect, cornerWidth: 14, cornerHeight: 14, transform: nil))
        ctx.fillPath()
        if let v = ch.wholeNumberValue {
            let attrs = [kCTFontAttributeName: baseFont,
                         kCTForegroundColorAttributeName: v == 3 ? ochre : numeral] as CFDictionary
            let line = CTLineCreateWithAttributedString(CFAttributedStringCreate(nil, "\(v)" as CFString, attrs))
            let bounds = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
            ctx.textPosition = CGPoint(x: rect.midX - bounds.midX, y: rect.midY - bounds.midY)
            CTLineDraw(line, ctx)
        }
    }
}
let url = URL(fileURLWithPath: "Nurikabe/Assets.xcassets/AppIcon.appiconset/AppIcon.png")
let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
CGImageDestinationFinalize(dest)
print("wrote \(url.path)")
