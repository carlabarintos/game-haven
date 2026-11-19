import SwiftUI

/// Mahjong solitaire at the Tea House: tap two matching free tiles to clear them. Every deal can be cleared.
/// No timer; unlimited undo, hints and shuffles; saves after every pair.
struct MahjongView: View {
    static let id = "mahjong"

    private enum Phase { case menu, board, won }

    @State private var game = Save.load(Self.id, as: MahjongGame.self)
    @State private var phase: Phase = Save.load(Self.id, as: MahjongGame.self) == nil ? .menu : .board
    /// What to do next, or why the last tap didn't clear anything.
    @State private var prompt = Self.firstPrompt
    @State private var rules = false
    /// The first tile tapped, waiting for its match.
    @State private var selected: Int?
    /// The pair Hint points at.
    @State private var hinted: Set<Int> = []
    @State private var misses = 0
    /// Per tile, how many taps went nowhere; each one shakes it.
    @State private var shakes: [Int: Int] = [:]
    /// Tiles just cleared, still dropping off the screen.
    @State private var falling: [Int] = []
    @State private var earned = 0
    @State private var unlocked: Village.Stage?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.highContrast) private var highContrast
    @Environment(\.dismiss) private var dismiss
    @Environment(Village.self) private var village

    private static let firstPrompt = "Tap a bright tile, then a matching one."

    var body: some View {
        Group {
            switch phase {
            case .menu: menu
            case .board: if let game { board(game) }
            case .won: won
            }
        }
        .screen()
        .sensoryFeedback(.success, trigger: game?.gone.count) { old, new in (new ?? 0) > (old ?? 0) }
        .sensoryFeedback(.selection, trigger: selected)
        .sensoryFeedback(.warning, trigger: misses)
    }

    private var menu: some View {
        ScrollView {
            VStack(spacing: 20) {
                Heading(text: "Mahjong")
                Text("At the Tea House").font(.title3.weight(.semibold))
                Button { rules = true } label: { Label("How to play", systemImage: "questionmark.circle") }.jewel(.amethyst)
                ForEach(Array(zip(MahjongLogic.Level.allCases, [Jewel.jade, .amber, .ruby])), id: \.0) { level, jewel in
                    let stars = MahjongLogic.Level.allCases.firstIndex(of: level)! + 1  // what a clear pays, as in MahjongGame.stars
                    Button { start(level) } label: {
                        VStack(spacing: 2) {
                            Text("\(level.rawValue) · \(level.tiles) tiles")
                            Text(String(repeating: "★", count: stars)).font(.body).accessibilityLabel("\(stars) \(stars == 1 ? "star" : "stars")")
                        }
                    }
                    .jewel(jewel)
                }
                Button("Back") { game == nil ? dismiss() : (phase = .board) }.jewel(.onyx)
            }
            .padding(8)  // room for the shadows
        }
        .sheet(isPresented: $rules) { howToPlay }
    }

    private var howToPlay: some View {
        VStack(spacing: 20) {
            Heading(text: "How to play")
            ScrollView {
                Text("Clear every tile from the table, two at a time.\n\nTap a tile, then tap another tile with the same picture to clear them both.\n\nOnly free tiles can be picked. A tile is free when nothing sits on top of it and it has an open side, left or right. Free tiles are bright; tiles you can't pick yet are shaded.\n\nThere is no timer, and you can undo as often as you like. Stuck? Tap Hint to see a pair. If no pairs are left, tap Shuffle to mix the tiles; every game can be cleared.")
                    .font(.title3)
            }
            Button("Got it") { rules = false }.jewel(.gold)
        }
        .foregroundStyle(highContrast ? .black : Theme.ink)
        .screen()
    }

    private func board(_ g: MahjongGame) -> some View {
        VStack(spacing: 8) {
            HStack {
                Button("Menu") { dismiss() }.jewel(.onyx)
                Button("New game") { phase = .menu }.jewel(.sapphire)
            }
            Spacer(minLength: 0)
            TileTable(game: g, selected: selected, hinted: hinted, shakes: shakes, falling: falling, tap: tap)
                .zIndex(1)  // falling tiles pass over the buttons
            Text(prompt).font(.title3).multilineTextAlignment(.center)
                .lineLimit(3, reservesSpace: true)  // a fixed height, so the tiles don't jump when the note changes
                .minimumScaleFactor(0.8)
                .accessibilityAddTraits(.updatesFrequently)
            Spacer(minLength: 0)
            HStack {
                Button("Undo", action: undo).jewel(.amethyst).disabled(g.history.isEmpty)
                if g.hint == nil {
                    Button("Shuffle", action: shuffle).jewel(.jade)
                } else {
                    Button("Hint", action: hint).jewel(.gold)
                }
            }
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)  // leave the tiles their room
        }
    }

    private var won: some View {
        VStack(spacing: 20) {
            Heading(text: "Well done!")
            ScrollView {
                VStack(spacing: 16) {
                    StarCelebration(stars: earned)
                    Text("The table is clear, and you earned \(earned) ★ for your village.").font(.title3)
                    VillageView(stage: village.stage, crop: true).frame(height: 300).clipShape(.rect(cornerRadius: 14))
                    if let unlocked { Text("Your village grew: \(unlocked.name.lowercased())!").font(.title3.bold()) }
                }
                .padding(8)
            }
            Button("New game") { Ads.shared.showBetweenGames(); phase = .menu }.jewel(.gold)
            Button("Menu") { Ads.shared.showBetweenGames(); dismiss() }.jewel(.onyx)
        }
    }

    private func start(_ level: MahjongLogic.Level) {
        game = MahjongLogic.generate(level, seed: .random(in: 0...UInt64.max))
        prompt = Self.firstPrompt
        selected = nil
        hinted = []
        shakes = [:]
        falling = []
        afterMove()
        phase = .board
    }

    /// Applies a change with the tiles fading away or back.
    private func play(_ change: (inout MahjongGame) -> Bool) -> Bool {
        guard var g = game, change(&g) else { return false }
        selected = nil
        hinted = []
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.3)) { game = g }
        Sound.tap.play()
        afterMove()
        return true
    }

    /// First tap picks a tile; a second tap on its match clears both. A tap on a different face picks that one instead.
    private func tap(_ i: Int) {
        guard let g = game else { return }
        let name = MahjongLogic.name(g.tiles[i].face)
        guard g.free(i) else {
            miss(i)
            prompt = g.covered(i)
                ? "The \(name) has a tile on top. Clear that one first."
                : "The \(name) is boxed in on both sides. Clear a tile to its left or right first."
            return
        }
        if selected == i {
            selected = nil
            prompt = Self.firstPrompt
        } else if let s = selected, g.tiles[s].face == g.tiles[i].face {
            prompt = "Cleared the \(name) pair."  // before play, so a "no pairs left" note from afterMove wins
            if !reduceMotion {
                falling += [s, i]
                Task { try? await Task.sleep(for: .seconds(1)); falling.removeAll { $0 == s || $0 == i } }
            }
            _ = play { $0.match(s, i) }
        } else {
            if let s = selected { misses += 1; Sound.miss.play(); prompt = "The \(MahjongLogic.name(g.tiles[s].face)) and the \(name) don't match. Picked the \(name) instead." }
            else { prompt = "You picked the \(name). Now tap its match." }
            selected = i
        }
    }

    private func miss(_ i: Int) {
        misses += 1
        Sound.miss.play()
        withAnimation(reduceMotion ? nil : .linear(duration: 0.4)) { shakes[i, default: 0] += 1 }
    }

    private func undo() {
        if play({ $0.undo() }) { prompt = "Put the last pair back." }
    }

    private func hint() {
        guard let g = game, let (a, b) = g.hint else { return }
        selected = nil
        hinted = [a, b]
        prompt = "Try the two \(MahjongLogic.name(g.tiles[a].face)) tiles outlined in gold."
    }

    private func shuffle() {
        prompt = play({ $0.shuffle(seed: .random(in: 0...UInt64.max)) })
            ? "Mixed the tiles. There are pairs to find again."
            : "These tiles can't be mixed into pairs. Tap Undo to go back, or start a new game."
    }

    private func afterMove() {
        guard let g = game else { return }
        if g.won {
            Save.clear(Self.id)
            Sound.win.play()
            earned = g.stars
            unlocked = village.earn(earned)
            Ads.shared.gameFinished()
            Task {  // let the last pair fade before the win screen
                try? await Task.sleep(for: .seconds(reduceMotion ? 0.3 : 1))
                game = nil
                phase = .won
            }
        } else {
            Save.store(Self.id, g)
            if g.hint == nil { prompt = "No pairs left to clear. Tap Shuffle to mix the tiles, or Undo." }
        }
    }
}

