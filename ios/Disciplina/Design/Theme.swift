import CoreText
import SwiftUI
import UIKit

enum AppColor {
    static let background = Color(hex: 0x070708)
    static let positive = Color(hex: 0x5EE0C3)
    static let negative = Color(hex: 0xFF8A86)
    static let gold = Color(hex: 0xE6C15A)
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        let red = Double((hex >> 16) & 0xFF) / 255
        let green = Double((hex >> 8) & 0xFF) / 255
        let blue = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }
}

enum SectionKind: String, CaseIterable, Identifiable {
    case finance, bundles, geo, tasks, journal, rules
    var id: String { rawValue }
}

struct JellyPalette {
    var top: Color
    var mid: Color
    var bottom: Color
    var glow: Color
    var gloss: Double

    static let ink = JellyPalette(
        top: Color(hex: 0x2C313C),
        mid: Color(hex: 0x171B22),
        bottom: Color(hex: 0x101318),
        glow: .black,
        gloss: 0.22
    )
}

final class ThemeController: ObservableObject {
    @Published var monochrome: Bool {
        didSet { UserDefaults.standard.set(monochrome, forKey: "disciplina.mono") }
    }

    init() {
        monochrome = UserDefaults.standard.bool(forKey: "disciplina.mono")
    }

    var positive: Color { monochrome ? .white : AppColor.positive }
    var negative: Color { monochrome ? Color.white.opacity(0.55) : AppColor.negative }
    var gold: Color { monochrome ? Color.white.opacity(0.85) : AppColor.gold }
    var secondary: Color { Color.white.opacity(0.64) }
    var tertiary: Color { Color.white.opacity(0.42) }

    func palette(_ section: SectionKind) -> JellyPalette {
        if monochrome {
            let lift: Double
            switch section {
            case .finance: lift = 0.78
            case .bundles: lift = 0.68
            case .geo: lift = 0.56
            case .tasks: lift = 0.48
            case .journal: lift = 0.62
            case .rules: lift = 0.72
            }
            return grayRamp(lift)
        }
        switch section {
        case .finance:
            return JellyPalette(top: Color(hex: 0x3ED4B6), mid: Color(hex: 0x14967E), bottom: Color(hex: 0x0C6B59), glow: Color(hex: 0x0A4F43), gloss: 0.62)
        case .bundles:
            return JellyPalette(top: Color(hex: 0xF2C86A), mid: Color(hex: 0xE2AE38), bottom: Color(hex: 0xC48C1A), glow: Color(hex: 0x8A6410), gloss: 0.58)
        case .geo:
            return JellyPalette(top: Color(hex: 0x7E93D4), mid: Color(hex: 0x4C62B6), bottom: Color(hex: 0x384A96), glow: Color(hex: 0x243268), gloss: 0.5)
        case .tasks:
            return JellyPalette(top: Color(hex: 0xC48AD0), mid: Color(hex: 0x8E56A6), bottom: Color(hex: 0x693C84), glow: Color(hex: 0x4A2860), gloss: 0.55)
        case .journal:
            return JellyPalette(top: Color(hex: 0xF29A92), mid: Color(hex: 0xE16A64), bottom: Color(hex: 0xC24A48), glow: Color(hex: 0x8A3030), gloss: 0.58)
        case .rules:
            return JellyPalette(top: Color(hex: 0x6ED48A), mid: Color(hex: 0x34A35C), bottom: Color(hex: 0x1E7A40), glow: Color(hex: 0x145C30), gloss: 0.55)
        }
    }

    func tone(_ name: String) -> Color {
        switch name {
        case "positive": return positive
        case "negative": return negative
        case "accent": return monochrome ? Color.white.opacity(0.8) : palette(.tasks).top
        default: return secondary
        }
    }

    func amountColor(_ amount: Double) -> Color {
        if amount < 0 { return negative }
        if amount > 0 { return positive }
        return .white
    }

    func pillColors(_ status: String) -> (Color, Color) {
        if monochrome {
            return (Color.white.opacity(0.16), .white)
        }
        switch status {
        case "profit", "live":
            return (Color(hex: 0x2ECAA6), .white)
        case "test":
            return (Color(hex: 0xE2B043), Color(hex: 0x2A2112))
        case "stop":
            return (Color(hex: 0xE15B56), .white)
        default:
            return (Color.white.opacity(0.14), .white)
        }
    }

    private func grayRamp(_ lift: Double) -> JellyPalette {
        func shade(_ delta: Double) -> Color {
            let value = min(0.92, max(0.18, lift + delta))
            return Color(.sRGB, white: value, opacity: 1)
        }
        return JellyPalette(top: shade(0.1), mid: shade(0), bottom: shade(-0.12), glow: .black, gloss: 0.45)
    }
}

enum ManropeFont {
    static let faces = [
        "Manrope-Regular",
        "Manrope-Medium",
        "Manrope-SemiBold",
        "Manrope-Bold",
        "Manrope-ExtraBold",
    ]

