import SwiftUI

/// Word search at the Bookshop: slide a finger along a word, or tap its first letter then its last. No timer; unlimited hints; saves after every word.
struct WordSearchView: View {
    static let id = "wordsearch"

    private enum Phase { case menu, board, won }

    @State private var game = Save.load(Self.id, as: WordSearchGame.self)
    @State private var phase: Phase = Save.load(Self.id, as: WordSearchGame.self) == nil ? .menu : .board
    /// The first letter tapped, waiting for the last.
    @State private var anchor: Int?
    /// What to do next, or why the last pick didn't count.
    @State private var prompt = Self.firstPrompt
    /// Whether the how-to-play popup is open.
    @State private var rules = false
    /// Squares of the word just found, glowing for a moment.
    @State private var glow: Set<Int> = []
    @State private var misses = 0
    /// Per square, how many missed picks ran through it; each one shakes it.
    @State private var shakes: [Int: Int] = [:]
    @State private var wonLevel = ""
    @State private var earned = 0
    @State private var unlocked: Village.Stage?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.highContrast) private var highContrast
    @Environment(\.dismiss) private var dismiss
    @Environment(Village.self) private var village

    private static let firstPrompt = "Tap the first letter of a word."

    var body: some View {
        Group {
            switch phase {
            case .menu: menu
            case .board: if let game { board(game) }
            case .won: won
            }
        }
        .screen()
        .sensoryFeedback(.success, trigger: glow) { (_: Set<Int>, new: Set<Int>) in !new.isEmpty }
        .sensoryFeedback(.selection, trigger: anchor)
        .sensoryFeedback(.warning, trigger: misses)
    }

    private var menu: some View {
        ScrollView {
            VStack(spacing: 20) {
                Heading(text: "Word Search")
                Text("At the Bookshop").font(.title3.weight(.semibold))
                Button { rules = true } label: { Label("How to play", systemImage: "questionmark.circle") }.jewel(.amethyst)
                ForEach(Array(zip(WordSearchLogic.Level.allCases, [Jewel.jade, .amber, .ruby])), id: \.0) { level, jewel in
                    let stars = WordSearchLogic.Level.allCases.firstIndex(of: level)! + 1  // what a solve pays, as in WordSearchGame.stars
                    Button { start(level) } label: {
                        VStack(spacing: 2) {
                            Text("\(level.rawValue) · \(level.words) words")
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
                Text("Find every word in the list hidden among the letters.\n\nSlide your finger along a word, from its first letter to its last. If that's hard, tap the first letter, then tap the last letter instead. If the word is there, it is marked in colour and ticked off the list. Tap a letter again to let it go.\n\nEasy words read across and down. Medium words can also run on a slant. Hard words can run backwards too.\n\nThere is no timer. Stuck? Tap Hint and the first letter of a word is picked for you.")
                    .font(.title3)
            }
            Button("Got it") { rules = false }.jewel(.gold)
        }
        .foregroundStyle(highContrast ? .black : Theme.ink)
        .screen()
    }

    private func board(_ g: WordSearchGame) -> some View {
        VStack(spacing: 8) {
            HStack {
                Button("Menu") { dismiss() }.jewel(.onyx)
                Button("New puzzle") { phase = .menu }.jewel(.sapphire)
            }
            Text(g.theme).font(.system(.title2, design: .serif, weight: .heavy))
                .accessibilityAddTraits(.isHeader)
            Text(prompt).font(.title3).multilineTextAlignment(.center)
                .accessibilityAddTraits(.updatesFrequently)
            LetterGrid(game: g, anchor: anchor, glow: glow, shakes: shakes, tap: tap, drag: drag)
            WordList(game: g)
            Button("Hint: pick a first letter", action: hint).jewel(.gold)
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)  // leave the grid its room
        }
    }

    private var won: some View {
        VStack(spacing: 20) {
            Heading(text: "Well done!")
            ScrollView {
                VStack(spacing: 16) {
                    StarCelebration(stars: earned)
                    Text("You found every word in the \(wonLevel.lowercased()) puzzle and earned \(earned) ★ for your village.").font(.title3)
                    VillageView(stage: village.stage, crop: true).frame(height: 300).clipShape(.rect(cornerRadius: 14))
                    if let unlocked { Text("Your village grew: \(unlocked.name.lowercased())!").font(.title3.bold()) }
                }
                .padding(8)
            }
            Button("New puzzle") { Ads.shared.showBetweenGames(); phase = .menu }.jewel(.gold)
            Button("Menu") { Ads.shared.showBetweenGames(); dismiss() }.jewel(.onyx)
        }
    }

    private func start(_ level: WordSearchLogic.Level) {
        game = WordSearchLogic.generate(level, seed: .random(in: 0...UInt64.max))
        anchor = nil
        prompt = Self.firstPrompt
        glow = []
        shakes = [:]
        afterMove()
        phase = .board
    }

    /// First tap holds a letter; the second checks the line between them. A miss moves the hold to the new letter.
    private func tap(_ i: Int) {
        guard let g = game else { return }
        guard let a = anchor, a != i else {
            anchor = anchor == i ? nil : i
            prompt = anchor == nil ? Self.firstPrompt : "Now tap the last letter of the word."
            return
        }
        if !pick(a, i) {
            miss(g.line(a, i) ?? [a, i])
            anchor = i
            prompt = g.line(a, i) == nil
                ? "Words run in a straight line. Now tap the last letter from here."
                : "No word there. Now tap the last letter from here."
        }
    }

    /// A finger slid from a to b. The grid already snapped b onto a straight line.
    private func drag(_ a: Int, _ b: Int) {
        anchor = nil
        if !pick(a, b), let g = game {
            miss(g.line(a, b) ?? [a, b])
            prompt = "No word there. Slide along a word, or tap its first letter."
        }
    }

    /// Shakes the letters of a pick that wasn't a word.
    private func miss(_ squares: [Int]) {
        misses += 1
        Sound.miss.play()
        withAnimation(reduceMotion ? nil : .linear(duration: 0.4)) {
            for i in squares { shakes[i, default: 0] += 1 }
        }
    }

    /// Marks the word from a to b if there is one.
    private func pick(_ a: Int, _ b: Int) -> Bool {
        guard var g = game, let word = g.pick(a, b) else { return false }
        game = g
        anchor = nil
        prompt = "You found \(word)!"
        Sound.tap.play()
        let squares = Set(g.line(a, b) ?? [])
        withAnimation(.easeOut(duration: 0.2)) { glow = squares }
        Task { try? await Task.sleep(for: .seconds(0.8)); withAnimation(.easeIn(duration: 0.4)) { glow = [] } }
        afterMove()
        return true
    }

    /// Picks the first letter of a word not found yet, and names the word.
    private func hint() {
        guard let g = game, let f = g.hidden.first(where: { !g.isFound($0.word) }) else { return }
        anchor = f.start
        prompt = "This is the first letter of \(f.word). Now tap its last letter."
    }

    private func afterMove() {
        guard let g = game else { return }
        if g.solved {
            Save.clear(Self.id)
            Sound.win.play()
            wonLevel = g.level.rawValue
            earned = g.stars
            unlocked = village.earn(earned)
            Ads.shared.gameFinished()
            Task {  // let the last word glow before the win screen
                try? await Task.sleep(for: .seconds(reduceMotion ? 0.3 : 1))
                game = nil
                phase = .won
            }
        } else {
            Save.store(Self.id, g)
        }
    }
}

/// The letters on ivory paper in a walnut frame. Found words are marked with a coloured band, and their letters turn bold so it isn't colour alone.
private struct LetterGrid: View {
    let game: WordSearchGame
    let anchor: Int?
    let glow: Set<Int>
    let shakes: [Int: Int]
    let tap: (Int) -> Void
    let drag: (Int, Int) -> Void
    /// The finger's first square and the square it has snapped to, while sliding.
    @State private var slide: (from: Int, to: Int)?

    /// Light highlighter colours, so ink letters stay readable on top.
    private static let marks: [Color] = [0xF3C969, 0x9CC9E8, 0xB8DDA8, 0xF2A7A0, 0xC9B6E4].map { Color(hex: $0) }

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height) - 24  // room for the frame
            let n = game.size
            let cell = side / CGFloat(n)
            let foundSquares = Set(game.found.flatMap { game.line($0.start, $0.end) ?? [] })
            ZStack {
                Canvas { ctx, _ in
                    func center(_ i: Int) -> CGPoint { CGPoint(x: (CGFloat(i % n) + 0.5) * cell, y: (CGFloat(i / n) + 0.5) * cell) }
                    for (k, f) in game.found.enumerated() {
                        var band = Path()
                        band.move(to: center(f.start))
                        band.addLine(to: center(f.end))
                        ctx.stroke(band, with: .color(Self.marks[k % Self.marks.count]), style: StrokeStyle(lineWidth: cell * 0.78, lineCap: .round))
                    }
                    if let slide {
                        var band = Path()
                        band.move(to: center(slide.from))
                        band.addLine(to: center(slide.to))
                        ctx.stroke(band, with: .color(Theme.gold.opacity(0.6)), style: StrokeStyle(lineWidth: cell * 0.78, lineCap: .round))
                    }
                }
                VStack(spacing: 0) {
                    ForEach(0..<n, id: \.self) { row in
                        HStack(spacing: 0) {
                            ForEach(0..<n, id: \.self) { col in
                                square(row * n + col, size: cell, found: foundSquares.contains(row * n + col))
                            }
                        }
                    }
                }
            }
            .frame(width: side, height: side)
            // Alongside the letter buttons, which still take plain taps. A slide that stays on one letter is left to its button.
            .simultaneousGesture(DragGesture(minimumDistance: 12).onChanged { v in
                let from = slide?.from ?? square(at: v.startLocation, cell: cell)
                slide = (from, game.snap(from: from, across: (v.location.x - (CGFloat(from % n) + 0.5) * cell) / cell, down: (v.location.y - (CGFloat(from / n) + 0.5) * cell) / cell))
            }.onEnded { _ in
                if let s = slide, s.from != s.to { drag(s.from, s.to) }
                slide = nil
            })
            .background(Theme.ivory)
            .padding(12)
            .background(Theme.walnut, in: .rect(cornerRadius: 10))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minHeight: 260)
    }

    private func square(at p: CGPoint, cell: CGFloat) -> Int {
        let n = game.size
        return min(max(Int(p.y / cell), 0), n - 1) * n + min(max(Int(p.x / cell), 0), n - 1)
    }

    private func square(_ i: Int, size: CGFloat, found: Bool) -> some View {
        let held = anchor == i
        return Button { tap(i) } label: {
            Text(game.letters[i])
                .font(.system(size: size * 0.6, weight: found || held ? .heavy : .medium, design: .rounded))
                .foregroundStyle(Theme.ink)
                .scaleEffect(glow.contains(i) ? 1.25 : 1)
                .modifier(Shake(count: CGFloat(shakes[i] ?? 0)))
                .frame(width: size, height: size)
                .background { if held { Circle().fill(Theme.gold).padding(2) } }
                .overlay { if held { Circle().strokeBorder(Theme.ink, lineWidth: 3).padding(2) } }  // outline too, not colour alone
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .dynamicTypeSize(.large)  // letters scale with the grid, not the text setting
        .accessibilityLabel("Row \(i / game.size + 1), column \(i % game.size + 1), \(game.letters[i])")
        .accessibilityValue(held ? "first letter picked" : found ? "part of a found word" : "")
    }
}

/// The words to find, two columns, ticked and struck through once found.
private struct WordList: View {
    let game: WordSearchGame

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)], spacing: 6) {
            ForEach(game.words, id: \.self) { word in
                let done = game.isFound(word)
                HStack(spacing: 6) {
                    Image(systemName: done ? "checkmark.circle.fill" : "circle")
                    Text(word).strikethrough(done).lineLimit(1).minimumScaleFactor(0.6)
                }
                .font(.title3.weight(done ? .regular : .bold))
                .opacity(done ? 0.6 : 1)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(word), \(done ? "found" : "not found yet")")
            }
        }
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)  // two columns can't grow further
    }
}