/// The tiles on the table. Upper layers sit up and to the left so the stack reads as 3D;
/// tiles that can't be picked yet are shaded.
private struct TileTable: View {
    let game: MahjongGame
    let selected: Int?
    let hinted: Set<Int>
    let shakes: [Int: Int]
    let falling: [Int]
    let tap: (Int) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            let base = game.level.layers[0]
            let depth = CGFloat(game.level.layers.count - 1)  // the bottom layer doesn't lift
            let unit = min(geo.size.width / size.width, geo.size.height / size.height)
            let lift = unit * 0.25
            let order = game.left.sorted { (game.tiles[$0].z, game.tiles[$0].y, game.tiles[$0].x) < (game.tiles[$1].z, game.tiles[$1].y, game.tiles[$1].x) }
            ZStack(alignment: .topLeading) {
                ForEach(order, id: \.self) { i in
                    let t = game.tiles[i]
                    tile(i, width: unit * 2, height: unit * 2.6, side: lift)
                        .offset(x: CGFloat(t.x) * unit + (depth - CGFloat(t.z)) * lift, y: CGFloat(t.y) * unit * 1.3 + (depth - CGFloat(t.z)) * lift)
                        // A cleared tile hands over to its falling copy below; with Reduce Motion it just fades.
                        .transition(reduceMotion ? .opacity.combined(with: .scale(scale: 0.6)) : .asymmetric(insertion: .opacity, removal: .identity))
                }
                ForEach(falling, id: \.self) { i in
                    let t = game.tiles[i]
                    look(i, width: unit * 2, height: unit * 2.6, side: lift, shaded: false, marked: true)
                        .modifier(Fall(direction: t.x < base.cols ? -1 : 1))
                        .offset(x: CGFloat(t.x) * unit + (depth - CGFloat(t.z)) * lift, y: CGFloat(t.y) * unit * 1.3 + (depth - CGFloat(t.z)) * lift)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
            .frame(width: size.width * unit, height: size.height * unit, alignment: .topLeading)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(size, contentMode: .fit)  // only as tall as the tiles, so the note sits right under them
    }

    /// The board in half-tile steps: a tile is 1.3 times taller than wide, and each layer above the bottom lifts by a quarter step.
    private var size: CGSize {
        let base = game.level.layers[0]
        let lifts = CGFloat(game.level.layers.count - 1) * 0.25
        return CGSize(width: CGFloat(base.cols * 2) + lifts, height: CGFloat(base.rows * 2) * 1.3 + lifts)
    }

    private func tile(_ i: Int, width: CGFloat, height: CGFloat, side: CGFloat) -> some View {
        let free = game.free(i)
        return Button { tap(i) } label: {
            look(i, width: width, height: height, side: side, shaded: !free, marked: selected == i || hinted.contains(i))
                .overlay(alignment: .topLeading) {  // a second line on the picked tile, not colour alone
                    if selected == i { RoundedRectangle(cornerRadius: width * 0.12).strokeBorder(Theme.ink, lineWidth: 1.5).padding(4).frame(width: width - side, height: height - side) }
                }
                .offset(y: selected == i ? -side : 0)
                .modifier(Shake(count: CGFloat(shakes[i] ?? 0)))
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityHidden(game.covered(i) && game.tiles.indices.contains { j in  // fully hidden under an aligned tile
            !game.gone.contains(j) && game.tiles[j].z == game.tiles[i].z + 1 && game.tiles[j].x == game.tiles[i].x && game.tiles[j].y == game.tiles[i].y
        })
        .accessibilityLabel(MahjongLogic.name(game.tiles[i].face))
        .accessibilityValue(selected == i ? "picked" : hinted.contains(i) ? "hint" : free ? "free" : "blocked")
    }

    private func look(_ i: Int, width: CGFloat, height: CGFloat, side: CGFloat, shaded: Bool, marked: Bool) -> some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: width * 0.14).fill(Jewel.jade.fill)  // the tile's edge, showing bottom and right
            TileFace(face: game.tiles[i].face, size: width - side)
                .frame(width: width - side, height: height - side)
                .background(Theme.ivory, in: .rect(cornerRadius: width * 0.12))
                .overlay { if shaded { RoundedRectangle(cornerRadius: width * 0.12).fill(Theme.ink.opacity(0.32)) } }
                .overlay(RoundedRectangle(cornerRadius: width * 0.12).strokeBorder(marked ? Theme.gold : Theme.walnut, lineWidth: marked ? 4 : 1))
        }
        .frame(width: width, height: height)
        .dynamicTypeSize(.large)  // faces scale with the tile, not the text setting
    }
}

