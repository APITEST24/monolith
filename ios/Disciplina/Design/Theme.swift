import CoreText
import SwiftUI
import UIKit

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        let red = Double((hex >> 16) & 0xFF) / 255
        let green = Double((hex >> 8) & 0xFF) / 255
        let blue = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }

    func mixed(with other: Color, amount: Double) -> Color {
        let left = UIColor(self)
        let right = UIColor(other)
        var lr: CGFloat = 0, lg: CGFloat = 0, lb: CGFloat = 0, la: CGFloat = 0
        var rr: CGFloat = 0, rg: CGFloat = 0, rb: CGFloat = 0, ra: CGFloat = 0
        left.getRed(&lr, green: &lg, blue: &lb, alpha: &la)
        right.getRed(&rr, green: &rg, blue: &rb, alpha: &ra)
        let t = CGFloat(amount)
        return Color(
            .sRGB,
            red: Double(lr + (rr - lr) * t),
            green: Double(lg + (rg - lg) * t),
            blue: Double(lb + (rb - lb) * t),
            opacity: Double(la + (ra - la) * t)
        )
    }
}

enum AppColor {
    static let ink = Color(hex: 0xF3EEE9)
    static let background = Color(hex: 0x0A0A0C)
    static let monoBackground = Color(hex: 0x050505)
    static let positive = Color(hex: 0x7EE0D4)
    static let negative = Color(hex: 0xE8898A)
    static let amberInk = Color(hex: 0x1A1408)
}

enum SectionKind: String, CaseIterable, Identifiable {
    case finance, bundles, geo, tasks, journal, rules
    var id: String { rawValue }
}

struct JellySkin {
    var stops: [Color]
    var locations: [CGFloat]
    var calm: Bool
    var slab: Color
    var slabDeep: Color
    var step1: CGFloat
    var step2: CGFloat
    var dropY: CGFloat
    var dropBlur: CGFloat
    var dropAlpha: Double
    var bloom: Color
    var bloomAlpha: Double
    var wash: Color? = nil
}

final class ThemeController: ObservableObject {
    @Published var monochrome: Bool {
        didSet { UserDefaults.standard.set(monochrome, forKey: "disciplina.mono") }
    }

    init() {
        monochrome = UserDefaults.standard.bool(forKey: "disciplina.mono")
    }

    var background: Color { monochrome ? AppColor.monoBackground : AppColor.background }
    var ink: Color { monochrome ? Color(hex: 0xF2F2F0) : AppColor.ink }
    var positive: Color { monochrome ? Color(hex: 0xF2F2F0) : AppColor.positive }
    var negative: Color { monochrome ? Color(hex: 0xC8C8C4) : AppColor.negative }
    var muted: Color { ink.opacity(monochrome ? 0.52 : 0.56) }
    var onHero: Color { ink.opacity(monochrome ? 0.55 : 0.60) }
    var line: Color { ink.opacity(0.10) }
    var chart: Color { monochrome ? Color(hex: 0xD8D8D4) : Color(hex: 0x7AD4C8) }

