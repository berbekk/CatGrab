// Рисует иконку приложения по сетке иконок macOS (холст 1024, тело 824 со скруглением
// «continuous», тень вниз): кот из вектора перед кольцом из шести цветных секторов —
// тем самым круговым меню, которое приложение открывает.
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
let catWidth: CGFloat = 500
let catSize = NSSize(width: catWidth, height: catWidth * svg.size.height / svg.size.width)
let cat = NSImage(size: catSize, flipped: false) { rect in
    svg.draw(in: rect)
    return true
}

/// Сектор кольца: дуга между двумя радиусами.
struct RingSector: Shape {
    let start: Double, end: Double, inner: CGFloat, outer: CGFloat

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        var path = Path()
        path.addArc(center: center, radius: outer, startAngle: .radians(start), endAngle: .radians(end), clockwise: false)
        path.addArc(center: center, radius: inner, startAngle: .radians(end), endAngle: .radians(start), clockwise: true)
        path.closeSubpath()
        return path
    }
}

/// Шесть секторов со скруглёнными углами; `color(index)` красит каждый.
struct SectorRing<Fill: ShapeStyle>: View {
    static var outer: CGFloat { 352 }
    static var inner: CGFloat { 212 }
    /// Радиус скругления углов сектора: сектор рисуется меньше на `corner` и обводится линией `2 × corner`.
    static var corner: CGFloat { 26 }
    let fill: (Int) -> Fill

    var body: some View {
        ZStack {
            ForEach(0..<6, id: \.self) { index in
                let step = 2 * Double.pi / 6
                let gap = Double(Self.corner + 9) / Double(Self.outer)
                let sector = RingSector(
                    start: -Double.pi / 2 + Double(index) * step + gap,
                    end: -Double.pi / 2 + Double(index + 1) * step - gap,
                    inner: Self.inner + Self.corner,
                    outer: Self.outer - Self.corner
                )
                sector
                    .fill(fill(index))
                    .overlay(sector.stroke(fill(index), style: StrokeStyle(lineWidth: 2 * Self.corner, lineJoin: .round)))
            }
        }
    }
}

/// Силуэт кота, раздутый цветом фона: зазор между котом и кольцом, чтобы они не слипались.
struct CatHalo: View {
    let cat: NSImage, width: CGFloat, color: Color

    var body: some View {
        ZStack {
            ForEach(0..<24, id: \.self) { index in
                let angle = Double(index) / 24 * 2 * Double.pi
                Image(nsImage: cat)
                    .resizable()
                    .renderingMode(.template)
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .foregroundStyle(color)
                    .frame(width: width)
                    .offset(x: CGFloat(cos(angle)) * 22, y: CGFloat(sin(angle)) * 22)
            }
        }
    }
}

/// Сетка иконок macOS: холст 1024, тело 824 с «continuous» скруглением 185, тень вниз.
struct AppIcon: View {
    let cat: NSImage

    /// Синий, зелёный, жёлтый, оранжевый, розовый, фиолетовый — по часовой стрелке сверху.
    static let colors: [Color] = [
        Color(red: 0.04, green: 0.52, blue: 1.0),
        Color(red: 0.19, green: 0.82, blue: 0.35),
        Color(red: 1.0, green: 0.84, blue: 0.04),
        Color(red: 1.0, green: 0.62, blue: 0.04),
        Color(red: 1.0, green: 0.22, blue: 0.37),
        Color(red: 0.75, green: 0.35, blue: 0.95)
    ]

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
            SectorRing { Self.colors[$0] }
                .frame(width: body, height: body)
                // Лёгкий блик сверху — кольцо читается стеклянным, а не плоским.
                .overlay(
                    LinearGradient(colors: [Color.white.opacity(0.16), Color.white.opacity(0)],
                                   startPoint: .top, endPoint: .center)
                        .mask(SectorRing { _ in Color.black })
                )
            Image(nsImage: cat)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .frame(width: catWidth)
                .background(CatHalo(cat: cat, width: catWidth, color: Color(white: 0.97)))
                .offset(y: 10)
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
