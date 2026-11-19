import SwiftUI

/// Jigsaw at the Koi Pond: drag a piece from the tray to its spot, or tap the piece then tap the spot.
/// A piece only goes in its own spot, so nothing is ever placed wrong. No timer; unlimited hints; saves after every piece.
struct JigsawView: View {
    static let id = "jigsaw"

    private enum Phase { case menu, board, won }

    @State private var game = Save.load(Self.id, as: JigsawGame.self)
    @State private var phase: Phase = Save.load(Self.id, as: JigsawGame.self) == nil ? .menu : .board
    /// The picture picked on the menu.
    @State private var picture = 0
    /// The piece tapped, waiting for its spot.
    @State private var held: Int?
    /// The piece under the finger and where the finger is, while dragging.
    @State private var dragging: (piece: Int, at: CGPoint)?
    /// What to do next, or why the last try didn't fit.
    @State private var prompt = Self.firstPrompt
    /// Whether the how-to-play popup is open.
    @State private var rules = false
    /// The piece just placed, glowing for a moment.
    @State private var glow: Int?
    /// The spot a hint is pointing at.
    @State private var hinted: Int?
    /// Where the piece being placed flies in from (offset from its spot) and its size there.
    @State private var flight = (from: CGSize.zero, scale: CGFloat(1))
    /// Petals bursting from the spot a piece just landed in; `n` restarts the burst each time.
    @State private var burst: (spot: Int, n: Int)?
    /// Pieces placed in a row without a miss.
    @State private var streak = 0
    @State private var misses = 0
    /// Per piece, how many tries didn't fit; each one shakes it.
    @State private var shakes: [Int: Int] = [:]
    @State private var wonLevel = ""
    @State private var earned = 0
    @State private var unlocked: Village.Stage?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.highContrast) private var highContrast
    @Environment(\.dismiss) private var dismiss
    @Environment(Village.self) private var village

    private static let firstPrompt = "Pick up a piece from the tray below."
    private static let cheers = ["It fits!", "Lovely!", "Perfect fit!", "Well spotted!", "Beautiful!"]

    var body: some View {
        Group {
            switch phase {
            case .menu: menu
            case .board: if let game { board(game) }
            case .won: won
            }
        }
        .screen()
        .sensoryFeedback(.success, trigger: glow) { _, new in new != nil }
        .sensoryFeedback(.selection, trigger: held)
        .sensoryFeedback(.warning, trigger: misses)
    }

    private var menu: some View {
        ScrollView {
            VStack(spacing: 20) {
                Heading(text: "Jigsaw")
                Text("At the Koi Pond").font(.title3.weight(.semibold))
                Button { rules = true } label: { Label("How to play", systemImage: "questionmark.circle") }.jewel(.amethyst)
                Text("Choose a picture").font(.title3.bold())
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(JigsawLogic.pictures.indices, id: \.self) { i in
                        let chosen = picture == i
                        Button { picture = i } label: {
                            VStack(spacing: 4) {
                                Image(uiImage: JigsawPicture.image(i)).resizable().aspectRatio(1, contentMode: .fit)
                                    .clipShape(.rect(cornerRadius: 8))
                                Text(JigsawLogic.pictures[i]).font(.headline).lineLimit(2).minimumScaleFactor(0.7)
                                if chosen { Label("Chosen", systemImage: "checkmark.circle.fill").font(.headline) }  // not colour alone
                            }
                            .padding(6)
                            .background(chosen ? Theme.gold : Theme.ivory, in: .rect(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(highContrast ? .black : Theme.walnut, lineWidth: chosen ? 4 : 2))
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(chosen ? .isSelected : [])
                    }
                }
                ForEach(Array(zip(JigsawLogic.Level.allCases, [Jewel.jade, .amber, .ruby])), id: \.0) { level, jewel in
                    let stars = JigsawLogic.Level.allCases.firstIndex(of: level)! + 1  // what a solve pays, as in JigsawGame.stars
                    Button { start(level) } label: {
                        VStack(spacing: 2) {
                            Text("\(level.rawValue) · \(level.pieces) pieces")
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
                Text("Put the picture back together.\n\nSlide a piece from the tray up to its spot in the frame. If that's hard, tap a piece to pick it up, then tap the spot where it goes. A piece only goes in its own spot, so you can't get it wrong. If it doesn't fit, it stays in the tray.\n\nEdge pieces have a straight side. The bumps and dips on each piece match its neighbours.\n\nEasy and Medium show a faint copy of the picture in the frame to help you. Hard doesn't.\n\nThere is no timer. Stuck? Tap Hint and the spot for a piece will light up.")
                    .font(.title3)
            }
            Button("Got it") { rules = false }.jewel(.gold)
        }
        .foregroundStyle(highContrast ? .black : Theme.ink)
        .screen()
    }

    private func board(_ g: JigsawGame) -> some View {
        VStack(spacing: 8) {
            HStack {
                Button("Menu") { dismiss() }.jewel(.onyx)
                Button("New puzzle") { phase = .menu }.jewel(.sapphire)
            }
            Text(JigsawLogic.pictures[g.picture]).font(.system(.title2, design: .serif, weight: .heavy))
                .accessibilityAddTraits(.isHeader)
            Text(prompt).font(.title3).multilineTextAlignment(.center)
                .accessibilityAddTraits(.updatesFrequently)
            GeometryReader { geo in play(g, in: geo.size) }
                .frame(minHeight: 360)
            Button("Hint: show where a piece goes", action: hint).jewel(.gold)
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)  // leave the board its room
        }
    }

    /// The frame on top and the tray of loose pieces below, laid out in one space so a dragged piece knows where it is.
    private func play(_ g: JigsawGame, in size: CGSize) -> some View {
        let n = g.size, image = JigsawPicture.image(g.picture)
        let side = min(size.width - 24, size.height * 0.56)  // 12 pt of wood each side
        let cell = side / CGFloat(n)
        let origin = CGPoint(x: (size.width - side) / 2, y: 12)
        func center(_ spot: Int) -> CGPoint { CGPoint(x: origin.x + (CGFloat(spot % n) + 0.5) * cell, y: origin.y + (CGFloat(spot / n) + 0.5) * cell) }
        let trayTop = side + 36
        let tray = Self.tray(count: g.loose.count, in: CGSize(width: size.width, height: size.height - trayTop))
        let full = cell * (1 + 2 * PieceShape.reach)  // a piece with room for its tabs
        let small = min(1, tray.slot * 0.95 / full)
        func trayCenter(_ k: Int) -> CGPoint {
            CGPoint(x: (size.width - CGFloat(tray.cols) * tray.slot) / 2 + (CGFloat(k % tray.cols) + 0.5) * tray.slot,
                    y: trayTop + (CGFloat(k / tray.cols) + 0.5) * tray.slot)
        }
        /// The spot under a point, or nil off the board.
        func spot(at p: CGPoint) -> Int? {
            let c = Int(floor((p.x - origin.x) / cell)), r = Int(floor((p.y - origin.y) / cell))
            return (0..<n).contains(c) && (0..<n).contains(r) ? r * n + c : nil
        }

        return ZStack(alignment: .topLeading) {
            Color.clear
            RoundedRectangle(cornerRadius: 10).fill(Theme.walnut)
                .frame(width: side + 24, height: side + 24)
                .position(x: size.width / 2, y: origin.y + side / 2)
            Image(uiImage: image).resizable()
                .frame(width: side, height: side)
                .opacity(g.level.guide)
                .background(Theme.ivory)
                .position(x: size.width / 2, y: origin.y + side / 2)
                .accessibilityHidden(true)
            // Every spot's outline, so the shapes help too.
            Canvas { ctx, _ in
                for i in 0..<n * n {
                    let rect = CGRect(x: CGFloat(i % n) * cell - cell * PieceShape.reach, y: CGFloat(i / n) * cell - cell * PieceShape.reach, width: full, height: full)
                    ctx.stroke(PieceShape(edges: g.edges(i)).path(in: rect), with: .color(Theme.walnut.opacity(0.45)), lineWidth: 1.5)
                }
            }
            .frame(width: side, height: side)
            .opacity(g.solved ? 0 : 1)  // a finished picture has no seams
            .position(x: size.width / 2, y: origin.y + side / 2)
            .accessibilityHidden(true)
            ForEach(0..<n * n, id: \.self) { i in
                if g.isPlaced(i) {
                    let at = center(i)
                    Piece(image: image, game: g, piece: i, cell: cell, seams: !g.solved)
                        .overlay(PieceShape(edges: g.edges(i)).stroke(Theme.gold, lineWidth: 4).opacity(glow == i ? 1 : 0))
                        .scaleEffect(glow == i ? 1.08 : 1)
                        .position(at)
                        .zIndex(glow == i ? 1 : 0)
                        .allowsHitTesting(false)
                        .transition(reduceMotion ? .identity : .asymmetric(
                            insertion: .modifier(active: Fly(offset: flight.from, scale: flight.scale, anchor: UnitPoint(x: at.x / size.width, y: at.y / size.height)), identity: Fly()),
                            removal: .identity))
                }
            }
            if let hinted {
                PieceShape(edges: g.edges(hinted))
                    .stroke(Theme.gold, style: StrokeStyle(lineWidth: 5))
                    .overlay(PieceShape(edges: g.edges(hinted)).stroke(Theme.ink, style: StrokeStyle(lineWidth: 2, dash: [6, 5])))  // not colour alone
                    .frame(width: full, height: full)
                    .phaseAnimator(reduceMotion ? [1.0] : [0.35, 1.0]) { outline, glow in outline.opacity(glow) }
                    .position(center(hinted))
                    .allowsHitTesting(false)
            }
            if let burst, !reduceMotion {
                Burst(count: 10, radius: cell * 0.9).id(burst.n)
                    .position(center(burst.spot))
                    .allowsHitTesting(false)
            }
            if g.solved, !reduceMotion {
                Shine(side: side)
                    .position(x: size.width / 2, y: origin.y + side / 2)
                    .allowsHitTesting(false)
                Burst(count: 40, radius: side * 0.75, size: 14)
                    .position(x: size.width / 2, y: origin.y + side / 2)
                    .allowsHitTesting(false)
            }
            // Tap targets for the spots, one per square.
            ForEach(0..<n * n, id: \.self) { i in
                Color.clear.contentShape(.rect)
                    .frame(width: cell, height: cell)
                    .position(center(i))
                    .onTapGesture {
                        // A tapped piece flies in from its place in the tray.
                        let from = held.flatMap { g.loose.firstIndex(of: $0) }.map(trayCenter) ?? center(i)
                        tapSpot(i, from: CGSize(width: from.x - center(i).x, height: from.y - center(i).y), scale: small)
                    }
                    .accessibilityElement()
                    .accessibilityLabel("Spot in row \(i / n + 1), column \(i % n + 1)")
                    .accessibilityValue(g.isPlaced(i) ? "filled" : "empty")
                    .accessibilityAddTraits(g.isPlaced(i) ? [] : .isButton)
            }
            ForEach(Array(g.loose.enumerated()), id: \.element) { k, p in
                let isHeld = held == p
                Piece(image: image, game: g, piece: p, cell: cell)
                    .scaleEffect(isHeld ? small * 1.18 : small)  // lifted off the tray
                    .shadow(color: Theme.ink.opacity(isHeld ? 0.35 : 0), radius: 5, y: 4)
                    .modifier(Shake(count: CGFloat(shakes[p] ?? 0)))
                    .frame(width: tray.slot, height: tray.slot)
                    .background { if isHeld { Circle().fill(Theme.gold.opacity(0.7)) } }
                    .overlay { if isHeld { Circle().strokeBorder(Theme.ink, lineWidth: 3) } }  // outline too, not colour alone
                    .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.55), value: isHeld)
                    .opacity(dragging?.piece == p ? 0 : 1)
                    .contentShape(.rect)
                    .position(trayCenter(k))
                    .onTapGesture { pickUp(p) }
                    .gesture(DragGesture(minimumDistance: 8, coordinateSpace: .named("play"))
                        .onChanged { v in dragging = (p, v.location) }
                        .onEnded { v in
                            dragging = nil
                            if let s = spot(at: v.location) {
                                tryPlace(p, at: s, from: CGSize(width: v.location.x - center(s).x, height: v.location.y - center(s).y), scale: 1)
                            }
                        })
                    .accessibilityElement()
                    .accessibilityLabel("Piece from row \(p / n + 1), column \(p % n + 1)")
                    .accessibilityValue(isHeld ? "picked up" : "")
                    .accessibilityAddTraits(.isButton)
            }
            if let dragging {
                Piece(image: image, game: g, piece: dragging.piece, cell: cell)
                    .shadow(color: Theme.ink.opacity(0.4), radius: 6, y: 4)
                    .position(dragging.at)
                    .allowsHitTesting(false)
            }
        }
        .frame(width: size.width, height: size.height)
        .coordinateSpace(.named("play"))
    }

    private var won: some View {
        VStack(spacing: 20) {
            Heading(text: "Well done!")
            ScrollView {
                VStack(spacing: 16) {
                    StarCelebration(stars: earned)
                    Text("You finished the \(wonLevel.lowercased()) puzzle and earned \(earned) ★ for your village.").font(.title3)
                    VillageView(stage: village.stage, crop: true).frame(height: 300).clipShape(.rect(cornerRadius: 14))
                    if let unlocked { Text("Your village grew: \(unlocked.name.lowercased())!").font(.title3.bold()) }
                }
                .padding(8)
            }
            Button("New puzzle") { Ads.shared.showBetweenGames(); phase = .menu }.jewel(.gold)
            Button("Menu") { Ads.shared.showBetweenGames(); dismiss() }.jewel(.onyx)
        }
    }

    /// Columns and slot size that fit this many pieces in the tray as big as they can be.
    private static func tray(count: Int, in size: CGSize) -> (cols: Int, slot: CGFloat) {
        (1...max(count, 1)).map { cols in (cols, min(size.width / CGFloat(cols), size.height / CGFloat((count + cols - 1) / cols))) }
            .max { $0.1 < $1.1 }!
    }

    private func start(_ level: JigsawLogic.Level) {
        game = JigsawLogic.generate(level, picture: picture, seed: .random(in: 0...UInt64.max))
        held = nil
        hinted = nil
        prompt = Self.firstPrompt
        glow = nil
        burst = nil
        streak = 0
        shakes = [:]
        afterMove()
        phase = .board
    }

    /// Tapping a piece picks it up; tapping it again puts it down.
    private func pickUp(_ p: Int) {
        held = held == p ? nil : p
        hinted = nil
        prompt = held == nil ? Self.firstPrompt : "Now tap the spot where it goes."
    }

    private func tapSpot(_ s: Int, from: CGSize, scale: CGFloat) {
        guard let p = held else {
            prompt = game?.isPlaced(s) == true ? Self.firstPrompt : "First pick up a piece from the tray below."
            return
        }
        tryPlace(p, at: s, from: from, scale: scale)
    }

    /// Places the piece if the spot is its own, flying it in from `from` (its offset from the spot) at `scale`.
    /// Otherwise it shakes and stays in the tray, still picked up.
    private func tryPlace(_ p: Int, at s: Int, from: CGSize, scale: CGFloat) {
        guard var g = game else { return }
        guard g.place(p, at: s) else {
            misses += 1
            Sound.miss.play()
            streak = 0
            withAnimation(reduceMotion ? nil : .linear(duration: 0.4)) { shakes[p, default: 0] += 1 }
            held = p
            prompt = "Not that spot. Look at its edges and the picture, and try another."
            return
        }
        streak += 1
        Sound.tap.play()
        flight = (from, scale)
        withAnimation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.62)) {
            game = g
            held = nil
            hinted = nil
        }
        prompt = cheer(g, placed: p)
        Task {  // glow and burst as it lands
            try? await Task.sleep(for: .seconds(reduceMotion ? 0 : 0.3))
            burst = (s, (burst?.n ?? 0) + 1)
            withAnimation(.easeOut(duration: 0.2)) { glow = p }
            try? await Task.sleep(for: .seconds(0.8))
            withAnimation(.easeIn(duration: 0.3)) { if glow == p { glow = nil } }
        }
        afterMove()
    }

    /// What to say when a piece goes in: milestones first, then a run of good tries, else a varied cheer.
    private func cheer(_ g: JigsawGame, placed p: Int) -> String {
        let border = (0..<g.level.pieces).filter { g.edges($0).contains(0) }
        if g.solved { return "You did it!" }
        if border.contains(p), border.allSatisfy(g.isPlaced) { return "The border is done! Now fill in the middle." }
        if g.loose.count == g.level.pieces / 2 { return "Halfway there!" }
        if streak >= 3 { return "\(streak) in a row! Keep going." }
        return Self.cheers.randomElement()! + " Pick up another piece."
    }

    /// Picks up a piece (the one held, or the first in the tray) and lights up its spot.
    private func hint() {
        guard let g = game, let p = held ?? g.loose.first else { return }
        held = p
        hinted = p
        prompt = "This piece goes in the glowing spot. Tap it there."
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
            Task {  // let the finished picture shine before the win screen
                try? await Task.sleep(for: .seconds(reduceMotion ? 0.8 : 2.6))
                game = nil
                phase = .won
            }
        } else {
            Save.store(Self.id, g)
        }
    }
}

