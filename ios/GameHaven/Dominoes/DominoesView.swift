import SwiftUI

/// Dominoes at the Pine Cabin: match a tile to an open end, against a gentle computer player.
/// No timer; unlimited undo and hints; saves after every move.
struct DominoesView: View {
    static let id = "dominoes"

    private enum Phase { case menu, board, over }

    @State private var game = Save.load(Self.id, as: DominoGame.self)
    @State private var phase: Phase = Save.load(Self.id, as: DominoGame.self) == nil ? .menu : .board
    /// What to do next, or what the computer just did.
    @State private var prompt = ""
    @State private var rules = false
    /// A tile that fits both ends, waiting for the player to pick one.
    @State private var selected: Int?
    @State private var hinted: Int?
    @State private var misses = 0
    /// The hand tile being dragged, how far it has moved, and the end it would land on if dropped now.
    @State private var dragging: Int?
    @State private var dragOffset: CGSize = .zero
    @State private var dropSide: DominoGame.Side?
    /// The felt, in the board's coordinates, so a drop can be matched to an end.
    @State private var tableFrame: CGRect = .zero
    /// The computer's face-down tiles, where its moves fly from.
    @State private var opponentFrame: CGRect = .zero
    /// The tile the computer just played, flying from its hand to the table.
    @State private var computerTile: Domino?
    /// The computer's move is still playing out, so the player waits.
    @State private var busy = false
    /// The finished game, for the result screen.
    @State private var finished: DominoGame?
    @State private var unlocked: Village.Stage?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.highContrast) private var highContrast
    @Environment(\.dismiss) private var dismiss
    @Environment(Village.self) private var village

    var body: some View {
        Group {
            switch phase {
            case .menu: menu
            case .board: if let game { board(game) }
            case .over: over
            }
        }
        .screen()
        .onAppear { if let game { prompt = status(game) } }
        .sensoryFeedback(.success, trigger: game?.board.line.count) { old, new in (new ?? 0) > (old ?? 0) }
        .sensoryFeedback(.selection, trigger: selected)
        .sensoryFeedback(.warning, trigger: misses)
    }

    private var menu: some View {
        ScrollView {
            VStack(spacing: 20) {
                Heading(text: "Dominoes")
                Text("At the Pine Cabin").font(.title3.weight(.semibold))
                Button { rules = true } label: { Label("How to play", systemImage: "questionmark.circle") }.jewel(.amethyst)
                ForEach(Array(zip(DominoLogic.Level.allCases, [Jewel.jade, .ruby])), id: \.0) { level, jewel in
                    let stars = level == .easy ? 2 : 3  // what a win pays, as in DominoGame.stars
                    Button { start(level) } label: {
                        VStack(spacing: 2) {
                            Text("\(level.rawValue) · vs the computer")
                            Text(String(repeating: "★", count: stars)).font(.body).accessibilityLabel("\(stars) stars for a win")
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
                Text("You and the computer each start with 7 tiles. Take turns adding a tile to either end of the line on the table.\n\nA tile fits when one of its halves has the same number of dots as that end. Tiles that fit are bright; the rest are shaded. Drag a tile onto the end you want, or just tap it. If you tap a tile that fits both ends, you'll be asked which end.\n\nIf nothing fits, tap Draw to take a tile from the pile. When the pile is empty and nothing fits, tap Pass.\n\nThe first to play all their tiles wins. If nobody can play, whoever has fewer dots left wins.\n\nThere is no timer, and you can undo as often as you like. Stuck? Tap Hint.")
                    .font(.title3)
            }
            Button("Got it") { rules = false }.jewel(.gold)
        }
        .foregroundStyle(highContrast ? .black : Theme.ink)
        .screen()
    }

    private func board(_ g: DominoGame) -> some View {
        VStack(spacing: 8) {
            HStack {
                Button("Menu") { dismiss() }.jewel(.onyx)
                Button("New game") { phase = .menu }.jewel(.sapphire)
            }
            Group {
                opponent(g)
                table(g)
                Text(prompt).font(.title3).multilineTextAlignment(.center)
                    .lineLimit(3, reservesSpace: true)  // a fixed height, so the tiles don't jump when the note changes
                    .minimumScaleFactor(0.8)
                    .accessibilityAddTraits(.updatesFrequently)
                hand(g).zIndex(1)  // a dragged tile passes over the table
                controls(g)
            }
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)  // leave the tiles their room
        }
        .coordinateSpace(.named("board"))
    }

    /// Where each line tile sits on a felt of this size: spots in half-tile units, points per unit, and the unit row at the felt's centre.
    private func tableLayout(_ g: DominoGame, _ size: CGSize) -> (spots: [DominoLogic.Spot], unit: CGFloat, middle: Double) {
        let width = 12.0  // in half tiles: five tiles a row
        let spots = DominoLogic.layout(g.board.line, first: g.board.left, width: width)
        let top = spots.map { $0.y - ($0.vertical ? 1 : 0.5) }.min() ?? 0
        let bottom = spots.map { $0.y + ($0.vertical ? 1 : 0.5) }.max() ?? 0
        return (spots, min((size.width - 24) / width, (size.height - 24) / max(bottom - top, 4)), (top + bottom) / 2)
    }

    /// Of the ends this tile fits, the one nearest a point on the board; nil when the point is off the table.
    private func nearestEnd(_ g: DominoGame, _ d: Domino, to p: CGPoint) -> DominoGame.Side? {
        guard tableFrame.contains(p) else { return nil }
        let sides = g.sides(d)
        guard sides.count == 2 else { return sides.first }
        let (spots, unit, middle) = tableLayout(g, tableFrame.size)
        func distance(_ k: Int) -> CGFloat {
            hypot(tableFrame.midX + spots[k].x * unit - p.x, tableFrame.midY + (spots[k].y - middle) * unit - p.y)
        }
        return distance(0) <= distance(g.board.line.count - 1) ? .left : .right
    }

    private func drop(_ i: Int, at p: CGPoint) {
        guard let g = game, g.board.you.indices.contains(i) else { return }
        let d = g.board.you[i]
        let side = nearestEnd(g, d, to: p)
        dropSide = nil
        if let side {
            dragging = nil
            dragOffset = .zero
            place(i, side)
            return
        }
        if tableFrame.contains(p) { tap(i) }  // doesn't fit: says why
        withAnimation(reduceMotion ? nil : .spring(duration: 0.3)) { dragOffset = .zero } completion: { dragging = nil }
    }

    /// The computer's tiles face down, and the pile.
    private func opponent(_ g: DominoGame) -> some View {
        HStack(spacing: 10) {
            Text("Computer").font(.headline)
            HStack(spacing: 3) {
                ForEach(0..<min(g.board.computer.count, 10), id: \.self) { _ in DominoBack().frame(width: 16, height: 32) }
                if g.board.computer.count > 10 { Text("+\(g.board.computer.count - 10)").font(.headline) }
            }
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .named("board")) } action: { opponentFrame = $0 }
            Spacer(minLength: 0)
            Text("Pile \(g.board.pile.count)").font(.headline)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("The computer has \(g.board.computer.count) tiles. \(g.board.pile.count) in the pile.")
    }

    /// The line as on a real table (see DominoLogic.layout), scaled to fit the felt. The two open ends are outlined in gold.
    private func table(_ g: DominoGame) -> some View {
        GeometryReader { geo in
            let (spots, unit, middle) = tableLayout(g, geo.size)
            ZStack {
                ForEach(Array(g.board.line.enumerated()), id: \.element) { k, d in
                    let spot = spots[k]
                    let end: DominoGame.Side? = k == 0 ? .left : k == g.board.line.count - 1 ? .right : nil
                    DominoTile(domino: spot.flipped ? d.flipped : d, horizontal: !spot.vertical, marked: end != nil)
                        .frame(width: unit * (spot.vertical ? 1 : 2) - 2, height: unit * (spot.vertical ? 2 : 1) - 2)  // a hairline gap between tiles
                        .scaleEffect(end != nil && (end == dropSide || g.board.line.count == 1 && dropSide != nil) ? 1.25 : 1)  // the end a drop would land on
                        .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: dropSide)
                        .offset(x: spot.x * unit, y: (spot.y - middle) * unit)
                        // From the computer's hand to here: the gap between them, in the felt's coordinates.
                        .modifier(FlyIn(from: CGSize(width: opponentFrame.midX - tableFrame.midX - spot.x * unit, height: opponentFrame.midY - tableFrame.midY - (spot.y - middle) * unit),
                                        active: d == computerTile && !reduceMotion))
                        .zIndex(d == computerTile ? 1 : 0)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .frame(maxWidth: .infinity, minHeight: 150, maxHeight: .infinity)
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .named("board")) } action: { tableFrame = $0 }
        .background {  // the rim sits under the tiles, so the computer's tile flies over it
            RoundedRectangle(cornerRadius: 16).fill(Color(hex: 0x2F5E45))
                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Theme.walnut, lineWidth: 6))
        }
        .overlay { if g.board.line.isEmpty { Text("The table is empty").font(.title3.weight(.semibold)).foregroundStyle(Theme.ivory) } }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(g.ends.map { "Table: \(g.board.line.count) tiles. Left end \($0.left), right end \($0.right)." } ?? "The table is empty")
    }

    private func hand(_ g: DominoGame) -> some View {
        VStack(spacing: 6) {
            Text("Your tiles").font(.headline).accessibilityAddTraits(.isHeader)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: min(max(7, g.board.you.count), 10)), spacing: 12) {  // one row up to 10 tiles
                ForEach(Array(g.board.you.enumerated()), id: \.element) { i, d in
                    let fits = !g.sides(d).isEmpty
                    // Tap or drag: tapping stays, since dragging is hard for some hands.
                    DominoTile(domino: d, horizontal: false, marked: selected == i || hinted == i, shaded: !fits)
                        .offset(y: selected == i ? -8 : 0)
                        .scaleEffect(dragging == i ? 1.15 : 1)
                        .shadow(color: .black.opacity(dragging == i ? 0.3 : 0), radius: 6, y: 4)
                        .offset(dragging == i ? dragOffset : .zero)
                        .zIndex(dragging == i ? 1 : 0)
                        .contentShape(.rect)
                        .onTapGesture { tap(i) }
                        .gesture(DragGesture(minimumDistance: 8, coordinateSpace: .named("board"))
                            .onChanged { v in
                                guard !g.over, !busy else { return }
                                if dragging != i { dragging = i; selected = nil; hinted = nil }
                                dragOffset = v.translation
                                dropSide = nearestEnd(g, d, to: v.location)
                            }
                            .onEnded { v in if dragging == i { drop(i, at: v.location) } })
                        .accessibilityAddTraits(.isButton)
                        .accessibilityLabel(d.name)
                    .accessibilityValue(selected == i ? "picked" : hinted == i ? "hint" : fits ? "fits" : "doesn't fit")
                }
            }
        }
    }

    @ViewBuilder private func controls(_ g: DominoGame) -> some View {
        if let s = selected, let (l, r) = g.ends {
            HStack {
                Button("Left end (\(l))") { place(s, .left) }.jewel(.gold)
                Button("Right end (\(r))") { place(s, .right) }.jewel(.gold)
            }
        } else {
            HStack {
                Button("Undo", action: undo).jewel(.amethyst).disabled(g.history.isEmpty)
                if g.mustDraw {
                    Button("Draw") { act { $0.draw() } }.jewel(.jade)
                } else if g.mustPass {
                    Button("Pass") { act { $0.pass() } }.jewel(.jade)
                } else {
                    Button("Hint", action: hint).jewel(.gold).disabled(g.over)
                }
            }
            .disabled(busy)
        }
    }

    private var over: some View {
        let g = finished
        let earned = g?.stars ?? 0
        let (title, line): (String, String) = switch g?.result {
        case .won: ("You won!", g?.board.you.isEmpty == true ? "You played all your tiles." : "Nobody could play, and you had fewer dots left.")
        case .tie: ("A tie!", "Nobody could play, and you both had the same dots left.")
        default: ("Good game!", g?.board.computer.isEmpty == true ? "The computer played all its tiles first." : "Nobody could play, and the computer had fewer dots left.")
        }
        return VStack(spacing: 20) {
            Heading(text: title)
            ScrollView {
                VStack(spacing: 16) {
                    StarCelebration(stars: earned)
                    Text("\(line) You earned \(earned) ★ for your village.").font(.title3)
                    VillageView(stage: village.stage, crop: true).frame(height: 300).clipShape(.rect(cornerRadius: 14))
                    if let unlocked { Text("Your village grew: \(unlocked.name.lowercased())!").font(.title3.bold()) }
                }
                .padding(8)
            }
            Button("New game") { Ads.shared.showBetweenGames(); phase = .menu }.jewel(.gold)
            Button("Menu") { Ads.shared.showBetweenGames(); dismiss() }.jewel(.onyx)
        }
    }

    private func start(_ level: DominoLogic.Level) {
        game = DominoLogic.generate(level, seed: .random(in: 0...UInt64.max))
        computerTile = game!.board.line.first  // the computer's opening double, if it had the highest
        selected = nil
        hinted = nil
        afterMove()
        phase = .board
    }

    /// Applies a move with the tiles sliding into place.
    @discardableResult private func act(_ change: (inout DominoGame) -> Bool) -> Bool {
        guard var g = game, change(&g) else { return false }
        let before = game!.board
        selected = nil
        hinted = nil
        computerTile = Set(g.board.line).subtracting(before.line).subtracting(before.you).first
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.3)) { game = g }
        Sound.tap.play()
        afterMove()
        return true
    }

    /// A tile that fits one end plays at once; one that fits both waits for the player to pick an end.
    private func tap(_ i: Int) {
        guard let g = game, !g.over, !busy else { return }
        let d = g.board.you[i]
        let sides = g.sides(d)
        if sides.isEmpty {
            misses += 1
            Sound.miss.play()
            if let (l, r) = g.ends { prompt = "The \(d.name) doesn't match either end (\(l) or \(r)). Try a bright tile." }
        } else if sides.count == 1 {
            place(i, sides[0])
        } else {
            selected = selected == i ? nil : i
            prompt = selected == nil ? status(g) : "The \(d.name) fits both ends. Which end?"
        }
    }

    private func place(_ i: Int, _ side: DominoGame.Side) {
        act { $0.play(i, on: side) }
    }

    private func undo() {
        if act({ $0.undo() }) { prompt = "Took back your last move. " + status(game!) }
    }

    private func hint() {
        guard let g = game, let i = g.hint else { return }
        selected = nil
        hinted = i
        prompt = "Try the \(g.board.you[i].name), outlined in gold."
    }

    /// What the computer just did, then what the player can do.
    private func status(_ g: DominoGame) -> String {
        let next = g.over ? "" : g.board.line.isEmpty ? "You go first. Drag or tap any tile."
            : g.mustDraw ? "Nothing fits. Tap Draw to take a tile."
            : g.mustPass ? "Nothing fits and the pile is empty. Tap Pass."
            : "Your turn. Drag or tap a bright tile."
        return [g.board.said, next].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " ")
    }

    private func afterMove() {
        guard let g = game else { return }
        let flying = computerTile != nil && !reduceMotion
        if flying {  // say what the computer did once its tile lands
            busy = true
            prompt = "The computer's turn…"
            Task {
                try? await Task.sleep(for: .seconds(FlyIn.total))
                busy = false
                prompt = status(g)
            }
        } else {
            prompt = status(g)
        }
        if g.over {
            Save.clear(Self.id)
            finished = g
            if g.result == .won { Sound.win.play() }
            unlocked = village.earn(g.stars)
            Ads.shared.gameFinished()
            Task {  // let the last tile land before the result screen
                try? await Task.sleep(for: .seconds(reduceMotion ? 0.3 : flying ? FlyIn.total + 1 : 1.2))
                game = nil
                phase = .over
            }
        } else {
            Save.store(Self.id, g)
        }
    }
}

