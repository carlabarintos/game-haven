import SwiftUI

/// Nonograms at the Bathhouse: the numbers by each row and column count its runs of filled squares; fill them in to reveal a picture.
/// No timer; a wrong guess is put right for you; unlimited hints; saves after every move.
struct NonogramView: View {
    static let id = "nonogram"

    private enum Phase { case menu, board, won }

    @State private var game = Save.load(Self.id, as: NonogramGame.self)
    @State private var phase: Phase = Save.load(Self.id, as: NonogramGame.self) == nil ? .menu : .board
    /// The square last tapped, with the Fill / Cross tray open beside it.
    @State private var selected: Int?
    /// The step of the guided puzzle, while it's being played; not saved and pays no stars.
    @State private var coach: Int?
    /// Whether the how-to-play popup is open.
    @State private var rules = false
    /// Squares of a row or column just finished, glowing for a moment.
    @State private var glow: Set<Int> = []
    /// Per square, how many wrong guesses went in; each one shakes it.
    @State private var shakes: [Int: Int] = [:]
    @State private var wonPicture: NonogramGame?
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
            case .won: won
            }
        }
        .screen()
        .sensoryFeedback(.success, trigger: glow) { (_: Set<Int>, new: Set<Int>) in !new.isEmpty }
        .sensoryFeedback(.error, trigger: game?.mistakes)
        .sensoryFeedback(.selection, trigger: selected)
    }

    private var menu: some View {
        ScrollView {
            VStack(spacing: 20) {
                Heading(text: "Nonograms")
                Text("At the Bathhouse").font(.title3.weight(.semibold))
                Button { learn() } label: { Label("Learn with a guided puzzle", systemImage: "hand.point.up.left") }.jewel(.gold)
                Button { rules = true } label: { Label("How to play", systemImage: "questionmark.circle") }.jewel(.amethyst)
                ForEach(Array(zip(NonogramLogic.Level.allCases, [Jewel.jade, .amber, .ruby])), id: \.0) { level, jewel in
                    let stars = NonogramLogic.Level.allCases.firstIndex(of: level)! + 1  // what a solve pays, as in NonogramGame.stars
                    Button { start(level) } label: {
                        VStack(spacing: 2) {
                            Text("\(level.rawValue) · \(level.size)×\(level.size)")
                            Text(String(repeating: "★", count: stars)).font(.body).accessibilityLabel("\(stars) \(stars == 1 ? "star" : "stars")")
                        }
                    }
                    .jewel(jewel)
                }
                Button("Back") { game == nil ? dismiss() : (phase = .board) }.jewel(.onyx)
            }
            .padding(8)  // room for the shadows, which the scroll area would clip
        }
        .sheet(isPresented: $rules) { howToPlay }
    }

    private var howToPlay: some View {
        VStack(spacing: 20) {
            Heading(text: "How to play")
            ScrollView {
                Text("A picture is hidden in the grid. The numbers beside each row, and above each column, say how many squares in a row are filled, in order. \"3 1\" means three filled squares, a gap, then one more.\n\nTap a square and two buttons open beside it: Fill to shade it, or Cross to mark it empty. Tap the square again to close them. If a guess is wrong, the square shakes, is put right for you, and stays red so you can see where it was.\n\nWhen a row or column is finished, its numbers fade and its empty squares are crossed off.\n\nThere is no timer. Solve a puzzle with no wrong guesses for a bonus star.")
                    .font(.title3)
            }
            Button("Got it") { rules = false }.jewel(.gold)
        }
        .screen()
    }

    private func board(_ g: NonogramGame) -> some View {
        VStack(spacing: 12) {
            HStack {
                Button("Menu") { dismiss() }.jewel(.onyx)
                Button("New puzzle") { phase = .menu }.jewel(.sapphire)
            }
            if let coach { lesson(coach) }
            NonogramBoard(game: g, glow: glow, shakes: shakes, focus: coach.flatMap { NonogramLogic.lesson.lines[safe: $0] },
                          selected: selected, tap: tap, pick: pick)
                .zIndex(1)  // the tray may hang over the button below
            // Stops growing past this size: beyond it it'd squeeze the board.
            Button(action: hint) {
                VStack(spacing: 0) {
                    Text("Hint").font(.title3.bold())
                    Text("fill one square").font(.footnote)
                }
            }
            .jewel(.amethyst)
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        }
    }

    private var won: some View {
        VStack(spacing: 20) {
            Heading(text: "Well done!")
            ScrollView {
                VStack(spacing: 16) {
                    if let g = wonPicture {
                        NonogramPicture(game: g).frame(width: 180, height: 180)
                        StarCelebration(stars: g.stars)
                        Text("You solved the \(g.level.rawValue.lowercased()) puzzle and earned \(g.stars) ★ for your village.").font(.title3)
                        if g.mistakes == 0 { Text("No wrong guesses: 1 bonus ★ included.").font(.title3.bold()) }
                    }
                    VillageView(stage: village.stage, crop: true).frame(height: 300).clipShape(.rect(cornerRadius: 14))
                    if let unlocked { Text("Your village grew: \(unlocked.name.lowercased())!").font(.title3.bold()) }
                }
                .padding(8)
            }
            Button("New puzzle") { Ads.shared.showBetweenGames(); phase = .menu }.jewel(.gold)
            Button("Menu") { Ads.shared.showBetweenGames(); dismiss() }.jewel(.onyx)
        }
    }

    /// What the coach says at each step of the guided puzzle; the last has no line and ends the lesson.
    private static let coachSays = [
        "Each number counts filled squares in a row. The gold row says 5, and it is 5 squares long, so every square is filled. Tap each one and choose ■ Fill.",
        "Columns 1 and 5 say 1, and their 1 is found, so their other squares were crossed off for you. The gold column says 3 1: three filled, a gap, then one. That fits only one way: fill the top three and the bottom one.",
        "The top row is finished, so it was crossed off too. The gold column says 4, and only 4 of its squares are still open. Fill them.",
        "Same again: this column says 4, with 4 squares open. Fill them to finish the picture.",
        "You've drawn a little house! That's the whole game: read the numbers, fill what must be filled, and cross off what must be empty.",
    ]

    /// The coach's note above the board, and at the end, the way on.
    private func lesson(_ step: Int) -> some View {
        VStack(spacing: 10) {
            Text(Self.coachSays[step]).font(.title3).frame(maxWidth: .infinity, alignment: .leading)
            if step == Self.coachSays.count - 1 {
                Button("Play an easy puzzle") { start(.easy) }.jewel(.gold)
            }
        }
        .padding(12)
        .background(Theme.ivory, in: .rect(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.gold, lineWidth: 3))
        .accessibilityAddTraits(.updatesFrequently)
    }

    /// Starts the guided puzzle. Any saved game stays saved for later.
    private func learn() {
        game = NonogramGame(solution: NonogramLogic.lesson.picture, level: .easy)
        glow = []
        shakes = [:]
        selected = nil
        coach = 0
        phase = .board
    }

    private func start(_ level: NonogramLogic.Level) {
        game = NonogramGame(solution: NonogramLogic.generate(level, seed: .random(in: 0...UInt64.max)), level: level)
        glow = []
        shakes = [:]
        selected = nil
        coach = nil
        afterMove()
        phase = .board
    }

    /// Opens the tray beside a blank square; tapping the same square again closes it.
    private func tap(_ i: Int) {
        guard let g = game else { return }
        withAnimation(reduceMotion ? nil : .spring(duration: 0.3, bounce: 0.35)) {
            selected = selected == i || g.marks[i] != .blank ? nil : i
        }
    }

    private func pick(_ fill: Bool) {
        guard let i = selected else { return }
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.15)) { selected = nil }
        mark(i, fill: fill)
    }

    private func mark(_ i: Int, fill: Bool) {
        guard var g = game, g.marks[i] == .blank else { return }
        if !g.mark(i, fill: fill) {
            Sound.miss.play()
            withAnimation(reduceMotion ? nil : .linear(duration: 0.4)) { shakes[i, default: 0] += 1 }
        } else {
            Sound.tap.play()
        }
        game = g
        let done = g.finishedLines(at: i)
        if !done.isEmpty {
            withAnimation(.easeOut(duration: 0.2)) { glow = done }
            Task { try? await Task.sleep(for: .seconds(0.7)); withAnimation(.easeIn(duration: 0.4)) { glow = [] } }
        }
        afterMove()
    }

    /// Puts the selected square right if it's still blank, otherwise fills the first filled square not yet found.
    private func hint() {
        guard let g = game else { return }
        let picked = selected
        selected = nil
        if let i = picked, g.marks[i] == .blank { mark(i, fill: g.solution[i]); return }
        guard let i = g.solution.indices.first(where: { g.solution[$0] && g.marks[$0] == .blank }) else { return }
        mark(i, fill: true)
    }

    private func afterMove() {
        guard let g = game else { return }
        if var step = coach {  // the lesson moves on as each line is finished
            while let line = NonogramLogic.lesson.lines[safe: step], g.done(NonogramLogic.lines(g.size)[line]) { step += 1 }
            coach = step
            return
        }
        if g.solved {
            Save.clear(Self.id)
            Sound.win.play()
            wonPicture = g
            unlocked = village.earn(g.stars)
            game = nil
            Ads.shared.gameFinished()
            phase = .won
        } else {
            Save.store(Self.id, g)
        }
    }
}