    func hero(_ section: SectionKind) -> JellySkin {
        if monochrome {
            return skin(
                [Color(hex: 0x2A2A2A), Color(hex: 0x1A1A1A), Color(hex: 0x101010)],
                [0, 0.5, 1],
                calm: false,
                slab: Color(hex: 0x101010),
                deep: .black,
                step1: section == .finance ? 6 : 5,
                step2: section == .finance ? 9 : 8,
                dropY: section == .finance ? 20 : 16,
                dropBlur: section == .finance ? 34 : 26,
                dropAlpha: section == .finance ? 0.46 : 0.42,
                bloom: .white,
                bloomAlpha: 0.08
            )
        }
        switch section {
        case .finance:
            return skin(
                [Color(hex: 0x2CB8A8), Color(hex: 0x0E6A61), Color(hex: 0x08443E)],
                [0, 0.42, 1],
                calm: false,
                slab: Color(hex: 0x06332E),
                deep: Color(hex: 0x041F1C),
                step1: 6, step2: 9, dropY: 20, dropBlur: 34, dropAlpha: 0.46,
                bloom: Color(hex: 0x2CB8A8), bloomAlpha: 0.32
            )
        case .bundles:
            return skin(
                [Color(hex: 0xF0D078), Color(hex: 0xD4A038), Color(hex: 0x9A7018)],
                [0, 0.44, 1],
                calm: false,
                slab: Color(hex: 0x6A4A10),
                deep: Color(hex: 0x3E2C08),
                step1: 5, step2: 8, dropY: 16, dropBlur: 26, dropAlpha: 0.40,
                bloom: Color(hex: 0xD4A038), bloomAlpha: 0.30
            )
        case .geo:
            return skin(
                [Color(hex: 0x4A6CA4), Color(hex: 0x1E3A68), Color(hex: 0x101C38)],
                [0, 0.50, 1],
                calm: false,
                slab: Color(hex: 0x0C1830),
                deep: Color(hex: 0x070E1C),
                step1: 5, step2: 8, dropY: 16, dropBlur: 26, dropAlpha: 0.42,
                bloom: Color(hex: 0x1E3A68), bloomAlpha: 0.36
            )
        case .tasks:
            return skin(
                [Color(hex: 0x8A5AAA), Color(hex: 0x5C3870), Color(hex: 0x321C42)],
                [0, 0.50, 1],
                calm: false,
                slab: Color(hex: 0x241430),
                deep: Color(hex: 0x140A1C),
                step1: 5, step2: 8, dropY: 16, dropBlur: 26, dropAlpha: 0.42,
                bloom: Color(hex: 0x5C3870), bloomAlpha: 0.36
            )
        case .journal:
            return skin(
                [Color(hex: 0xE06A62), Color(hex: 0xB03C38), Color(hex: 0x6A1E1C)],
                [0, 0.50, 1],
                calm: false,
                slab: Color(hex: 0x4A1414),
                deep: Color(hex: 0x2A0C0C),
                step1: 5, step2: 8, dropY: 16, dropBlur: 26, dropAlpha: 0.42,
                bloom: Color(hex: 0xB03C38), bloomAlpha: 0.34
            )
        case .rules:
            return skin(
                [Color(hex: 0x589A68), Color(hex: 0x326840), Color(hex: 0x173022)],
                [0, 0.50, 1],
                calm: false,
                slab: Color(hex: 0x102018),
                deep: Color(hex: 0x08110C),
                step1: 5, step2: 8, dropY: 16, dropBlur: 26, dropAlpha: 0.42,
                bloom: Color(hex: 0x326840), bloomAlpha: 0.34
            )
        }
    }

    func sheet(_ kind: SheetTone) -> JellySkin {
        let base = skin(
            kind.stops(mono: monochrome),
            [0, 1],
            calm: true,
            slab: Color(hex: 0x0A0B10),
            deep: Color(hex: 0x050508),
            step1: 5, step2: 8, dropY: 16, dropBlur: 26, dropAlpha: 0.44,
            bloom: .black, bloomAlpha: 0.28
        )
        return base
    }

    func bundleSkin(_ status: String) -> JellySkin {
        var paint = sheet(.bundle)
        if !monochrome {
            switch status {
            case "profit": paint.wash = Color(hex: 0x2CB8A8).opacity(0.18)
            case "test": paint.wash = Color(hex: 0xC8A03C).opacity(0.18)
            case "stop": paint.wash = Color(hex: 0xE06A62).opacity(0.20)
            default: break
            }
        }
        return paint
    }

    func peekInk(_ section: SectionKind) -> Color {
        if monochrome { return ink }
        return section == .bundles ? AppColor.amberInk : ink
    }

    func peekMuted(_ section: SectionKind) -> Color {
        if monochrome { return ink.opacity(0.55) }
        if section == .bundles { return AppColor.amberInk.opacity(0.68) }
        return ink.opacity(0.70)
    }

    func monoPeek(_ index: Int) -> JellySkin {
        let pairs: [(UInt32, UInt32)] = [
            (0x222126, 0x161518),
            (0x1A1A1A, 0x121212),
            (0x181818, 0x101010),
            (0x151515, 0x0E0E0E),
            (0x131313, 0x0C0C0C),
        ]
        let pair = pairs[min(index, pairs.count - 1)]
        return sheetStops(Color(hex: pair.0), Color(hex: pair.1))
    }

    func bar(_ section: SectionKind) -> Color {
        if monochrome { return Color(hex: 0xE8E8E4) }
        return section == .finance ? Color(hex: 0x2EC4B6) : Color(hex: 0xE0B65A)
    }

    func tone(_ name: String) -> Color {
        switch name {
        case "positive": return positive
        case "negative": return negative
        case "accent":
            return monochrome ? ink.opacity(0.8) : Color(hex: 0x9F78B7)
        default: return ink
        }
    }

