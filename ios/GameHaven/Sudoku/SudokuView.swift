import SwiftUI

/// Sudoku: tap a square, then pick its number from the tray that opens beside it. No timer; unlimited undo and hints; saves after every move.
struct SudokuView: View {
    static let id = "sudoku"

    private enum Phase { case menu, board, won }

    @State private var game = Save.load(Self.id, as: SudokuGame.self)
    @State private var phase: Phase = Save.load(Self.id, as: SudokuGame.self) == nil ? .menu : .board
    /// The square last tapped; its row, column, box and matching numbers are shaded.
    @State private var selected: Int?
    /// Whether the number tray is open beside the selected square.
    @State private var picking = false
    /// Whether the how-to-play popup is open.
    @State private var rules = false
    /// Squares of a row, column or box just finished, glowing for a moment.
    @State private var glow: Set<Int> = []
    /// Per square, how many wrong numbers went in; each one shakes it.
    @State private var shakes = [Int](repeating: 0, count: 81)
    /// Per square, how many right numbers went in; each one stamps it down with a gold ripple.
    @State private var stamps = [Int](repeating: 0, count: 81)
    @State private var stamped: Int?
    /// On a solve, how many diagonals of the board the gold sweep has lit before the win screen.
    @State private var finale: Int?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.highContrast) private var highContrast
    @State private var wonLevel = ""
    @State private var earned = 0
    @State private var perfect = false
    @State private var unlocked: Village.Stage?
    @Environment(\.dismiss) private var dismiss
    @Environment(Village.self) private var village

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
        .sensoryFeedback(.selection, trigger: selected)
        .sensoryFeedback(.impact(weight: .light), trigger: stamps)
        .sensoryFeedback(.error, trigger: shakes) { (old: [Int], new: [Int]) in new.reduce(0, +) > old.reduce(0, +) }
    }

    /// The parlour entrance: a lit marquee, today's puzzle, the levels with the stars each pays, and the rules in a popup until asked for.
    private var menu: some View {
        let today = SudokuDaily.key(.now)
        let done = SudokuDaily.done
        return ScrollView {
            VStack(spacing: 20) {
                marquee
                Button { rules = true } label: { Label("How to play", systemImage: "questionmark.circle") }.jewel(.amethyst)
                if done.contains(today) {
                    Text("You've solved today's puzzle. A new one comes tomorrow.").font(.title3.bold())
                } else {
                    Button("Today's puzzle") { start(SudokuDaily.level, daily: today) }.jewel(.gold)
                }
                WeekOfDailies(done: done)
                ForEach(Array(zip(SudokuLogic.Level.allCases, [Jewel.jade, .amber, .ruby])), id: \.0) { level, jewel in
                    let stars = SudokuLogic.Level.allCases.firstIndex(of: level)! + 1  // what a solve pays, as in SudokuGame.stars
                    Button { start(level) } label: {
                        VStack(spacing: 2) {
                            Text(level.rawValue)
                            Text(String(repeating: "★", count: stars)).font(.body).accessibilityLabel("\(stars) \(stars == 1 ? "star" : "stars")")
                        }
                    }
                    .jewel(jewel)
                    .overlay {  // gold rim so red stands off the red wall
                        if jewel == .ruby && !highContrast { RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.gold, lineWidth: 3).allowsHitTesting(false) }
                    }
                }
                Button("Back") { game == nil ? dismiss() : (phase = .board) }.jewel(.onyx)
            }
        }
        .foregroundStyle(highContrast ? .black : Theme.ivory)
        .background { if !highContrast { ParlourBackdrop().padding(-40).ignoresSafeArea() } }
        .sheet(isPresented: $rules) { howToPlay }
    }

    private var howToPlay: some View {
        VStack(spacing: 20) {
            Heading(text: "How to play")
            ScrollView {
                Text("Fill every row, column and 3×3 box with the numbers 1 to 9, each used once.\n\nTap a square and a tray of numbers opens beside it. Tap the number that goes there. Tap the same number again to take it back. A wrong number turns red and is underlined. Finish a row, column or box and it lights up.\n\nThere is no timer. Take your time. Solve a puzzle with no wrong numbers for a bonus star.")
                    .font(.title3)
            }
            Button("Got it") { rules = false }.jewel(.gold)
        }
        .foregroundStyle(highContrast ? .black : Theme.ink)
        .screen()
    }

    /// The title in lights: 数独 between lanterns inside the chasing-bulb frame, like the board.
    private var marquee: some View {
        VStack(spacing: 4) {
            HStack(spacing: 16) {
                Lantern()
                Text("数独").font(.system(size: 56, weight: .heavy, design: .serif)).foregroundStyle(Theme.gold)
                    .shadow(color: Jewel.ruby.fill, radius: 0, x: 2, y: 2)
                Lantern()
            }
            Text("SUDOKU").font(.system(.title, design: .serif, weight: .bold)).foregroundStyle(Theme.ivory)
        }
        .dynamicTypeSize(...DynamicTypeSize.xxLarge)
        .padding(.vertical, 28)
        .frame(maxWidth: .infinity)
        .background { MarqueeFrame(flash: false) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Sudoku")
        .accessibilityAddTraits(.isHeader)
    }

    private func board(_ g: SudokuGame) -> some View {
        VStack(spacing: 8) {
            HStack {
                Button("Menu") { dismiss() }.jewel(.onyx)
                Button("New puzzle") { phase = .menu }.jewel(.sapphire)
            }
            sign(g)
            SudokuBoard(game: g, selected: selected, picking: picking, glow: glow, shakes: shakes, stamps: stamps, stamped: stamped, finale: finale, tap: tap, pick: pick)
                .zIndex(1)  // the tray may hang over the buttons below
            // Controls stop growing past this size: beyond it they'd squeeze the board, whose digits already scale with it.
            HStack(spacing: 8) {
                control("Undo", "last move", .amethyst, action: undo)
                control("Hint", "show one", .gold, action: hint)
            }
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        }
        .allowsHitTesting(finale == nil)  // the solve is already paid out
        // Negative padding stretches the parlour wall past the screen padding to the edges.
        .background { if !highContrast { ParlourBackdrop().padding(-40).ignoresSafeArea() } }
    }

    /// The lantern-lit sign over the board, naming the puzzle like a parlour machine's marquee.
    private func sign(_ g: SudokuGame) -> some View {
        let level = g.daily == nil ? g.level.rawValue : "Daily"
        return HStack(spacing: 12) {
            Lantern()
            Text("数独").foregroundStyle(Theme.gold) + Text("  \(level)").foregroundStyle(Theme.ivory)
            Lantern()
        }
        .font(.system(.title2, design: .serif, weight: .heavy))
        .padding(.horizontal, 18)
        .padding(.vertical, 4)
        .background(Jewel.ruby.fill, in: .capsule)
        .overlay(Capsule().strokeBorder(Theme.gold, lineWidth: 2))
        .dynamicTypeSize(...DynamicTypeSize.xxLarge)  // leave the board its room
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Sudoku, \(level)")
    }

    /// A bottom-row button: a word, with a few smaller words saying what it does or its state.
    private func control(_ title: String, _ detail: String, _ jewel: Jewel, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 0) {
                Text(title).font(.title3.bold())
                Text(detail).font(.footnote)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.75)
        }
        .jewel(jewel)
    }

    private var won: some View {
        VStack(spacing: 20) {
            Heading(text: "Well done!")
            ScrollView {
                VStack(spacing: 16) {
                    StarCelebration(stars: earned)
                    Text("You solved the \(wonLevel.lowercased()) puzzle and earned \(earned) ★ for your village.").font(.title3)
                    if perfect { Text("No wrong numbers: 1 bonus ★ included.").font(.title3.bold()) }
                    VillageView(stage: village.stage, crop: true).frame(height: 300).clipShape(.rect(cornerRadius: 14))
                    if let unlocked { Text("Your village grew: \(unlocked.name.lowercased())!").font(.title3.bold()) }
                }
                .padding(8)
            }
            Button("New puzzle") { Ads.shared.showBetweenGames(); phase = .menu }.jewel(.gold)
            Button("Menu") { Ads.shared.showBetweenGames(); dismiss() }.jewel(.onyx)
        }
        .overlay { if !reduceMotion { CoinShower().padding(-40).ignoresSafeArea() } }
    }

    private func start(_ level: SudokuLogic.Level, daily: String? = nil) {
        let g = SudokuLogic.generate(level, seed: daily.map(SudokuDaily.seed) ?? .random(in: 0...UInt64.max))
        game = SudokuGame(puzzle: g.puzzle, solution: g.solution, board: g.puzzle, level: level, daily: daily)
        selected = nil
        picking = false
        glow = []
        shakes = .init(repeating: 0, count: 81)
        stamps = .init(repeating: 0, count: 81)
        stamped = nil
        finale = nil
        afterMove()
        phase = .board
    }

    /// Selects a square and opens the tray if the player can fill it. Tapping the open square again closes the tray.
    private func tap(_ i: Int) {
        guard let g = game else { return }
        withAnimation(reduceMotion ? nil : .spring(duration: 0.3, bounce: 0.35)) {
            picking = !(selected == i && picking) && g.puzzle[i] == 0
            selected = i
        }
    }

    /// Puts the number in the selected square, or takes it back if it's already there.
    private func pick(_ d: Int) {
        guard let g = game, let i = selected else { return }
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.15)) { picking = false }
        place(g.board[i] == d ? 0 : d, at: i)
    }

    private func place(_ d: Int, at i: Int) {
        guard var g = game else { return }
        g.place(d, at: i)
        game = g
        if d != 0, g.board[i] != g.solution[i] {
            Sound.miss.play()
            withAnimation(reduceMotion ? nil : .linear(duration: 0.4)) { shakes[i] += 1 }
        } else if d != 0 {
            Sound.tap.play()
            stamped = i
            stamps[i] += 1
            // A finished row, column or box lights up, and so does every square of a digit once all nine are in.
            let done = g.left(d) == 0 ? Set((0..<81).filter { g.board[$0] == d }) : []
            withAnimation(.easeOut(duration: 0.2)) { glow = g.finishedUnits(at: i).union(done) }
            if !glow.isEmpty { Task { try? await Task.sleep(for: .seconds(0.7)); withAnimation(.easeIn(duration: 0.4)) { glow = [] } } }
        }
        afterMove()
    }

    private func undo() {
        guard var g = game, g.undo() != nil else { return }
        game = g
        picking = false
        afterMove()
    }

    /// Fixes the selected square if it's empty or wrong, otherwise the first square that is.
    private func hint() {
        guard let g = game else { return }
        let open = (0..<81).filter { g.board[$0] != g.solution[$0] }
        guard let i = open.first(where: { $0 == selected }) ?? open.first else { return }
        selected = i
        picking = false
        place(g.solution[i], at: i)
    }

    private func afterMove() {
        guard let g = game else { return }
        if g.solved {
            Save.clear(Self.id)
            Sound.win.play()
            if let day = g.daily { SudokuDaily.done.insert(day) }
            wonLevel = g.daily == nil ? g.level.rawValue : "daily"
            earned = g.stars
            perfect = (g.mistakes ?? 0) == 0
            unlocked = village.earn(earned)
            Ads.shared.gameFinished()
            Task {
                if !reduceMotion {
                    for k in 0...16 {  // light the board corner to corner, one diagonal at a time
                        withAnimation(.easeOut(duration: 0.2)) { finale = k }
                        try? await Task.sleep(for: .seconds(0.06))
                    }
                    try? await Task.sleep(for: .seconds(1.2))
                }
                game = nil
                finale = nil
                phase = .won
            }
        } else {
            Save.store(Self.id, g)
        }
    }
}

