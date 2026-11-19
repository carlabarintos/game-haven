import SwiftUI

struct HomeView: View {
    /// Each game is a place in the village. `spot` is the place's tap area on the 390×844 board, plaque at its bottom.
    /// A game without a screen shows as "coming soon" until it's built.
    /// `jp` and `neon` dress each plaque as a lit Tokyo shop sign.
    private static let games: [(name: String, place: String, jp: String, neon: UInt32, jewel: Jewel, built: Bool, spot: CGRect)] = [
        ("Sudoku", "Hot Spring", "温泉", 0xFFD84A, .gold, true, CGRect(x: 124, y: 360, width: 152, height: 170)),
        ("Solitaire", "Maple Cabin", "紅葉", 0xFF4F7B, .ruby, true, CGRect(x: 8, y: 452, width: 116, height: 160)),
        ("Word Search", "Bookshop", "本屋", 0x3FE0FF, .sapphire, true, CGRect(x: 226, y: 170, width: 152, height: 168)),
        ("Mahjong", "Tea House", "茶屋", 0x7CFF8A, .ivory, true, CGRect(x: 34, y: 196, width: 152, height: 172)),
        ("Dominoes", "Pine Cabin", "松屋", 0xC77DFF, .amethyst, true, CGRect(x: 236, y: 534, width: 148, height: 146)),
        ("Jigsaw", "Koi Pond", "鯉池", 0xFF9F43, .onyx, true, CGRect(x: 30, y: 668, width: 150, height: 138)),
        ("Nonograms", "Bathhouse", "銭湯", 0xFF6FD8, .jade, true, CGRect(x: 236, y: 340, width: 148, height: 120)),
    ]

    @Environment(\.dynamicTypeSize) private var textSize
    @Environment(\.highContrast) private var highContrast
    @Environment(Village.self) private var village

    private var starLine: String {
        village.next.map { "★ \(village.stars) stars · Next: \($0.name.lowercased()) at \($0.stars)" } ?? "★ \(village.stars) stars · Your village is complete"
    }

    var body: some View {
        // The plaques can't grow past about xxxLarge on the map, so the largest text sizes get a list instead.
        if textSize > .xxxLarge { list } else { map }
    }

    private var map: some View {
        GeometryReader { geo in
            // Same fit as the scene, so each plaque lands on its place.
            let s = min(geo.size.width / VillageScene.board.width, geo.size.height / VillageScene.board.height)
            let origin = CGPoint(x: (geo.size.width - VillageScene.board.width * s) / 2, y: (geo.size.height - VillageScene.board.height * s) / 2)
            ZStack(alignment: .topLeading) {
                VillageView(stage: village.stage)
                VStack(spacing: 10) {
                    Label { Text(starLine.dropFirst(2)) } icon: { Image(systemName: "star.fill").foregroundStyle(Jewel.amber.fill) }
                        .font(.headline).padding(.horizontal, 16).padding(.vertical, 8)
                        .background(Theme.ivory, in: .capsule)
                        .overlay(Capsule().strokeBorder(highContrast ? .black : Theme.walnut, lineWidth: 2))
                    VStack(spacing: 0) {
                        Text("Yuzu Springs").font(.system(.title2, design: .serif, weight: .heavy))
                        Text("ゆず温泉").font(.caption.bold()).tracking(4).foregroundStyle(Color(hex: 0xF2D9A8)).accessibilityHidden(true)
                    }
                    .foregroundStyle(Theme.ivory)
                    .padding(.horizontal, 22).padding(.vertical, 6)
                    .background(Color(hex: 0x5E3B26), in: .rect(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(highContrast ? .black : Color(hex: 0x3B2A1E), lineWidth: 3))
                    .accessibilityAddTraits(.isHeader)
                }
                .frame(width: geo.size.width)
                .padding(.top, origin.y + 44 * s)
                ForEach(Self.games, id: \.name) { game in
                    Group {
                        if game.built {
                            NavigationLink { destination(game.name) } label: { plaque(game, soon: false) }
                        } else {
                            plaque(game, soon: true)
                        }
                    }
                    .buttonStyle(.plain)
                    .frame(width: game.spot.width * s, height: game.spot.height * s, alignment: .bottom)
                    .offset(x: origin.x + game.spot.minX * s, y: origin.y + game.spot.minY * s)
                }
                NavigationLink { SettingsView() } label: {
                    Image(systemName: "gearshape.fill").font(.title.weight(.heavy)).foregroundStyle(Theme.ivory)
                        .frame(width: 60, height: 60)
                        .background(Color(hex: 0x5E3B26), in: .circle)
                        .overlay(Circle().strokeBorder(highContrast ? .black : Color(hex: 0x3B2A1E), lineWidth: 3))
                }
                .accessibilityLabel("Settings")
                .offset(x: origin.x + 376 * s - 60, y: origin.y + 744 * s)
            }
        }
        .ignoresSafeArea()
        .toolbar(.hidden, for: .navigationBar)
    }

    @ViewBuilder private func destination(_ name: String) -> some View {
        switch name {
        case "Word Search": WordSearchView()
        case "Solitaire": SolitaireView()
        case "Mahjong": MahjongView()
        case "Jigsaw": JigsawView()
        case "Dominoes": DominoesView()
        case "Nonograms": NonogramView()
        default: SudokuView()
        }
    }

    /// Neon shop sign: Japanese and place name small, game name large and glowing. The whole place above it is part of the button.
    private func plaque(_ game: (name: String, place: String, jp: String, neon: UInt32, jewel: Jewel, built: Bool, spot: CGRect), soon: Bool) -> some View {
        let neon = highContrast ? Color.white : Color(hex: game.neon)
        return VStack(spacing: 0) {
            Spacer(minLength: 0)
            VStack(spacing: 0) {
                HStack(spacing: 5) {
                    Text(game.jp).accessibilityHidden(true)
                    Text(game.place)
                }
                .font(.subheadline.weight(.bold)).foregroundStyle(neon)
                Text(game.name).font(.title3.weight(.heavy)).foregroundStyle(.white)
                    .shadow(color: highContrast ? .clear : neon, radius: 5)
                if soon { Text("coming soon").font(.footnote.weight(.semibold)).foregroundStyle(.white) }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .padding(.horizontal, 6).padding(.vertical, 5)
            .frame(maxWidth: .infinity)
            .background(highContrast ? .black : Color(hex: 0x16112A).opacity(0.92), in: .rect(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(neon, lineWidth: 2.5).shadow(color: neon, radius: 4).shadow(color: neon, radius: 10))
        }
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(soon ? [] : .isButton)
    }

    private var list: some View {
        VStack(spacing: 16) {
            Heading(text: "Game Haven")
            ScrollView {
                VillageView(stage: village.stage, crop: true)
                    .frame(height: 260)
                    .clipShape(.rect(cornerRadius: 14))
                    .padding(8)
                Text(starLine).font(.title3).multilineTextAlignment(.center)
                VStack(spacing: 16) {
                    ForEach(Self.games, id: \.name) { game in
                        if game.built {
                            NavigationLink(game.name) { destination(game.name) }.jewel(game.jewel)
                        } else {
                            Button("\(game.name)\n(coming soon)") {}.jewel(game.jewel).disabled(true)
                        }
                    }
                }
                .padding(8)  // room for the shadows, which the scroll area would clip
            }
            NavigationLink("Settings") { SettingsView() }.jewel(.onyx)
        }
        .screen()
    }
}