    private func sheetStops(_ top: Color, _ bottom: Color) -> JellySkin {
        skin(
            [top, bottom],
            [0, 1],
            calm: true,
            slab: Color(hex: 0x0A0B10),
            deep: Color(hex: 0x050508),
            step1: 5, step2: 8, dropY: 16, dropBlur: 26, dropAlpha: 0.44,
            bloom: .black, bloomAlpha: 0.28
        )
    }

    private func skin(
        _ stops: [Color],
        _ locations: [CGFloat],
        calm: Bool,
        slab: Color,
        deep: Color,
        step1: CGFloat,
        step2: CGFloat,
        dropY: CGFloat,
        dropBlur: CGFloat,
        dropAlpha: Double,
        bloom: Color,
        bloomAlpha: Double
    ) -> JellySkin {
        JellySkin(
            stops: stops,
            locations: locations,
            calm: calm,
            slab: slab,
            slabDeep: deep,
            step1: step1,
            step2: step2,
            dropY: dropY,
            dropBlur: dropBlur,
            dropAlpha: dropAlpha,
            bloom: bloom,
            bloomAlpha: bloomAlpha
        )
    }
}

enum SheetTone {
    case financeBook, geo, geoStop, tasks, journal, rules, bundle

    func stops(mono: Bool) -> [Color] {
        if mono {
            return [Color(hex: 0x1C1C1C), Color(hex: 0x121212)]
        }
        switch self {
        case .financeBook: return [Color(hex: 0x243656), Color(hex: 0x141C2C)]
        case .geo: return [Color(hex: 0x1C2434), Color(hex: 0x121820)]
        case .geoStop: return [Color(hex: 0x2A2024), Color(hex: 0x161214)]
        case .tasks: return [Color(hex: 0x262030), Color(hex: 0x16121C)]
        case .journal: return [Color(hex: 0x2A2024), Color(hex: 0x161214)]
        case .rules: return [Color(hex: 0x1C2420), Color(hex: 0x121614)]
        case .bundle: return [Color(hex: 0x222126), Color(hex: 0x161518)]
        }
    }
}

enum ManropeFont {
    static let faces = [
        "Manrope",
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
        case let value where value.rawValue >= 0.50:
            name = "Manrope-ExtraBold"
        case let value where value.rawValue >= 0.37:
            name = "Manrope-Bold"
        case let value where value.rawValue >= 0.28:
            name = "Manrope-SemiBold"
        case let value where value.rawValue >= 0.20:
            name = "Manrope-Medium"
        default:
            name = "Manrope-Regular"
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

    static let demi = UIFont.Weight(rawValue: 0.34)
    static let blackish = UIFont.Weight(rawValue: 0.56)
}

extension Text {
    func face(_ size: CGFloat, _ weight: UIFont.Weight = .medium, em: CGFloat = 0) -> Text {
        font(ManropeFont.font(size: size, weight: weight)).tracking(em * size)
    }
}

struct AppBackground: View {
    @EnvironmentObject private var theme: ThemeController