/// One piece: its part of the picture, cut to its shape, with room around it for its tabs.
private struct Piece: View {
    let image: UIImage
    let game: JigsawGame
    let piece: Int
    let cell: CGFloat
    /// Whether its outline shows; a finished picture drops them.
    var seams = true

    var body: some View {
        let n = game.size, reach = cell * PieceShape.reach
        let shape = PieceShape(edges: game.edges(piece))
        Image(uiImage: image).resizable()
            .frame(width: cell * CGFloat(n), height: cell * CGFloat(n))
            .offset(x: reach - CGFloat(piece % n) * cell, y: reach - CGFloat(piece / n) * cell)
            .frame(width: cell + 2 * reach, height: cell + 2 * reach, alignment: .topLeading)
            .clipShape(shape)
            .overlay(shape.stroke(Theme.ink.opacity(seams ? 0.6 : 0), lineWidth: 1.5))
    }
}

/// A placed piece on its way in: shifted and shrunk towards where it came from, growing about its own spot.
private struct Fly: ViewModifier {
    var offset = CGSize.zero
    var scale: CGFloat = 1
    var anchor = UnitPoint.center

    func body(content: Content) -> some View { content.scaleEffect(scale, anchor: anchor).offset(offset) }
}

/// Blossom petals and gold flecks bursting out from a point and fading.
private struct Burst: View {
    let count: Int
    let radius: CGFloat
    var size: CGFloat = 10
    @State private var out = false