/// The last seven days, ticked when that day's puzzle was solved. No streak to lose: missed days are just blank.
private struct WeekOfDailies: View {
    let done: Set<String>

    var body: some View {
        let days = (0..<7).reversed().map { Calendar.current.date(byAdding: .day, value: -$0, to: .now)! }
        HStack(spacing: 6) {
            ForEach(days, id: \.self) { day in
                let solved = done.contains(SudokuDaily.key(day))
                VStack(spacing: 2) {
                    Text(day.formatted(.dateTime.weekday(.abbreviated))).font(.footnote)
                    Image(systemName: solved ? "checkmark.circle.fill" : "circle").font(.title2)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(day.formatted(.dateTime.weekday(.wide))): \(solved ? "solved" : "not played")")
            }
        }
        .dynamicTypeSize(...DynamicTypeSize.xxLarge)  // seven columns can't grow further
    }
}

/// The 9×9 grid: dark ink on ivory paper, the highest-contrast surface, so high contrast mode needs no change.
private struct SudokuBoard: View {
    let game: SudokuGame
    let selected: Int?
    let picking: Bool
    let glow: Set<Int>
    let shakes: [Int]
    let stamps: [Int]
    let stamped: Int?
    let finale: Int?
    let tap: (Int) -> Void
    let pick: (Int) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let playerInk = Color(hex: 0x1F3A93)
    private static let wrong = Color(hex: 0xB00020)
    private static let sameDigit = Color(hex: 0xECD07A)
    private static let peer = Color(hex: 0xF3E3C3)

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height) - 32  // room for the marquee frame
            let cell = side / 9
            ZStack(alignment: .topLeading) {
                VStack(spacing: 0) {
                    ForEach(0..<9, id: \.self) { row in
                        HStack(spacing: 0) {
                            ForEach(0..<9, id: \.self) { col in
                                square(row * 9 + col, size: cell)
                            }
                        }
                    }
                }
                .background(Theme.ivory)
                .overlay { lines(cell: cell) }
                if !glow.isEmpty && !reduceMotion {
                    let n = CGFloat(glow.count)  // burst from the middle of the finished squares
                    WinBurst(size: side)
                        .position(x: (glow.reduce(0) { $0 + CGFloat($1 % 9) } / n + 0.5) * cell,
                                  y: (glow.reduce(0) { $0 + CGFloat($1 / 9) } / n + 0.5) * cell)
                        .id(glow)  // a new finish starts a fresh burst
                }
                if let s = stamped, !reduceMotion {
                    Ripple(size: cell)
                        .position(x: (CGFloat(s % 9) + 0.5) * cell, y: (CGFloat(s / 9) + 0.5) * cell)
                        .id(stamps.reduce(0, +))  // each right number sends a fresh ripple
                }
                if finale == 16 && !reduceMotion {
                    WinBurst(size: side * 1.6).position(x: side / 2, y: side / 2)
                }
                if picking, let s = selected {
                    let pebble = max(52, cell * 1.15)  // never below a comfortable finger size
                    let tray = pebble * 3 + 32
                    NumberTray(game: game, square: s, pebble: pebble, pick: pick)
                        .position(trayCenter(s, cell: cell, side: side, tray: tray))
                        .transition(.scale(scale: 0.5).combined(with: .opacity))
                }
            }
            .frame(width: side, height: side)
            .padding(16)
            .background { MarqueeFrame(flash: !glow.isEmpty || finale != nil) }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minHeight: 280)
    }

    /// Beside the square, on whichever side has more room, so the square itself stays in view.
    private func trayCenter(_ s: Int, cell: CGFloat, side: CGFloat, tray: CGFloat) -> CGPoint {
        let row = CGFloat(s / 9), col = CGFloat(s % 9)
        let x = min(max((col + 0.5) * cell, tray / 2), side - tray / 2)
        let y = row < 4.5 ? (row + 1) * cell + 6 + tray / 2 : row * cell - 6 - tray / 2
        return CGPoint(x: x, y: y)
    }

    private func square(_ i: Int, size: CGFloat) -> some View {
        let d = game.board[i]
        let isWrong = d != 0 && d != game.solution[i]
        let given = game.puzzle[i] != 0
        let chosen = selected == i
        let same = d != 0 && d == selected.map { game.board[$0] }
        let lit = finale.map { i / 9 + i % 9 <= $0 } ?? false
        let peer = selected.map { s in s / 9 == i / 9 || s % 9 == i % 9 || (s / 27 == i / 27 && s % 9 / 3 == i % 9 / 3) } ?? false
        return Button { tap(i) } label: {
            Text(d == 0 ? " " : "\(d)")
                .font(.system(size: size * 0.65, weight: given ? .bold : .regular))
                .foregroundStyle(given ? Theme.ink : isWrong ? Self.wrong : Self.playerInk)
                .underline(isWrong, color: Self.wrong)  // so mistakes don't rely on colour alone
                .scaleEffect(glow.contains(i) || lit ? 1.2 : 1)
                .keyframeAnimator(initialValue: 1.0, trigger: reduceMotion ? 0 : stamps[i]) { v, scale in v.scaleEffect(scale) } keyframes: { _ in
                    LinearKeyframe(1.8, duration: 0.06)  // lifted, then stamped down
                    SpringKeyframe(1, duration: 0.45, spring: .bouncy)
                }
                .modifier(Shake(count: CGFloat(shakes[i])))
                .frame(width: size, height: size)
                .background(glow.contains(i) || chosen || lit ? Theme.gold : same ? Self.sameDigit : peer ? Self.peer : .clear)
                .overlay {  // outline as well as fill, again not colour alone
                    if chosen || same { Rectangle().strokeBorder(chosen ? Theme.ink : Self.playerInk, lineWidth: 3) }
                }
        }
        .buttonStyle(Squish())
        .dynamicTypeSize(.large)  // digits scale with the board, not the text setting
        .accessibilityLabel("Row \(i / 9 + 1), column \(i % 9 + 1)")
        .accessibilityValue(d != 0 ? "\(d)\(given ? ", given" : isWrong ? ", wrong" : "")" : "empty")
    }

    private func lines(cell: CGFloat) -> some View {
        Canvas { ctx, size in
            for k in 0...9 {
                let x = CGFloat(k) * cell
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                path.move(to: CGPoint(x: 0, y: x))
                path.addLine(to: CGPoint(x: size.width, y: x))
                ctx.stroke(path, with: .color(Theme.ink), lineWidth: k % 3 == 0 ? 4 : 1)
            }
        }
        .allowsHitTesting(false)
    }
}

