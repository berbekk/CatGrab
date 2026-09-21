// Рисует иконку приложения из вектора кота по сетке иконок macOS
// (холст 1024, тело 824 со скруглением «continuous», тень вниз).
//
//   swift scripts/render-app-icon.swift design/cat.svg Sources/CatGrab/Resources/AppIcon.png 1024
//   swift scripts/render-app-icon.swift design/cat.svg design/icon.png 512
//
// AppIcon.png — исходник: build.sh собирает из него AppIcon.icns на каждой сборке.

import AppKit
import SwiftUI

let args = CommandLine.arguments
let svgPath = args[1], outPath = args[2]
let size = CGFloat(Double(args[3]) ?? 1024)

guard let svg = NSImage(contentsOf: URL(fileURLWithPath: svgPath)) else {
    fatalError("NSImage cannot read SVG")
}
// Рисуем вектор сразу в итоговом размере — иначе SVG растеризуется в родные 99 px и мылится.
let catWidth: CGFloat = 560 * size / 1024
let catSize = NSSize(width: catWidth, height: catWidth * svg.size.height / svg.size.width)
let cat = NSImage(size: catSize, flipped: false) { rect in
    svg.draw(in: rect)
    return true
}

/// Сетка иконок macOS: холст 1024, тело 824 с «continuous» скруглением 185, тень вниз.
struct AppIcon: View {
    let cat: NSImage
    var body: some View {
        let body: CGFloat = 824
        let shape = RoundedRectangle(cornerRadius: 185.4, style: .continuous)
        ZStack {
            shape
                .fill(LinearGradient(colors: [Color(white: 1.0), Color(red: 0.91, green: 0.91, blue: 0.93)],
                                     startPoint: .top, endPoint: .bottom))
                .overlay(shape.strokeBorder(Color.black.opacity(0.06), lineWidth: 2))
                .frame(width: body, height: body)
                .shadow(color: .black.opacity(0.28), radius: 12, x: 0, y: 10)
            Image(nsImage: cat)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .frame(width: 560)
                .offset(y: 8)
        }
        .frame(width: 1024, height: 1024)
    }
}

MainActor.assumeIsolated {
    let renderer = ImageRenderer(content: AppIcon(cat: cat).scaleEffect(size / 1024).frame(width: size, height: size))
    renderer.scale = 1
    guard let cg = renderer.cgImage else { fatalError("render failed") }
    let rep = NSBitmapImageRep(cgImage: cg)
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: outPath))
    print("wrote \(outPath) \(cg.width)x\(cg.height)")
}