    private static let colors: [Color] = [Color(hex: 0xF4B6C2), Theme.gold, Color(hex: 0xEFA3B5), Theme.ivory]

    var body: some View {
        ZStack {
            ForEach(0..<count, id: \.self) { k in
                let a = Double(k) / Double(count) * 2 * .pi + Double(k % 3) * 0.2
                let reach = radius * (0.55 + 0.45 * Double(k % 4) / 3)
                Ellipse().fill(Self.colors[k % Self.colors.count])
                    .overlay(Ellipse().stroke(Theme.walnut.opacity(0.4), lineWidth: 0.5))
                    .frame(width: size, height: size * 0.6)
                    .rotationEffect(.radians(out ? a + 2 : a))
                    .offset(x: out ? cos(a) * reach : 0, y: out ? sin(a) * reach + radius * 0.25 : 0)  // drifts down a little as it goes
                    .scaleEffect(out ? 0.5 : 1)
                    .opacity(out ? 0 : 1)
            }
        }
        .onAppear { withAnimation(.easeOut(duration: 1.1)) { out = true } }
        .accessibilityHidden(true)
    }
}

/// A band of light sweeping once across the finished picture.
private struct Shine: View {
    let side: CGFloat
    @State private var across = false

    var body: some View {
        Color.clear
            .frame(width: side, height: side)
            .overlay {
                LinearGradient(colors: [.clear, .white.opacity(0.65), .clear], startPoint: .leading, endPoint: .trailing)
                    .frame(width: side * 0.4, height: side * 2)
                    .rotationEffect(.degrees(25))
                    .offset(x: across ? side : -side)
            }
            .clipped()
            .onAppear { withAnimation(.easeInOut(duration: 1.2).delay(0.35)) { across = true } }
            .accessibilityHidden(true)
    }
}