/// A cleared tile hops up, spins outward and drops off the bottom of the screen.
private struct Fall: ViewModifier {
    /// -1 falls to the left, 1 to the right.
    let direction: CGFloat
    @State private var progress: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .modifier(FallPath(progress: progress, direction: direction))
            .onAppear { withAnimation(.linear(duration: 0.9)) { progress = 1 } }
    }
}

/// The fall's path: a thrown arc, so a straight timeline still looks like gravity.
private struct FallPath: ViewModifier, Animatable {
    var progress: CGFloat
    let direction: CGFloat
    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(direction * 80 * progress))
            .offset(x: direction * 120 * progress, y: 1600 * progress * progress - 400 * progress)
    }
}

/// Large-print faces: a big number or letter over a shape per suit, so a pair is easy to spot without knowing the tiles.
private struct TileFace: View {
    let face: Int
    let size: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            switch face {
            case 0..<27:
                let suit = face / 9
                let colour = [Jewel.sapphire.fill, Jewel.jade.fill, Jewel.ruby.fill][suit]
                Text("\(face % 9 + 1)").font(.system(size: size * 0.55, weight: .heavy, design: .rounded)).foregroundStyle(colour)
                if suit == 2 {
                    Text("萬").font(.system(size: size * 0.4, weight: .bold)).foregroundStyle(colour)
                } else {
                    Image(systemName: suit == 0 ? "circle.fill" : "leaf.fill").font(.system(size: size * 0.32)).foregroundStyle(colour)
                }
            case 27..<31:
                Text(["E", "S", "W", "N"][face - 27]).font(.system(size: size * 0.55, weight: .heavy, design: .serif)).foregroundStyle(Theme.ink)
                Image(systemName: "wind").font(.system(size: size * 0.3, weight: .bold)).foregroundStyle(Theme.ink)
            default:
                let dragon = face - 31
                if dragon == 2 {
                    RoundedRectangle(cornerRadius: size * 0.06).strokeBorder(Jewel.sapphire.fill, lineWidth: size * 0.08)
                        .frame(width: size * 0.55, height: size * 0.75)
                } else {
                    Text(dragon == 0 ? "中" : "發").font(.system(size: size * 0.62, weight: .heavy)).foregroundStyle(dragon == 0 ? Jewel.ruby.fill : Jewel.jade.fill)
                }
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.5)
    }
}