    var body: some View {
        ZStack {
            theme.background
            RadialGradient(
                colors: [Color.white.opacity(0.045), .clear],
                center: UnitPoint(x: 0.5, y: 0),
                startRadius: 0,
                endRadius: 320
            )
            .offset(y: -220)
            .allowsHitTesting(false)
        }
        .ignoresSafeArea()
    }
}

struct JellyFill: View {
    var skin: JellySkin

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            ZStack {
                LinearGradient(
                    stops: zip(skin.stops, skin.locations).map { Gradient.Stop(color: $0.0, location: $0.1) },
                    startPoint: UnitPoint(x: 0.18, y: 0),
                    endPoint: UnitPoint(x: 0.78, y: 1)
                )
                if let wash = skin.wash {
                    LinearGradient(
                        colors: [wash, .clear],
                        startPoint: UnitPoint(x: 0, y: 0),
                        endPoint: UnitPoint(x: 0.7, y: 0.7)
                    )
                }
                gloss(width: width, height: height)
            }
        }
    }

    private func gloss(width: CGFloat, height: CGFloat) -> some View {
        let vivid = !skin.calm
        return ZStack {
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(vivid ? 0.86 : 0.48),
                            Color.white.opacity(vivid ? 0.28 : 0.14),
                            .clear,
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: max(width, height) * 0.28
                    )
                )
                .frame(width: width * (vivid ? 0.72 : 0.70), height: height * (vivid ? 0.22 : 0.18))
                .position(x: width * (vivid ? 0.26 : 0.24), y: height * (vivid ? 0.07 : 0.04))
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [Color.white.opacity(vivid ? 0.24 : 0.14), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: width * 0.18
                    )
                )
                .frame(width: width * (vivid ? 0.36 : 0.30), height: height * (vivid ? 0.12 : 0.10))
                .position(x: width * (vivid ? 0.72 : 0.78), y: height * (vivid ? 0.20 : 0.16))
            if vivid {
                Ellipse()
                    .fill(
                        RadialGradient(
                            colors: [Color.white.opacity(0.10), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: width * 0.4
                        )
                    )
                    .frame(width: width * 0.80, height: height * 0.50)
                    .position(x: width * 0.50, y: height * 1.10)
                Ellipse()
                    .fill(
                        RadialGradient(
                            colors: [Color.white.opacity(0.16), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: width * 0.42
                        )
                    )
                    .frame(width: width * 0.80, height: height * 0.70)
                    .position(x: width * 0.50, y: height * 0.38)
                    .blendMode(.softLight)
            }
            LinearGradient(
                stops: vivid
                    ? [
                        .init(color: .white.opacity(0.14), location: 0),
                        .init(color: .clear, location: 0.32),
                        .init(color: .black.opacity(0.06), location: 0.70),
                        .init(color: .black.opacity(0.24), location: 1),
                    ]
                    : [
                        .init(color: .white.opacity(0.10), location: 0),
                        .init(color: .clear, location: 0.28),
                        .init(color: .black.opacity(0.05), location: 0.72),
                        .init(color: .black.opacity(0.20), location: 1),
                    ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .allowsHitTesting(false)
    }
}

struct JellyChrome<S: Shape, Content: View>: View {
    var skin: JellySkin
    var shape: S
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack {
            shape.fill(skin.slabDeep).offset(y: skin.step2)
            shape.fill(skin.slab).offset(y: skin.step1)
            content()
                .background(JellyFill(skin: skin))
                .clipShape(shape)
                .overlay(innerRim)
        }
        .compositingGroup()
        .shadow(color: .black.opacity(skin.dropAlpha), radius: skin.dropBlur / 2, y: skin.dropY)
        .shadow(color: skin.bloom.opacity(skin.bloomAlpha), radius: 14, y: 10)
    }

    private var innerRim: some View {
        shape
            .stroke(Color.white.opacity(skin.calm ? 0.14 : 0.20), lineWidth: skin.calm ? 1 : 1.2)
            .overlay(alignment: .top) {
                shape
                    .stroke(Color.white.opacity(skin.calm ? 0.42 : 0.62), lineWidth: 1.5)
                    .mask(
                        LinearGradient(colors: [.white, .clear], startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.18))
                    )
            }
            .allowsHitTesting(false)
    }
}

struct CircleIconButton: View {
    var system: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppColor.ink)
                .frame(width: 34, height: 34)
                .background(
                    Circle().fill(
                        LinearGradient(
                            colors: [Color(hex: 0x3A3A40), Color(hex: 0x1A1A1E), Color(hex: 0x0E0E10)],
                            startPoint: UnitPoint(x: 0.2, y: 0),
                            endPoint: UnitPoint(x: 0.8, y: 1)
                        )
                    )
                )
                .overlay(Circle().stroke(Color.white.opacity(0.20), lineWidth: 1).mask(Circle().padding(.bottom, 17)))
                .shadow(color: .black.opacity(0.5), radius: 2.5, y: 2)
        }
        .buttonStyle(.plain)
    }
}

struct DotButton: View {
    var action: () -> Void
    @EnvironmentObject private var theme: ThemeController

    var body: some View {
        Button(action: action) {
            HStack(spacing: 3) {
                ForEach(0..<3, id: \.self) { _ in
                    Circle().fill(theme.ink.opacity(0.85)).frame(width: 3.5, height: 3.5)
                }
            }
            .frame(width: 34, height: 34)
            .background(
                Circle().fill(
                    LinearGradient(
                        colors: [Color(hex: 0x3A3A40), Color(hex: 0x1A1A1E), Color(hex: 0x0C0C0E)],
                        startPoint: UnitPoint(x: 0.15, y: 0),
                        endPoint: UnitPoint(x: 0.85, y: 1)
                    )
                )
            )
            .shadow(color: .black.opacity(0.5), radius: 2.5, y: 2)
        }
        .buttonStyle(.plain)
    }
}