/// Nine round pebbles laid out like a 3×3 box. The square's current number is gold; tapping it takes it back.
private struct NumberTray: View {
    let game: SudokuGame
    let square: Int
    let pebble: CGFloat
    let pick: (Int) -> Void

    var body: some View {
        Grid(horizontalSpacing: 6, verticalSpacing: 6) {
            ForEach(0..<3, id: \.self) { r in
                GridRow {
                    ForEach(1...3, id: \.self) { c in
                        stone(r * 3 + c)
                    }
                }
            }
        }
        .padding(10)
        .background(Jewel.ruby.fill, in: .rect(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(Theme.gold, lineWidth: 3))
        .shadow(color: .black.opacity(0.5), radius: 10, y: 6)
        .dynamicTypeSize(.large)  // numbers scale with the pebbles
    }

    private func stone(_ d: Int) -> some View {
        let current = game.board[square] == d
        let left = game.left(d)
        let used = left == 0 && !current
        let fill = current
            ? AnyShapeStyle(Theme.gold)
            : AnyShapeStyle(RadialGradient(colors: [.white, Theme.ivory, Theme.paperEdge], center: UnitPoint(x: 0.35, y: 0.3), startRadius: 0, endRadius: pebble * 0.75))
        return Button { pick(d) } label: {
            Text("\(d)")
                .font(.system(size: pebble * 0.5, weight: .bold, design: .serif))
                .foregroundStyle(Theme.ink)
                .frame(width: pebble, height: pebble)
                .background(Circle().fill(fill))
                .overlay(Circle().strokeBorder(Theme.walnut, lineWidth: current ? 3 : 2))
                .shadow(color: Theme.walnut.opacity(0.35), radius: 1, y: 2)
        }
        .buttonStyle(Squish())
        .disabled(used)
        .opacity(used ? 0.35 : 1)
        .accessibilityLabel(current ? "Take back \(d)" : used ? "\(d), all placed" : "\(d), \(left) left")
    }
}

/// Presses in under the finger, so a tap feels like pushing a real button.
private struct Squish: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.88 : 1)
            .animation(.spring(duration: 0.2, bounce: 0.5), value: configuration.isPressed)
    }
}