    static func register() {
        for face in faces {
            let urls = [
                Bundle.main.url(forResource: face, withExtension: "ttf"),
                Bundle.main.url(forResource: face, withExtension: "ttf", subdirectory: "Resources/Fonts"),
                Bundle.main.url(forResource: face, withExtension: "ttf", subdirectory: "Fonts"),
            ]
            guard let url = urls.compactMap({ $0 }).first else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }

    static func uiFont(size: CGFloat, weight: UIFont.Weight) -> UIFont {
        let name: String
        switch weight {
        case .medium: name = "Manrope-Medium"
        case .semibold: name = "Manrope-SemiBold"
        case .bold: name = "Manrope-Bold"
        case .heavy, .black: name = "Manrope-ExtraBold"
        default: name = "Manrope-Regular"
        }
        let base = UIFont(name: name, size: size) ?? UIFont.systemFont(ofSize: size, weight: weight)
        let settings: [[UIFontDescriptor.FeatureKey: Any]] = [
            [
                UIFontDescriptor.FeatureKey.featureIdentifier: kNumberSpacingType,
                UIFontDescriptor.FeatureKey.typeIdentifier: kMonospacedNumbersSelector,
            ],
        ]
        let descriptor = base.fontDescriptor.addingAttributes([.featureSettings: settings])
        return UIFont(descriptor: descriptor, size: size)
    }

    static func font(size: CGFloat, weight: UIFont.Weight = .regular) -> Font {
        Font(uiFont(size: size, weight: weight))
    }
}

struct JellyBackground: View {
    var palette: JellyPalette

    var body: some View {
        ZStack {
            LinearGradient(colors: [palette.top, palette.mid, palette.bottom], startPoint: .top, endPoint: .bottom)
            LinearGradient(
                colors: [Color.white.opacity(palette.gloss), Color.white.opacity(palette.gloss * 0.28), .clear],
                startPoint: .top,
                endPoint: .center
            )
            RadialGradient(
                colors: [Color.white.opacity(palette.gloss * 0.45), .clear],
                center: UnitPoint(x: 0.5, y: -0.05),
                startRadius: 4,
                endRadius: 220
            )
            LinearGradient(colors: [.clear, Color.black.opacity(0.18)], startPoint: .center, endPoint: .bottom)
        }
    }
}

struct JellyChrome<S: Shape, Content: View>: View {
    var palette: JellyPalette
    var shape: S
    var glow: Bool = true
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .background(JellyBackground(palette: palette))
            .clipShape(shape)
            .overlay(
                shape.stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.7), Color.white.opacity(0.08), Color.white.opacity(0.0)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1.1
                )
            )
            .shadow(color: glow ? palette.glow.opacity(0.55) : .clear, radius: 16, y: 12)
            .shadow(color: Color.black.opacity(0.38), radius: 8, y: 4)
    }
}

struct CircleIconButton: View {
    var system: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(Circle().fill(Color.white.opacity(0.08)))
                .overlay(Circle().stroke(Color.white.opacity(0.08), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

struct ScreenHeader: View {
    var title: String
    var trailing: String?
    var onBack: () -> Void
    var onTrailing: () -> Void = {}

    var body: some View {
        ZStack {
            Text(title)
                .font(ManropeFont.font(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, 52)
            HStack {
                CircleIconButton(system: "chevron.left", action: onBack)
                Spacer()
                if let trailing {
                    CircleIconButton(system: trailing, action: onTrailing)
                } else {
                    Color.clear.frame(width: 40, height: 40)
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 6)
        .padding(.bottom, 10)
    }
}

struct StatusPill: View {
    @EnvironmentObject private var theme: ThemeController
    var title: String
    var status: String

    var body: some View {
        let colors = theme.pillColors(status)
        Text(title)
            .font(ManropeFont.font(size: 12, weight: .bold))
            .foregroundStyle(colors.1)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(colors.0))
    }
}

struct HairlineProgress: View {
    var fraction: Double
    var tint: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.black.opacity(0.28))
                Capsule()
                    .fill(tint)
                    .frame(width: max(8, geo.size.width * min(1, max(0, fraction))))
            }
        }
        .frame(height: 8)
    }
}

struct TrendSpark: View {
    var trend: Double
    var color: Color

    var body: some View {
        Canvas { context, size in
            var path = Path()
            let width = size.width
            let height = size.height
            if abs(trend) < 0.5 {
                path.move(to: CGPoint(x: 0, y: height * 0.5))
                path.addLine(to: CGPoint(x: width, y: height * 0.5))
            } else if trend > 0 {
                path.move(to: CGPoint(x: 0, y: height * 0.78))
                path.addQuadCurve(
                    to: CGPoint(x: width, y: height * 0.22),
                    control: CGPoint(x: width * 0.45, y: height * 0.72)
                )
            } else {
                path.move(to: CGPoint(x: 0, y: height * 0.28))
                path.addQuadCurve(
                    to: CGPoint(x: width, y: height * 0.8),
                    control: CGPoint(x: width * 0.55, y: height * 0.32)
                )
            }
            context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 2, lineCap: .round))
        }
        .frame(width: 36, height: 16)
    }
}

struct ScreenColumn<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                content()
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
    }
}
