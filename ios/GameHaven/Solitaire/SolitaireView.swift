import SwiftUI

/// Klondike solitaire at the Maple Cabin: drag a card where it should go, or tap it then tap the place. Nothing moves on its own, so the player makes every choice. No timer; unlimited undo and hints; saves after every move.
struct SolitaireView: View {
    static let id = "solitaire"

    private enum Phase { case menu, board, won }

    @State private var game = Save.load(Self.id, as: SolitaireGame.self)
    @State private var phase: Phase = Save.load(Self.id, as: SolitaireGame.self) == nil ? .menu : .board
    /// What to do next, or why the last tap didn't move anything.
    @State private var prompt = Self.firstPrompt
    @State private var rules = false
    /// The card Hint points at.
    @State private var hinted: Int?
    /// The card tapped to pick up, waiting for a tap on where it goes.
    @State private var selected: SolitaireGame.Spot?
    @State private var misses = 0
    /// Per card, how many taps went nowhere; each one shakes it.
    @State private var shakes: [Int: Int] = [:]
    /// Finish is sending the cards home one by one.
    @State private var finishing = false
    @State private var earned = 0
    @State private var unlocked: Village.Stage?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.highContrast) private var highContrast
    @Environment(\.dismiss) private var dismiss
    @Environment(Village.self) private var village

    private static let firstPrompt = "Drag a card to where it should go."

    var body: some View {
        Group {
            switch phase {
            case .menu: menu
            case .board: if let game { board(game) }
            case .won: won
            }
        }
        .screen()
        .sensoryFeedback(.selection, trigger: game?.history.count)
        .sensoryFeedback(.warning, trigger: misses)
    }

    private var menu: some View {
        ScrollView {
            VStack(spacing: 20) {
                Heading(text: "Solitaire")
                Text("At the Maple Cabin").font(.title3.weight(.semibold))
                Button { rules = true } label: { Label("How to play", systemImage: "questionmark.circle") }.jewel(.amethyst)
                ForEach(Array(zip(SolitaireGame.Draw.allCases, [Jewel.jade, .ruby])), id: \.0) { draw, jewel in
                    let stars = draw == .one ? 2 : 3  // what a win pays, as in SolitaireGame.stars
                    Button { start(draw) } label: {
                        VStack(spacing: 2) {
                            Text(draw == .one ? "Turn 1 card · easier" : "Turn 3 cards · harder")
                            Text(String(repeating: "★", count: stars)).font(.body).accessibilityLabel("\(stars) stars")
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
                Text("Build four home piles at the top, one for each suit, from Ace up to King.\n\nDrag a card to where it should go: home, or onto a card one higher in the other colour, red on black or black on red. A card in a column takes the cards on top of it along. If dragging is hard, tap the card to pick it up, then tap the place it should go. Only a King can go into an empty column.\n\nTap the deck at the top left to turn over a card (three on the harder game). When the deck runs out, tap it again to turn the cards back over.\n\nThere is no timer, and you can undo as often as you like. Stuck? Tap Hint. Not every deal can be won, so starting a new one is never a failure.")
                    .font(.title3)
            }
            Button("Got it") { rules = false }.jewel(.gold)
        }
        .foregroundStyle(highContrast ? .black : Theme.ink)
        .screen()
    }

    private func board(_ g: SolitaireGame) -> some View {
        VStack(spacing: 8) {
            HStack {
                Button("Menu") { dismiss() }.jewel(.onyx)
                Button("New deal") { phase = .menu }.jewel(.sapphire)
            }
            CardTable(game: g, marked: marked(g), shakes: shakes, turn: turn, tap: tap, place: place, drop: { move($0, to: $1, slide: false) })
                .disabled(finishing)
            Text(prompt).font(.title3).multilineTextAlignment(.center)
                .lineLimit(3, reservesSpace: true)  // a fixed height, so the cards don't jump when the note changes
                .minimumScaleFactor(0.8)
                .accessibilityAddTraits(.updatesFrequently)
            HStack {
                Button("Undo", action: undo).jewel(.amethyst).disabled(g.history.isEmpty || finishing)
                if g.canFinish {
                    Button("Finish", action: finish).jewel(.jade).disabled(finishing)
                } else {
                    Button("Hint", action: hint).jewel(.gold)
                }
            }
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)  // leave the cards their room
        }
    }

    private var won: some View {
        VStack(spacing: 20) {
            Heading(text: "Well done!")
            ScrollView {
                VStack(spacing: 16) {
                    StarCelebration(stars: earned)
                    Text("Every card is home, and you earned \(earned) ★ for your village.").font(.title3)
                    VillageView(stage: village.stage, crop: true).frame(height: 300).clipShape(.rect(cornerRadius: 14))
                    if let unlocked { Text("Your village grew: \(unlocked.name.lowercased())!").font(.title3.bold()) }
                }
                .padding(8)
            }
            Button("New deal") { Ads.shared.showBetweenGames(); phase = .menu }.jewel(.gold)
            Button("Menu") { Ads.shared.showBetweenGames(); dismiss() }.jewel(.onyx)
        }
    }

    private func start(_ draw: SolitaireGame.Draw) {
        game = SolitaireGame(draw: draw, seed: .random(in: 0...UInt64.max))
        prompt = Self.firstPrompt
        hinted = nil
        selected = nil
        shakes = [:]
        afterMove()
        phase = .board
    }

    /// Applies a change to the game with the cards sliding into place.
    /// `slide` off for a drag, where the card is already under the finger and should just land.
    private func play(slide: Bool = true, _ change: (inout SolitaireGame) -> Bool) -> Bool {
        guard var g = game, change(&g) else { return false }
        hinted = nil
        selected = nil
        withAnimation(reduceMotion || !slide ? nil : .easeInOut(duration: 0.25)) { game = g }
        Sound.tap.play()
        afterMove()
        return true
    }

    /// The picked-up cards and the hinted card, outlined in gold.
    private func marked(_ g: SolitaireGame) -> Set<Int> {
        Set((selected.map { g.cards(at: $0) } ?? []).map(\.id) + [hinted].compactMap { $0 })
    }

    /// Where a tapped or dropped-on card sits, as a place cards can go.
    private func place(of spot: SolitaireGame.Spot) -> SolitaireGame.Target? {
        switch spot {
        case .waste: nil
        case .foundation: .foundation
        case .tableau(let p, _): .tableau(p)
        }
    }

    /// With nothing picked up, picks the card up. With a card picked up, a tap somewhere else tries to put it there.
    private func tap(_ spot: SolitaireGame.Spot, card: Int) {
        guard let g = game else { return }
        if let from = selected, let to = place(of: spot), to != place(of: from) {
            move(from, to: to)
        } else if selected == spot {
            selected = nil
            prompt = Self.firstPrompt
        } else if let c = g.cards(at: spot).first {
            selected = spot
            hinted = nil
            prompt = "You picked up the \(c.name). Now tap where it should go."
        } else {
            miss(card)
            prompt = "That card is face down. Move the cards on top of it first."
        }
    }

    /// A tap on an empty home pile or column.
    private func place(_ to: SolitaireGame.Target) {
        if let from = selected { move(from, to: to) } else { prompt = "Pick up a card first, or drag one here." }
    }

    /// Puts the cards at spot where the player chose. A drop back on their own pile, or off the table, just returns them.
    private func move(_ from: SolitaireGame.Spot, to: SolitaireGame.Target?, slide: Bool = true) {
        guard let g = game, let c = g.cards(at: from).first else { return }
        guard let to, to != place(of: from) else { selected = nil; return }
        if play(slide: slide, { $0.move(from, to: to) }) {
            prompt = "Moved the \(c.name)."
        } else {
            selected = nil
            miss(c.id)
            prompt = to == .foundation
                ? "The \(c.name) can't go home yet. Home piles build up from the Ace, one suit each."
                : "The \(c.name) can't go there. It needs a card one higher in the other colour, or an empty column for a King."
        }
    }

    private func miss(_ card: Int) {
        misses += 1
        Sound.miss.play()
        withAnimation(reduceMotion ? nil : .linear(duration: 0.4)) { shakes[card, default: 0] += 1 }
    }

    private func turn() {
        if play({ $0.turn() }) { prompt = game?.waste.last.map { "You turned over the \($0.name)." } ?? "The deck is ready again." }
    }

    private func undo() {
        if play({ $0.undo() }) { prompt = "Went back one move." }
    }

    private func hint() {
        guard let g = game else { return }
        switch g.hint {
        case .move(let s):
            let c = g.cards(at: s)[0]
            hinted = c.id
            prompt = "Try moving the \(c.name)."
        case .turn:
            hinted = nil
            selected = nil
            prompt = g.stock.isEmpty ? "Tap the empty deck to turn the cards back over." : "Tap the deck to turn over a card."
        case nil:
            hinted = nil
            prompt = "No more moves. Tap Undo to go back, or start a new deal."
        }
    }

    /// Sends every card home one at a time, so the player can watch.
    private func finish() {
        finishing = true
        prompt = "Sending the cards home…"
        Task {
            while play({ $0.finishStep() }) { try? await Task.sleep(for: .seconds(reduceMotion ? 0.05 : 0.15)) }
            finishing = false
        }
    }

    private func afterMove() {
        guard let g = game else { return }
        if g.won {
            Save.clear(Self.id)
            Sound.win.play()
            earned = g.stars
            unlocked = village.earn(earned)
            Ads.shared.gameFinished()
            Task {  // let the last card land before the win screen
                try? await Task.sleep(for: .seconds(reduceMotion ? 0.3 : 1))
                game = nil
                phase = .won
            }
        } else {
            Save.store(Self.id, g)
        }
    }
}

/// The deck, turned cards and four home piles along the top, the seven columns below.
/// Every card sits in one layer at its own spot, so a move slides it across the table.
private struct CardTable: View {
    let game: SolitaireGame
    /// Cards outlined in gold: picked up, or hinted.
    let marked: Set<Int>
    let shakes: [Int: Int]
    let turn: () -> Void
    let tap: (SolitaireGame.Spot, Int) -> Void
    /// A tap on an empty home pile or column.
    let place: (SolitaireGame.Target) -> Void
    /// Cards dragged from a spot and let go over a place, or nil when let go off the table.
    let drop: (SolitaireGame.Spot, SolitaireGame.Target?) -> Void
    /// The cards under the finger and how far they've moved.
    @State private var dragging: (ids: Set<Int>, by: CGSize)?
    @Environment(\.highContrast) private var highContrast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Its own function so older compilers can type-check the board in time.
    // Measured on the screen, not the card, which moves under the finger and would make the drag jitter.
    private func drag(_ item: Placed, target: @escaping (CGPoint) -> SolitaireGame.Target?) -> some Gesture {
        DragGesture(minimumDistance: 8, coordinateSpace: .global).onChanged { v in
            guard let spot = item.spot else { return }
            if dragging == nil {
                let ids = Set(game.cards(at: spot).map(\.id))
                guard !ids.isEmpty else { return }  // face-down cards stay put
                dragging = (ids, .zero)
            }
            dragging?.by = v.translation
        }.onEnded { v in
            guard let spot = item.spot, dragging != nil else { return }
            dragging = nil  // lands, or jumps back, at once
            drop(spot, target(CGPoint(x: item.at.x + v.translation.width, y: item.at.y + v.translation.height)))
        }
    }

    private struct Placed: Identifiable {
        let card: Card
        let at: CGPoint
        /// Nil for the deck.
        let spot: SolitaireGame.Spot?
        /// Nil hides the card from VoiceOver, for cards under the top of a pile.
        let label: String?
        var id: Int { card.id }
    }

    var body: some View {
        GeometryReader { geo in
            let gap: CGFloat = 5
            // Narrow enough that a long column still fits on a short screen.
            let w = min((geo.size.width - gap * 6) / 7, geo.size.height / 6)
            let h = w * 1.4
            let left = (geo.size.width - w * 7 - gap * 6) / 2
            let x = { (col: Int) in left + CGFloat(col) * (w + gap) + w / 2 }
            let columnsTop = h + gap * 3
            // The place under a point: a column, or anywhere along the home piles.
            let target = { (p: CGPoint) -> SolitaireGame.Target? in
                let col = Int(((p.x - left) / (w + gap)).rounded(.down))
                guard (0..<7).contains(col) else { return nil }
                if p.y < columnsTop - gap { return col >= 3 ? .foundation : nil }
                return .tableau(col)
            }
            ZStack(alignment: .topLeading) {
                Button(action: turn) {
                    slot(w, h) { Image(systemName: "arrow.counterclockwise").font(.system(size: w * 0.45, weight: .bold)).opacity(game.waste.isEmpty ? 0 : 1) }
                }
                .buttonStyle(.plain)
                .position(x: x(0), y: h / 2)
                .accessibilityLabel(game.stock.isEmpty ? "Deck, empty. Tap to turn the cards back over." : "Deck, \(game.stock.count) cards. Tap to turn over \(game.draw == .one ? "a card" : "three cards").")
                .accessibilitySortPriority(2)
                ForEach(0..<4, id: \.self) { s in
                    Button { place(.foundation) } label: { slot(w, h) { Image(systemName: Self.symbols[s]).font(.system(size: w * 0.45)).opacity(0.35) } }
                        .buttonStyle(.plain)
                        .position(x: x(3 + s), y: h / 2)
                        .accessibilityLabel("Home pile for \(Card.suits[s]), empty")
                        .accessibilityHidden(!game.foundations[s].isEmpty)
                }
                ForEach(0..<7, id: \.self) { p in
                    Button { place(.tableau(p)) } label: { slot(w, h) { EmptyView() } }
                        .buttonStyle(.plain)
                        .position(x: x(p), y: columnsTop + h / 2)
                        .accessibilityLabel("Column \(p + 1), empty")
                        .accessibilityHidden(!game.tableau[p].isEmpty)
                }
                ForEach(Array(placed(w: w, h: h, x: x, columnsTop: columnsTop, height: geo.size.height).enumerated()), id: \.element.id) { z, item in
                    let lifted = dragging?.ids.contains(item.card.id) == true
                    CardFace(card: item.card, w: w, h: h, marked: marked.contains(item.card.id))
                        .modifier(Shake(count: CGFloat(shakes[item.card.id] ?? 0)))
                        .shadow(color: Theme.ink.opacity(lifted ? 0.4 : 0), radius: 6, y: 4)
                        .onTapGesture { item.spot.map { tap($0, item.card.id) } ?? turn() }
                        .gesture(drag(item, target: target))
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(item.label ?? "")
                        .accessibilityValue(marked.contains(item.card.id) ? "picked up" : "")
                        .accessibilityAddTraits(.isButton)
                        .accessibilityAction { item.spot.map { tap($0, item.card.id) } ?? turn() }
                        .accessibilityHidden(item.label == nil)
                        .position(item.at)
                        .offset(lifted ? dragging!.by : .zero)
                        .zIndex(Double(z) + (lifted ? 1000 : 0))
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
        }
        .frame(minHeight: 300)
    }

    /// Where every card sits. Columns bunch their cards up when they grow long, so the bottom card stays on screen.
    private func placed(w: CGFloat, h: CGFloat, x: (Int) -> CGFloat, columnsTop: CGFloat, height: CGFloat) -> [Placed] {
        var out = game.stock.map { Placed(card: $0, at: CGPoint(x: x(0), y: h / 2), spot: nil, label: nil) }
        // Turn 3 fans its top three cards so all three can be read.
        let fanFrom = game.draw == .three ? max(0, game.waste.count - 3) : game.waste.count
        for (k, c) in game.waste.enumerated() {
            let top = k == game.waste.count - 1
            out.append(Placed(card: c, at: CGPoint(x: x(1) + CGFloat(max(0, k - fanFrom)) * w * 0.45, y: h / 2), spot: .waste, label: top ? "Turned card, \(c.name)" : nil))
        }
        for (s, pile) in game.foundations.enumerated() {
            for (k, c) in pile.enumerated() {
                out.append(Placed(card: c, at: CGPoint(x: x(3 + s), y: h / 2), spot: .foundation(s), label: k == pile.count - 1 ? "Home pile, \(c.name)" : nil))
            }
        }
        let downStep = h * 0.16
        for (p, pile) in game.tableau.enumerated() {
            let under = pile.dropLast()
            let downs = CGFloat(under.filter { !$0.up }.count), ups = CGFloat(under.filter(\.up).count)
            let upStep = ups == 0 ? 0 : min(h * 0.4, max(h * 0.22, (height - columnsTop - h - downs * downStep) / ups))
            var y = columnsTop + h / 2
            for (i, c) in pile.enumerated() {
                out.append(Placed(card: c, at: CGPoint(x: x(p), y: y), spot: .tableau(p, i), label: c.up ? "Column \(p + 1), \(c.name)" : nil))
                y += c.up ? upStep : downStep
            }
        }
        return out
    }

    static let symbols = ["suit.spade.fill", "suit.heart.fill", "suit.diamond.fill", "suit.club.fill"]

    /// An outlined empty place on the table.
    private func slot(_ w: CGFloat, _ h: CGFloat, @ViewBuilder _ mark: () -> some View) -> some View {
        RoundedRectangle(cornerRadius: w * 0.12)
            .strokeBorder(highContrast ? .black : Theme.walnut.opacity(0.6), lineWidth: 2)
            .background(Theme.paperEdge.opacity(0.5), in: .rect(cornerRadius: w * 0.12))
            .overlay(mark().foregroundStyle(highContrast ? .black : Theme.walnut))
            .frame(width: w, height: h)
            .contentShape(.rect)
    }
}

/// A card: big rank and suit in the top corner so they show when cards overlap, and a large suit below.
/// Suits differ in shape as well as colour. Face down it shows a walnut back.
private struct CardFace: View {
    let card: Card
    let w: CGFloat
    let h: CGFloat
    let marked: Bool
    @Environment(\.highContrast) private var highContrast

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: w * 0.12)
        ZStack {
            if card.up {
                shape.fill(highContrast ? .white : Theme.ivory)
                VStack(spacing: 0) {
                    HStack(spacing: 1) {
                        Text(card.short).font(.system(size: w * 0.4, weight: .heavy, design: .rounded))
                        Image(systemName: CardTable.symbols[card.suit]).font(.system(size: w * 0.26, weight: .bold))
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, w * 0.06)
                    Spacer(minLength: 0)
                    Image(systemName: CardTable.symbols[card.suit]).font(.system(size: w * 0.55))
                    Spacer(minLength: 0)
                }
                .padding(.vertical, h * 0.04)
                .foregroundStyle(card.red ? Color(hex: highContrast ? 0x9B0000 : 0xB3261E) : highContrast ? .black : Theme.ink)
            } else {
                shape.fill(Theme.walnut)
                shape.inset(by: w * 0.1).strokeBorder(Theme.gold.opacity(0.7), lineWidth: 2)
            }
            shape.strokeBorder(marked ? Theme.gold : highContrast ? .black : Theme.ink.opacity(0.5), lineWidth: marked ? 4 : 1)
        }
        .frame(width: w, height: h)
        .shadow(color: Theme.walnut.opacity(0.3), radius: 1, y: 1)
        .contentShape(.rect)
        .dynamicTypeSize(.large)  // cards scale with the table, not the text setting
    }
}