/// A gold ring spreading out from a square that just took the right number.
private struct Ripple: View {
    let size: CGFloat
    @State private var out = false

    var body: some View {
        Circle()
            .strokeBorder(Theme.gold, lineWidth: 5)
            .frame(width: size, height: size)
            .scaleEffect(out ? 2.2 : 0.6)
            .opacity(out ? 0 : 1)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .onAppear { withAnimation(.easeOut(duration: 0.5)) { out = true } }
    }
}

/// Gold coins tumbling down the win screen for a few seconds, like a jackpot paying out.
private struct CoinShower: View {
    @State private var start = Date.now
    @State private var over = false

    var body: some View {
        TimelineView(.animation(paused: over)) { t in
            let age = t.date.timeIntervalSince(start)
            Canvas { ctx, size in
                for k in 0..<48 {
                    let x = (sin(Double(k) * 12.9898) * 0.5 + 0.5) * size.width  // scattered, but the same every time
                    let y = (age - Double(k % 12) * 0.2) * (380 + Double(k % 7) * 50) - 30
                    guard y > -30, y < size.height + 30 else { continue }
                    let w = 26 * max(0.15, abs(cos(age * 5 + Double(k))))  // flipping edge-on as it falls
                    let coin = CGRect(x: x - w / 2, y: y - 13, width: w, height: 26)
                    ctx.fill(Path(ellipseIn: coin), with: .color(Theme.gold))
                    ctx.stroke(Path(ellipseIn: coin.insetBy(dx: w * 0.2, dy: 5)), with: .color(Theme.walnut.opacity(0.6)), lineWidth: 1.5)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .task { try? await Task.sleep(for: .seconds(5)); over = true }
    }
}

/// Wiggles side to side three times each time count goes up by one. Shared with Word Search.
struct Shake: GeometryEffect {
    var count: CGFloat
    var animatableData: CGFloat {
        get { count }
        set { count = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: size.width * 0.12 * sin(count * .pi * 6), y: 0))
    }
}

/// The stars just earned, with hot-spring steam drifting up behind them. Still when Reduce Motion is on. Shared by every game's win screen.
struct StarCelebration: View {
    let stars: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var rising = false

    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { k in
                Capsule()
                    .fill(Theme.ivory.opacity(0.9))
                    .frame(width: 10, height: 44)
                    .blur(radius: 4)
                    .offset(x: CGFloat(k - 1) * 46, y: rising ? -46 : 6)
                    .opacity(rising ? 0 : 0.9)
                    .animation(reduceMotion ? nil : .easeOut(duration: 2.6).repeatForever(autoreverses: false).delay(Double(k) * 0.8), value: rising)
            }
            HStack(spacing: 8) {
                ForEach(0..<stars, id: \.self) { k in
                    Image(systemName: "star.fill").font(.system(size: 48)).foregroundStyle(Theme.gold)
                        .shadow(color: Theme.walnut.opacity(0.5), radius: 0, y: 2)
                        .scaleEffect(rising || reduceMotion ? 1 : 0.01)
                        .rotationEffect(.degrees(rising || reduceMotion ? 0 : -120))
                        .animation(reduceMotion ? nil : .spring(duration: 0.5, bounce: 0.55).delay(0.2 + Double(k) * 0.3), value: rising)
                }
            }
        }
        .frame(height: 90)
        .accessibilityElement()
        .accessibilityLabel("\(stars) \(stars == 1 ? "star" : "stars") earned")
        .onAppear { rising = true }
    }
}

