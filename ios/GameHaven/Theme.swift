import SwiftUI

/// Onsen village look (see home-village.md): washi paper, walnut wood, sumi ink, yuzu gold.
/// Text sizes come from Dynamic Type, so every screen grows with the player's text size for free.
enum Theme {
    static let paper = Color(hex: 0xF6EBD6)  // ink text on this is 13:1
    static let paperEdge = Color(hex: 0xE6D2AE)
    static let walnut = Color(hex: 0x7A4E32)
    static let gold = Color(hex: 0xE2A93B)
    static let ivory = Color(hex: 0xFFF6E6)
    static let ink = Color(hex: 0x33261C)
}

/// Button colours: fill and text. Every pair is at least 7:1 contrast.
enum Jewel {
    case ruby, sapphire, amethyst, onyx, gold, ivory, jade, amber

    var fill: Color {
        switch self {
        case .ruby: Color(hex: 0x8E2A24)  // deep vermilion
        case .sapphire: Color(hex: 0x23395B)  // indigo
        case .amethyst: Color(hex: 0x4B3B6E)  // wisteria
        case .onyx: Theme.ink
        case .gold: Theme.gold
        case .ivory: Theme.ivory
        case .jade: Color(hex: 0x2E6B4E)  // pine; ivory text on it is 5.9:1
        case .amber: Color(hex: 0xE8892E)  // persimmon; ink text on it is 5.6:1
        }
    }

    var text: Color { self == .gold || self == .ivory || self == .amber ? Theme.ink : Theme.ivory }
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double(hex >> 16 & 0xFF) / 255, green: Double(hex >> 8 & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }
}

/// Big, labelled, bordered button. At least 60 pt tall (Apple's minimum is 44).
struct JewelButtonStyle: ButtonStyle {
    var jewel: Jewel = .onyx
    @Environment(\.highContrast) private var highContrast
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.title3.bold())
            .multilineTextAlignment(.center)
            .foregroundStyle(jewel.text)
            .padding(.horizontal, 8)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 60)
            .background(jewel.fill, in: .rect(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(highContrast ? .black : Theme.walnut, lineWidth: 3))
            .shadow(color: Theme.walnut.opacity(0.35), radius: 3, y: 2)
            .opacity(isEnabled ? (configuration.isPressed ? 0.75 : 1) : 0.45)
    }
}

extension View {
    func jewel(_ jewel: Jewel) -> some View { buttonStyle(JewelButtonStyle(jewel: jewel)) }
}

/// Screen heading: big serif capitals over a short vermilion brush line.
struct Heading: View {
    let text: String
    @Environment(\.highContrast) private var highContrast

    var body: some View {
        VStack(spacing: 0) {
            Text(text.uppercased()).font(.system(.largeTitle, design: .serif, weight: .bold))
            Capsule().fill(Jewel.ruby.fill).frame(width: 64, height: 4).padding(.top, 6).accessibilityHidden(true)
        }
        .foregroundStyle(highContrast ? .black : Theme.ink)
        .multilineTextAlignment(.center)
        .accessibilityAddTraits(.isHeader)
    }
}

/// The player's text size and contrast, applied once at the root.
struct AppStyle: ViewModifier {
    let settings: AppSettings
    @Environment(\.colorSchemeContrast) private var systemContrast
    @Environment(\.dynamicTypeSize) private var systemSize

    func body(content: Content) -> some View {
        let highContrast = settings.highContrast || systemContrast == .increased
        content
            .environment(\.highContrast, highContrast)
            .dynamicTypeSize(settings.textSize ?? systemSize)
            .foregroundStyle(highContrast ? .black : Theme.ink)
            .preferredColorScheme(.light)  // dark text everywhere, so system sheets match
    }
}

/// A full page: padding, washi paper background (flat white in high contrast), and no small nav-bar back button.
struct ScreenStyle: ViewModifier {
    @Environment(\.highContrast) private var highContrast

    func body(content: Content) -> some View {
        content
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                if highContrast {
                    Color.white.ignoresSafeArea()
                } else {
                    RadialGradient(colors: [Theme.paper, Theme.paperEdge], center: UnitPoint(x: 0.5, y: 0.4), startRadius: 0, endRadius: 700)
                        .ignoresSafeArea()
                }
            }
            .toolbar(.hidden, for: .navigationBar)
    }
}

extension View {
    func screen() -> some View { modifier(ScreenStyle()) }
}

extension EnvironmentValues {
    @Entry var highContrast = false
}