/// A jigsaw outline: a square with a tab, hole or straight line on each side (JigsawGame.edges), drawn inside a frame
/// `reach` of a square bigger on every side so tabs fit.
nonisolated struct PieceShape: Shape {
    static let reach: CGFloat = 0.3
    let edges: [Int]

    func path(in rect: CGRect) -> Path {
        let cell = rect.width / (1 + 2 * Self.reach), m = cell * Self.reach
        let corners = [CGPoint(x: m, y: m), CGPoint(x: m + cell, y: m), CGPoint(x: m + cell, y: m + cell), CGPoint(x: m, y: m + cell)]
            .map { CGPoint(x: $0.x + rect.minX, y: $0.y + rect.minY) }
        var p = Path()
        p.move(to: corners[0])
        for k in 0..<4 {
            let a = corners[k], b = corners[(k + 1) % 4]
            let dx = b.x - a.x, dy = b.y - a.y, s = CGFloat(edges[k])
            // u runs along the side, v outwards from the piece (clockwise, so outwards is (dy, -dx)).
            func pt(_ u: CGFloat, _ v: CGFloat) -> CGPoint { CGPoint(x: a.x + dx * u + dy * v * s, y: a.y + dy * u - dx * v * s) }
            if s != 0 {
                p.addLine(to: pt(0.37, 0))
                p.addCurve(to: pt(0.34, 0.15), control1: pt(0.42, 0.05), control2: pt(0.30, 0.10))
                p.addCurve(to: pt(0.66, 0.15), control1: pt(0.36, 0.32), control2: pt(0.64, 0.32))
                p.addCurve(to: pt(0.63, 0), control1: pt(0.70, 0.10), control2: pt(0.58, 0.05))
            }
            p.addLine(to: b)
        }
        p.closeSubpath()
        return p
    }
}