/// Black-lacquer frame with gold trim and a ring of marquee bulbs that chase round. All bulbs blaze when a row, column or box is finished.
private struct MarqueeFrame: View {
    let flash: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.35)) { t in
            let tick = reduceMotion ? 0 : Int(t.date.timeIntervalSinceReferenceDate / 0.35)
            Canvas { ctx, size in
                let rect = CGRect(origin: .zero, size: size)
                ctx.fill(Path(roundedRect: rect, cornerRadius: 10), with: .color(Color(hex: 0x1A0B08)))
                ctx.stroke(Path(roundedRect: rect.insetBy(dx: 1.5, dy: 1.5), cornerRadius: 9), with: .color(Theme.gold), lineWidth: 3)
                ctx.stroke(Path(roundedRect: rect.insetBy(dx: 14, dy: 14), cornerRadius: 2), with: .color(Theme.gold), lineWidth: 2)
                let band = rect.insetBy(dx: 8, dy: 8)
                let n = max(8, Int(band.width / 20))  // bulbs per side
                for k in 0..<n * 4 {
                    let f = CGFloat(k % n) / CGFloat(n)
                    let p = switch k / n {  // clockwise from the top-left corner
                    case 0: CGPoint(x: band.minX + f * band.width, y: band.minY)
                    case 1: CGPoint(x: band.maxX, y: band.minY + f * band.height)
                    case 2: CGPoint(x: band.maxX - f * band.width, y: band.maxY)
                    default: CGPoint(x: band.minX, y: band.maxY - f * band.height)
                    }
                    let lit = flash || (k + tick) % 3 == 0
                    if lit { ctx.fill(Path(ellipseIn: CGRect(x: p.x - 6, y: p.y - 6, width: 12, height: 12)), with: .color(Theme.gold.opacity(0.45))) }
                    ctx.fill(Path(ellipseIn: CGRect(x: p.x - 3, y: p.y - 3, width: 6, height: 6)), with: .color(lit ? Theme.ivory : Theme.gold.opacity(0.4)))
                }
            }
        }
        .accessibilityHidden(true)
    }
}