/// The grid with its clues: row numbers to the left, column numbers stacked above. Ink on ivory paper, so high contrast needs no change.
private struct NonogramBoard: View {
    let game: NonogramGame
    let glow: Set<Int>
    let shakes: [Int: Int]
    /// The line the guided puzzle points at, shaded gold.
    let focus: Int?
    /// The square with the tray open; its row and column numbers are shaded.
    let selected: Int?
    let tap: (Int) -> Void
    let pick: (Bool) -> Void

    private static let wrongInk = Color(hex: 0xB00020)

    var body: some View {
        let n = game.size
        let lines = NonogramLogic.lines(n)
        let clues = lines.map(game.clue)
        let across = max(1, clues[..<n].map(\.count).max()!)  // widest row clue
        let down = max(1, clues[n...].map(\.count).max()!)  // tallest column clue
        GeometryReader { geo in
            let slot: CGFloat = 0.62  // one clue number, in squares
            let cell = min(geo.size.width / (CGFloat(n) + slot * CGFloat(across)), geo.size.height / (CGFloat(n) + slot * CGFloat(down)))
            let num = cell * slot
            VStack(alignment: .trailing, spacing: 0) {
                HStack(alignment: .bottom, spacing: 0) {
                    ForEach(0..<n, id: \.self) { c in
                        clue(clues[n + c], done: game.done(lines[n + c]), size: num, label: "Column \(c + 1)", down: true)
                            .frame(width: cell, height: num * CGFloat(down), alignment: .bottom)
                            .background(focus == n + c || selected.map { $0 % n == c } == true ? Theme.gold.opacity(0.5) : .clear)
                    }
                }
                ForEach(0..<n, id: \.self) { r in
                    HStack(spacing: 0) {
                        clue(clues[r], done: game.done(lines[r]), size: num, label: "Row \(r + 1)", down: false)
                            .frame(width: num * CGFloat(across), height: cell, alignment: .trailing)
                            .background(focus == r || selected.map { $0 / n == r } == true ? Theme.gold.opacity(0.5) : .clear)
                        ForEach(0..<n, id: \.self) { c in square(r * n + c, size: cell) }
                    }
                }
            }
            .overlay(alignment: .bottomTrailing) {
                ZStack(alignment: .topLeading) {
                    grid(n: n, cell: cell)
                    if let s = selected {
                        let pebble = max(60, cell * 1.2)  // never below a comfortable finger size
                        let tray = CGSize(width: pebble * 2 + 26, height: pebble + 20)
                        FillTray(pebble: pebble, pick: pick)
                            .position(trayCenter(s, n: n, cell: cell, tray: tray))
                            .transition(.scale(scale: 0.5).combined(with: .opacity))
                    }
                }
                .frame(width: cell * CGFloat(n), height: cell * CGFloat(n))  // the tray's position is in grid squares
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minHeight: 280)
        .dynamicTypeSize(.large)  // numbers scale with the board, not the text setting
    }

    /// One line's numbers, faded once the line is finished.
    private func clue(_ runs: [Int], done: Bool, size: CGFloat, label: String, down: Bool) -> some View {
        let stack = down ? AnyLayout(VStackLayout(spacing: 0)) : AnyLayout(HStackLayout(spacing: 0))
        return stack {
            ForEach(Array((runs.isEmpty ? [0] : runs).enumerated()), id: \.offset) { _, k in
                Text("\(k)").font(.system(size: size * 0.85, weight: .bold)).lineLimit(1).minimumScaleFactor(0.6).frame(width: size, height: size)  // "10" squeezes to fit
            }
        }
        .foregroundStyle(Theme.ink.opacity(done ? 0.3 : 1))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label) clue: \(runs.isEmpty ? "0" : runs.map(String.init).joined(separator: ", "))\(done ? ", finished" : "")")
    }

