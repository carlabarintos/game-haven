import SwiftUI

@main
struct GameHavenApp: App {
    @State private var settings = AppSettings()
    @State private var village = Village()
    @Environment(\.scenePhase) private var phase

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                #if DEBUG
                // `-screen sudoku` (or solitaire, mahjong, jigsaw, dominoes, nonogram, wordsearch, settings) at launch opens that screen directly, for simulator screenshots.
                switch UserDefaults.standard.string(forKey: "screen") {
                case "sudoku": SudokuView()
                case "solitaire": SolitaireView()
                case "mahjong": MahjongView()
                case "jigsaw": JigsawView()
                case "dominoes": DominoesView()
                case "nonogram": NonogramView()
                case "wordsearch": WordSearchView()
                case "settings": SettingsView()
                default: HomeView()
                }
                #else
                HomeView()
                #endif
            }
                .environment(settings)
                .environment(village)
                .modifier(AppStyle(settings: settings))
                .task {
                    #if DEBUG
                    if UserDefaults.standard.string(forKey: "screen") != nil { return }  // no consent popup over screenshots
                    #endif
                    await Ads.shared.start()
                }
                .task { await Purchases.shared.start() }  // runs for the app's life, following purchases
                .onChange(of: phase, initial: true) { if phase == .active { Music.start() } }  // iOS stops audio while the app is away
        }
    }
}