/// Red lacquer wall with a faint gold seigaiha wave pattern and a warm glow in the middle, like a pachinko parlour.
private struct ParlourBackdrop: View {
    private static let deep = Color(hex: 0x4A0F0F)

    var body: some View {
        Canvas { ctx, size in
            let r: CGFloat = 26
            // Each row overlaps the one above, so fanning top to bottom leaves the scale shapes.
            for (row, y) in stride(from: -r, through: size.height + r, by: r / 2).enumerated() {
                for x in stride(from: -r + (row % 2 == 0 ? 0 : r), through: size.width + r, by: r * 2) {
                    for ring in 0..<4 {
                        let rr = r * (1 - CGFloat(ring) * 0.25)
                        let circle = Path(ellipseIn: CGRect(x: x - rr, y: y - rr, width: rr * 2, height: rr * 2))
                        if ring == 0 { ctx.fill(circle, with: .color(Self.deep)) }
                        ctx.stroke(circle, with: .color(Theme.gold.opacity(0.14)), lineWidth: 1.5)
                    }
                }
            }
        }
        .overlay(RadialGradient(colors: [Jewel.ruby.fill.opacity(0.6), .clear], center: .center, startRadius: 0, endRadius: 500))
        .background(Self.deep)
        .accessibilityHidden(true)
    }
}