struct ScreenHeader: View {
    @EnvironmentObject private var theme: ThemeController
    var title: String
    var trailing: String?
    var onBack: () -> Void
    var onTrailing: () -> Void = {}

    var body: some View {
        ZStack {
            Text(title)
                .face(17, .bold, em: -0.03)
                .foregroundStyle(theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .padding(.horizontal, 48)
            HStack {
                CircleIconButton(system: "chevron.left", action: onBack)
                Spacer()
                if let trailing {
                    CircleIconButton(system: trailing, action: onTrailing)
                } else {
                    Color.clear.frame(width: 34, height: 34)
                }
            }
        }
        .padding(.horizontal, 20)
        .frame(height: 52)
    }
}

struct StatusPill: View {
    var title: String
    var status: String

    var body: some View {
        Text(title)
            .face(11, .bold, em: -0.01)
            .foregroundStyle(foreground)
            .padding(.horizontal, 9)
            .padding(.top, 5)
            .padding(.bottom, 4)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom))
            )
            .overlay(alignment: .top) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.white.opacity(status == "stop" ? 0.15 : 0.30), lineWidth: 1)
                    .mask(LinearGradient(colors: [.white, .clear], startPoint: .top, endPoint: .center))
            }
    }

    private var colors: [Color] {
        switch status {
        case "profit", "live": return [Color(hex: 0x8AD4C8), Color(hex: 0x3DB8A8)]
        case "test": return [Color(hex: 0xE8C56A), Color(hex: 0xC99A32)]
        case "stop": return [Color(hex: 0xE06A62), Color(hex: 0x8A2E2C)]
        default: return [Color(hex: 0x3A3A42), Color(hex: 0x1C1C22)]
        }
    }

    private var foreground: Color {
        switch status {
        case "profit", "live": return Color(hex: 0x062824)
        case "test": return Color(hex: 0x1A1408)
        default: return AppColor.ink
        }
    }
}

struct HairlineProgress: View {
    var fraction: Double
    var tint: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color.black.opacity(0.42))
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                tint.mixed(with: .white, amount: 0.15),
                                tint,
                                tint.mixed(with: .black, amount: 0.25),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
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
            let samples: [CGFloat]
            if abs(trend) < 0.5 {
                samples = [8, 8.2, 7.8, 8.1, 7.9, 8]
            } else if trend > 0 {
                samples = [9.8, 9.2, 9.4, 7.4, 5.6, 3.4]
            } else {
                samples = [5.4, 6.2, 7.0, 8.0, 9.2, 10.6]
            }
            let step = size.width / CGFloat(samples.count - 1)
            for (index, y) in samples.enumerated() {
                let point = CGPoint(x: CGFloat(index) * step, y: y / 16 * size.height)
                if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
            }
            context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
        }
        .frame(width: 36, height: 16)
    }
}

struct ScreenColumn<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                content()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 36)
        }
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
    }
}

struct Well<Content: View>: View {
    var radius: CGFloat = 20
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.black.opacity(0.32), Color.white.opacity(0.02)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
                    .mask(LinearGradient(colors: [.clear, .white], startPoint: .top, endPoint: .bottom))
            )
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}

struct JellyToggle: View {
    @EnvironmentObject private var theme: ThemeController
    var isOn: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: isOn ? .trailing : .leading) {
                Capsule()
                    .fill(track)
                    .frame(width: 48, height: 28)
                    .overlay(
                        Capsule().stroke(Color.white.opacity(isOn ? 0.35 : 0.06), lineWidth: 1)
                            .mask(LinearGradient(colors: [.white, .clear], startPoint: .top, endPoint: .center))
                    )
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.white, Color(hex: 0xECECE8), Color(hex: 0xD4D4D0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 22, height: 22)
                    .shadow(color: .black.opacity(0.40), radius: 2.5, y: 2)
                    .padding(3)
            }
            .frame(width: 48, height: 28)
        }
        .buttonStyle(.plain)
    }

    private var track: LinearGradient {
        if isOn {
            let paint = theme.hero(.rules)
            return LinearGradient(colors: paint.stops, startPoint: .top, endPoint: .bottom)
        }
        return LinearGradient(
            colors: [Color(hex: 0x2A2A30), Color(hex: 0x16161A)],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