    /// Above or below the square, on whichever side has more room, so the square itself stays in view.
    private func trayCenter(_ s: Int, n: Int, cell: CGFloat, tray: CGSize) -> CGPoint {
        let side = cell * CGFloat(n)
        let row = CGFloat(s / n), col = CGFloat(s % n)
        let x = min(max((col + 0.5) * cell, tray.width / 2), side - tray.width / 2)
        let y = row < CGFloat(n) / 2 ? (row + 1) * cell + 6 + tray.height / 2 : row * cell - 6 - tray.height / 2
        return CGPoint(x: x, y: y)
    }

    private func focused(_ i: Int) -> Bool { focus.map { NonogramLogic.lines(game.size)[$0].contains(i) } ?? false }

    private func square(_ i: Int, size: CGFloat) -> some View {
        let mark = game.marks[i]
        let wrong = game.wrong.contains(i)
        return Button { tap(i) } label: {
            ZStack {
                Rectangle().fill(glow.contains(i) ? Theme.gold : focused(i) ? Theme.gold.opacity(0.4) : Theme.ivory)
                if mark == .fill { Rectangle().fill(wrong ? Self.wrongInk : Theme.ink).padding(size * 0.06) }
                if mark == .cross || wrong {  // a mistake also carries a heavy X or "!", so it doesn't rely on red alone
                    Image(systemName: mark == .fill ? "exclamationmark" : "xmark").font(.system(size: size * 0.5, weight: wrong ? .heavy : .regular))
                        .foregroundStyle(mark == .fill ? Theme.ivory : wrong ? Self.wrongInk : Theme.walnut)
                }
            }
            .frame(width: size, height: size)
            .overlay { if selected == i { Rectangle().strokeBorder(Theme.ink, lineWidth: 3) } }
            .modifier(Shake(count: CGFloat(shakes[i] ?? 0)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Row \(i / game.size + 1), column \(i % game.size + 1)")
        .accessibilityValue((mark == .fill ? "filled" : mark == .cross ? "crossed off" : "empty") + (wrong ? ", was a wrong guess" : ""))
    }

    /// Thin lines between squares, thick ones every 4 or 5 squares and round the edge.
    private func grid(n: Int, cell: CGFloat) -> some View {
        let every = n == 8 ? 4 : 5
        return Canvas { ctx, size in
            for k in 0...n {
                let x = CGFloat(k) * cell
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                path.move(to: CGPoint(x: 0, y: x))
                path.addLine(to: CGPoint(x: size.width, y: x))
                ctx.stroke(path, with: .color(Theme.ink), lineWidth: k % every == 0 ? 3 : 1)
            }
        }
        .frame(width: cell * CGFloat(n), height: cell * CGFloat(n))
        .allowsHitTesting(false)
    }
}

/// Two round pebbles beside the tapped square: shade it, or cross it off.
private struct FillTray: View {
    let pebble: CGFloat
    let pick: (Bool) -> Void

    var body: some View {
        HStack(spacing: 6) {
            stone(fill: true)
            stone(fill: false)
        }
        .padding(10)
        .background(Jewel.sapphire.fill, in: .rect(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(Theme.gold, lineWidth: 3))
        .shadow(color: .black.opacity(0.5), radius: 10, y: 6)
    }

    private func stone(fill: Bool) -> some View {
        Button { pick(fill) } label: {
            Image(systemName: fill ? "square.fill" : "xmark")
                .font(.system(size: pebble * 0.42, weight: .bold))
                .foregroundStyle(Theme.ink)
                .frame(width: pebble, height: pebble)
                .background(Circle().fill(RadialGradient(colors: [.white, Theme.ivory, Theme.paperEdge], center: UnitPoint(x: 0.35, y: 0.3), startRadius: 0, endRadius: pebble * 0.75)))
                .overlay(Circle().strokeBorder(Theme.walnut, lineWidth: 2))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(fill ? "Fill" : "Cross off")
    }
}

/// The finished picture, ink on paper, for the win screen.
private struct NonogramPicture: View {
    let game: NonogramGame

    var body: some View {
        Canvas { ctx, size in
            let n = game.size, cell = size.width / CGFloat(n)
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Theme.ivory))
            for i in game.solution.indices where game.solution[i] {
                ctx.fill(Path(CGRect(x: CGFloat(i % n) * cell, y: CGFloat(i / n) * cell, width: cell, height: cell)), with: .color(Theme.ink))
            }
        }
        .overlay(Rectangle().strokeBorder(Theme.walnut, lineWidth: 3))
        .accessibilityLabel("The finished picture")
    }
}

extension Array {
    subscript(safe i: Int) -> Element? { indices.contains(i) ? self[i] : nil }
}