/// An ivory tile with dots in a 3×3 grid on each half, a brass pin and a thick edge below; vertical in the hand, horizontal on the table.
private struct DominoTile: View {
    let domino: Domino
    let horizontal: Bool
    var marked = false
    var shaded = false

    /// Dot spots per number, as (row, column) on a vertical half.
    private static let spots: [[(Int, Int)]] = [
        [], [(1, 1)], [(0, 0), (2, 2)], [(0, 0), (1, 1), (2, 2)],
        [(0, 0), (0, 2), (2, 0), (2, 2)], [(0, 0), (0, 2), (1, 1), (2, 0), (2, 2)],
        [(0, 0), (1, 0), (2, 0), (0, 2), (1, 2), (2, 2)],
    ]

    var body: some View {
        Canvas { ctx, size in
            let edge = max(2, min(size.width, size.height) * 0.06)
            let face = CGRect(x: 0, y: 0, width: size.width, height: size.height - edge)
            let corner = min(face.width, face.height) * 0.16
            ctx.fill(Path(roundedRect: face.offsetBy(dx: 0, dy: edge), cornerRadius: corner), with: .color(Color(hex: 0xC9B48F)))  // the tile's side
            ctx.fill(Path(roundedRect: face, cornerRadius: corner), with: .linearGradient(Gradient(colors: [Color(hex: 0xFFFBF2), Color(hex: 0xF4E7CF)]), startPoint: .zero, endPoint: CGPoint(x: 0, y: face.height)))
            let side = min(horizontal ? face.width / 2 : face.width, horizontal ? face.height : face.height / 2)
            let inset = side * 0.18
            var line = Path()
            line.move(to: horizontal ? CGPoint(x: face.midX, y: face.minY + inset) : CGPoint(x: face.minX + inset, y: face.midY))
            line.addLine(to: horizontal ? CGPoint(x: face.midX, y: face.maxY - inset) : CGPoint(x: face.maxX - inset, y: face.midY))
            ctx.stroke(line, with: .color(Theme.walnut.opacity(0.7)), lineWidth: max(1, side * 0.04))
            let pin = side * 0.12
            ctx.fill(Path(ellipseIn: CGRect(x: face.midX - pin / 2, y: face.midY - pin / 2, width: pin, height: pin)), with: .color(Color(hex: 0xB8892E)))
            let step = side * 0.26
            let dot = side * 0.17
            for (n, value) in [domino.a, domino.b].enumerated() {
                let centre = horizontal
                    ? CGPoint(x: face.minX + face.width / 2 * (CGFloat(n) + 0.5), y: face.midY)
                    : CGPoint(x: face.midX, y: face.minY + face.height / 2 * (CGFloat(n) + 0.5))
                for (r, c) in Self.spots[value] {
                    // Transposed on a horizontal tile, so a six shows as two rows of three.
                    let (dx, dy) = horizontal ? (CGFloat(r - 1), CGFloat(1 - c)) : (CGFloat(c - 1), CGFloat(r - 1))
                    let p = CGPoint(x: centre.x + dx * step, y: centre.y + dy * step)
                    ctx.fill(Path(ellipseIn: CGRect(x: p.x - dot / 2, y: p.y - dot / 2, width: dot, height: dot)), with: .color(Theme.ink))
                }
            }
            let whole = CGRect(origin: .zero, size: size)
            if shaded { ctx.fill(Path(roundedRect: whole, cornerRadius: corner), with: .color(Theme.ink.opacity(0.35))) }
            ctx.stroke(Path(roundedRect: whole.insetBy(dx: marked ? 1.5 : 0.5, dy: marked ? 1.5 : 0.5), cornerRadius: corner),
                       with: .color(marked ? Theme.gold : Theme.walnut), lineWidth: marked ? 3 : 1)
        }
        .aspectRatio(horizontal ? 2 : 0.5, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

/// The computer's tile waits on its hand, then flies to its spot, face up so the player sees what it played.
private struct FlyIn: ViewModifier {
    static let wait = 0.5, flight = 0.7
    static var total: Double { wait + flight }
    let from: CGSize
    let active: Bool
    @State private var progress: CGFloat

    init(from: CGSize, active: Bool) {
        self.from = from
        self.active = active
        _progress = State(initialValue: active ? 0 : 1)
    }

    func body(content: Content) -> some View {
        content
            .modifier(FlyPath(progress: progress, from: from))
            .onAppear { if progress < 1 { withAnimation(.easeInOut(duration: Self.flight).delay(Self.wait)) { progress = 1 } } }
    }
}

/// The flight itself: the tile face up the whole way, lifting off the table mid-flight.
private struct FlyPath: ViewModifier, Animatable {
    var progress: CGFloat
    let from: CGSize
    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        content
            .scaleEffect(1 + 0.25 * sin(progress * .pi))  // lifts off the table mid-flight
            .offset(x: from.width * (1 - progress), y: from.height * (1 - progress))
    }
}

/// A face-down tile in the computer's hand.
private struct DominoBack: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 4).fill(Theme.walnut)
            .overlay(Circle().fill(Color(hex: 0xB8892E)).frame(width: 4, height: 4))
            .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Theme.ink.opacity(0.5), lineWidth: 1))
            .accessibilityHidden(true)
    }
}
