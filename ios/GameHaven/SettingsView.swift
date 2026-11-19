import SwiftUI

// Buttons instead of a slider or switches: the system ones are small targets for unsteady hands.
struct SettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var textSize
    @State private var message: String?
    @State private var showPolicy = false
    private let purchases = Purchases.shared

    var body: some View {
        let index = settings.textSizeIndex
        // While following the iPhone, step from its size; sizes beyond the list count as the largest.
        let current = index ?? AppSettings.textSizes.firstIndex(of: textSize) ?? (textSize < .large ? 0 : AppSettings.textSizes.count - 1)
        VStack(spacing: 20) {
            Heading(text: "Settings")
            ScrollView {
                VStack(spacing: 20) {
                    Text(index.map { "Text size: \(Int(AppSettings.bodyPoints[$0] / 17 * 100))%" } ?? "Text size: same as iPhone")
                        .font(.title3)
                    HStack {
                        Button("Smaller") { settings.textSizeIndex = current - 1 }
                            .jewel(.onyx).disabled(current == 0)
                        Button("Bigger") { settings.textSizeIndex = current + 1 }
                            .jewel(.onyx).disabled(current == AppSettings.textSizes.count - 1)
                    }
                    if index != nil {
                        Button("Use iPhone text size") { settings.textSizeIndex = nil }.jewel(.onyx)
                    }
                    Button("High contrast: \(settings.highContrast ? "On" : "Off")") { settings.highContrast.toggle() }
                        .jewel(settings.highContrast ? .gold : .onyx)
                    Button("Sounds: \(settings.sound ? "On" : "Off")") { settings.sound.toggle() }
                        .jewel(settings.sound ? .gold : .onyx)
                    Button("Music: \(settings.music ? "On" : "Off")") { settings.music.toggle() }
                        .jewel(settings.music ? .gold : .onyx)
                    if purchases.adsRemoved {
                        Text("Ads removed. Thank you!").font(.title3)
                    } else {
                        Button(purchases.product.map { "Remove Ads: \($0.displayPrice)" } ?? "Remove Ads") {
                            Task { message = await purchases.buy() }
                        }
                        .jewel(.gold).disabled(purchases.busy)
                        Button("Restore Purchases") { Task { message = await purchases.restore() } }
                            .jewel(.onyx).disabled(purchases.busy)
                    }
                    Button("Privacy Policy") { showPolicy = true }.jewel(.onyx)
                    if Ads.shared.privacyOptionsRequired {
                        Button("Privacy settings") { Task { await Ads.shared.showPrivacyOptions() } }.jewel(.onyx)
                    }
                }
                .padding(8)
            }
            Button("Back") { dismiss() }.jewel(.ruby)
        }
        .screen()
        .alert(message ?? "", isPresented: Binding { message != nil } set: { if !$0 { message = nil } }) {}
        .sheet(isPresented: $showPolicy) { PrivacyPolicyView() }
    }
}