/// A small red paper lantern with gold caps.
private struct Lantern: View {
    var body: some View {
        VStack(spacing: 0) {
            Capsule().fill(Theme.gold).frame(width: 10, height: 4)
            Ellipse().fill(Color(hex: 0xE0442C)).frame(width: 18, height: 24)
                .shadow(color: Theme.gold.opacity(0.8), radius: 5)
            Capsule().fill(Theme.gold).frame(width: 10, height: 4)
        }
        .accessibilityHidden(true)
    }
}

/// A casino win: gold coins and sparkles fly out from the finished squares and "大当り!" (big win) pops up.
private struct WinBurst: View {
    let size: CGFloat
    @State private var out = false
    @State private var pop = false
    @State private var fade = false

    var body: some View {
        ZStack {
            ForEach(0..<24, id: \.self) { k in
                let angle = Double(k) / 24 * 2 * .pi
                let dist = size * (k % 2 == 0 ? 0.45 : 0.3)
                Image(systemName: k % 3 == 0 ? "sparkle" : "circle.fill")
                    .font(.system(size: k % 3 == 0 ? 24 : 14))
                    .foregroundStyle(k % 2 == 0 ? Theme.gold : Theme.ivory)
                    .shadow(color: Jewel.ruby.fill, radius: 0, y: 1)
                    .offset(x: out ? cos(angle) * dist : 0, y: out ? sin(angle) * dist : 0)
                    .scaleEffect(out ? 0.4 : 1.3)
                    .opacity(out ? 0 : 1)
            }
            Text("大当り!")
                .font(.system(size: size * 0.13, weight: .heavy, design: .serif))
                .foregroundStyle(Theme.gold)
                .shadow(color: Jewel.ruby.fill, radius: 0, x: 2, y: 2)
                .shadow(color: .black.opacity(0.5), radius: 6)
                .fixedSize()
                .scaleEffect(pop ? 1 : 0.2)
                .opacity(fade ? 0 : 1)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear {
            withAnimation(.easeOut(duration: 0.9)) { out = true }
            withAnimation(.spring(duration: 0.35, bounce: 0.5)) { pop = true }
            withAnimation(.easeIn(duration: 0.4).delay(0.7)) { fade = true }
        }
    }
}
