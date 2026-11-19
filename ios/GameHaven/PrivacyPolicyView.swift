import SwiftUI
import WebKit

/// The same privacy.html that is published on the web, read from the app bundle so it works offline.
struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Page()
            Button("Close") { dismiss() }.jewel(.ruby)
        }
        .screen()
    }

    private struct Page: UIViewRepresentable {
        func makeUIView(context: Context) -> WKWebView {
            let view = WKWebView()
            if let url = Bundle.main.url(forResource: "privacy", withExtension: "html") {
                view.loadFileURL(url, allowingReadAccessTo: url)
            }
            return view
        }
        func updateUIView(_ view: WKWebView, context: Context) {}
    }
}
