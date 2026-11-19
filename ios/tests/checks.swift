// Self-checks for the logic that doesn't need a phone. Run: tests/run.sh
import Foundation

func check(_ ok: Bool, _ what: String) {
    if !ok { print("FAILED: \(what)"); exit(1) }
}

struct Sample: Codable, Equatable { var score: Int; var grid: [Int] }

@main struct Checks {
    static func main() {
        Save.dir = FileManager.default.temporaryDirectory.appending(path: "gamehaven-checks")
        Save.store("_test", Sample(score: 3, grid: [1, 2]))
        check(Save.load("_test", as: Sample.self) == Sample(score: 3, grid: [1, 2]), "save round trip")
        Save.clear("_test")
        check(Save.load("_test", as: Sample.self) == nil, "cleared save loads empty")

        check(!AdRules.interstitialAllowed(adsRemoved: false, launches: 1, gamesFinished: 10, gamesSinceAd: 5, secondsSinceAd: 999), "no ads in first session")
        check(!AdRules.interstitialAllowed(adsRemoved: false, launches: 2, gamesFinished: 3, gamesSinceAd: 3, secondsSinceAd: 999), "no ads in first 3 games")
        check(!AdRules.interstitialAllowed(adsRemoved: false, launches: 2, gamesFinished: 9, gamesSinceAd: 2, secondsSinceAd: 999), "3 games between ads")
        check(!AdRules.interstitialAllowed(adsRemoved: false, launches: 2, gamesFinished: 9, gamesSinceAd: 3, secondsSinceAd: 239), "4 minutes between ads")
        check(!AdRules.interstitialAllowed(adsRemoved: true, launches: 2, gamesFinished: 9, gamesSinceAd: 3, secondsSinceAd: 999), "Remove Ads")
        check(AdRules.interstitialAllowed(adsRemoved: false, launches: 2, gamesFinished: 4, gamesSinceAd: 3, secondsSinceAd: 240), "ad allowed")

        check(Village.stage(stars: 0) == 0 && Village.stage(stars: 2) == 1 && Village.stage(stars: 3) == 2 && Village.stage(stars: 999) == Village.stages.count - 1, "village stage from stars")
        check(zip(Village.stages, Village.stages.dropFirst()).allSatisfy { $0.stars < $1.stars }, "village stages in order")
        UserDefaults.standard.removeObject(forKey: "stars")
        let village = Village()
        check(village.earn(1)?.name == Village.stages[1].name && village.earn(1) == nil && village.earn(1)?.name == Village.stages[2].name, "earning unlocks each stage once")
        check(Village().stars == 3, "stars saved")
        UserDefaults.standard.removeObject(forKey: "stars")

        let p = SudokuLogic.generate(clues: 40, seed: 3)
        var g = SudokuGame(puzzle: p.puzzle, solution: p.solution, board: p.puzzle, level: .easy)
        let empty = (0..<81).first { p.puzzle[$0] == 0 }!
        let d = p.solution[empty]
        let before = g.left(d)
        g.place(d, at: empty)
        check(g.board[empty] == d && g.left(d) == before - 1, "placing fills the square and the counter drops")
        check(g.undo() == empty && g.board[empty] == 0, "undo empties it")
        check(g.finishedUnits(at: empty).isEmpty, "unfinished square finishes nothing")
        var full = g
        full.board = p.solution
        check(full.finishedUnits(at: empty).count == 21, "a correct square finishes its row, column and box")
        let given = (0..<81).first { p.puzzle[$0] != 0 }!
        g.place(1, at: given)
        check(g.board[given] == p.puzzle[given], "givens can't change")
        check(g.stars == 2, "no mistakes earns the bonus star")
        g.place(d % 9 + 1, at: empty)
        _ = g.undo()
        check(g.mistakes == 1 && g.stars == 1, "a mistake stays counted after undo and only removes the bonus")
        check(try! JSONDecoder().decode(SudokuGame.self, from: JSONEncoder().encode(g)).mistakes == 1, "mistakes saved")
        check(SudokuDaily.seed("2026-11-17") == 20261117 && SudokuDaily.key(Date(timeIntervalSince1970: 0)).count == 10, "daily key and seed")
        check(SudokuLogic.generate(clues: 32, seed: SudokuDaily.seed("2026-11-17")).puzzle == SudokuLogic.generate(clues: 32, seed: 20261117).puzzle, "same daily puzzle for everyone")

        check(SudokuLogic.peers[0].count == 20 && SudokuLogic.peers[80].count == 20, "peers")
        check(SudokuLogic.generate(clues: 32, seed: 7).puzzle == SudokuLogic.generate(clues: 32, seed: 7).puzzle, "seed repeats")
        for level in SudokuLogic.Level.allCases {
            let start = Date()
            var (puzzle, solution) = SudokuLogic.generate(clues: level.clues, seed: 42)
            let clues = puzzle.filter { $0 != 0 }.count
            print("Sudoku \(level.rawValue): \(clues) clues in \(Int(Date().timeIntervalSince(start) * 1000)) ms")
            for i in 0..<81 {
                check((1...9).contains(solution[i]), "solution filled")
                check(puzzle[i] == 0 || puzzle[i] == solution[i], "puzzle matches solution")
                check(SudokuLogic.peers[i].allSatisfy { solution[$0] != solution[i] }, "solution obeys rules")
            }
            check(clues >= level.clues && clues <= level.clues + 6, "clue count")
            check(SudokuLogic.countSolutions(&puzzle) == 1, "unique solution")
        }
        for level in SudokuLogic.Level.allCases {
            for seed in UInt64(0)..<20 {
                var (puzzle, _) = SudokuLogic.generate(level, seed: seed)
                check(SudokuLogic.solvesBySingles(puzzle) == (level != .hard), "\(level.rawValue) fits its level")
                check(SudokuLogic.countSolutions(&puzzle) == 1, "level puzzle has a unique solution")
            }
        }
        check(SudokuLogic.generate(.medium, seed: 20261117).puzzle == SudokuLogic.generate(.medium, seed: 20261117).puzzle, "level puzzle repeats for a seed")
        for theme in WordSearchLogic.themes {
            check(Set(theme.words).count == theme.words.count, "\(theme.name): no repeated words")
            check(!theme.words.contains { w in theme.words.contains { $0 != w && $0.contains(w) } }, "\(theme.name): no word inside another")
        }
        for level in WordSearchLogic.Level.allCases {
            for seed in UInt64(0)..<50 {
                let g = WordSearchLogic.generate(level, seed: seed)
                check(g.letters.count == level.size * level.size && g.hidden.count == level.words, "\(level.rawValue) has every word")
                check(g.letters.allSatisfy { $0.count == 1 && $0 >= "A" && $0 <= "Z" }, "every square is a capital letter")
                var play = g
                for f in g.hidden { check(play.pick(f.start, f.end) == f.word, "hidden word can be picked") }
                check(play.solved, "finding every word solves it")
            }
        }
        var ws = WordSearchLogic.generate(.easy, seed: 1)
        let w = ws.hidden[0]
        check(ws.pick(w.end, w.start) == w.word && ws.isFound(w.word), "a word can be picked from either end")
        check(ws.pick(w.start, w.end) == nil && ws.found.count == 1, "a found word isn't counted twice")
        check(ws.line(0, ws.size + 2) == nil && ws.line(0, 0) == nil && ws.line(0, ws.size * 2 + 2) == [0, ws.size + 1, ws.size * 2 + 2], "only straight lines count")
        let mid = ws.size * 3 + 3  // row 3, column 3 of 7
        check(ws.snap(from: mid, across: 2.2, down: 0.4) == mid + 2 && ws.snap(from: mid, across: 1.9, down: 2.3) == mid + 2 * ws.size + 2, "a wobbly slide snaps to a straight line")
        check(ws.snap(from: mid, across: -9, down: 0) == mid - 3 && ws.snap(from: mid, across: 0.2, down: -0.1) == mid, "a slide stops at the edge")
        check(WordSearchLogic.generate(.hard, seed: 9).letters == WordSearchLogic.generate(.hard, seed: 9).letters, "word search seed repeats")
        check(try! JSONDecoder().decode(WordSearchGame.self, from: JSONEncoder().encode(ws)).found == ws.found, "word search saves")
        let deal = SolitaireGame(draw: .one, seed: 5)
        check(deal.stock.count == 24 && deal.tableau.map(\.count) == Array(1...7), "solitaire deals 1 to 7 cards a column and 24 in the deck")
        check(deal.tableau.allSatisfy { $0.last!.up && $0.dropLast().allSatisfy { !$0.up } }, "only each column's top card is face up")
        check(Set((deal.stock + deal.tableau.flatMap { $0 }).map(\.id)).count == 52, "one of every card")
        check(SolitaireGame(draw: .three, seed: 5).stock == deal.stock, "solitaire seed repeats")
        var sol = deal
        sol.turn()
        check(sol.waste.count == 1 && sol.waste[0].up && sol.stock.count == 23, "turning shows one card")
        check(sol.undo() && sol.stock == deal.stock && sol.waste.isEmpty && sol.history.isEmpty, "undo puts it back")
        var three = SolitaireGame(draw: .three, seed: 5)
        for _ in 0..<8 { three.turn() }
        check(three.stock.isEmpty && three.waste.count == 24, "Draw 3 turns three at a time")
        three.turn()
        check(three.stock == SolitaireGame(draw: .three, seed: 5).stock, "an empty deck turns back over in order")
        var t = SolitaireGame(draw: .one, seed: 0)
        t.stock = []
        t.tableau = [[Card(rank: 5, suit: 2), Card(rank: 7, suit: 0, up: true)], [Card(rank: 8, suit: 1, up: true)], [Card(rank: 1, suit: 3, up: true)], [], [], [], []]
        check(t.target(for: .tableau(0, 1)) == .tableau(1), "black 7 goes on red 8")
        check(!t.move(.tableau(0, 1), to: .tableau(2)) && !t.move(.tableau(0, 1), to: .foundation) && t.move(.tableau(0, 1), to: .tableau(1)) && t.tableau[0] == [Card(rank: 5, suit: 2, up: true)] && t.tableau[1].count == 2, "moving uncovers and turns up the card below")
        check(t.target(for: .tableau(2, 0)) == .foundation && t.move(.tableau(2, 0), to: .foundation) && t.foundations[3].count == 1, "an ace goes home")
        check(t.target(for: .tableau(0, 0)) == nil && !(0..<7).contains { t.move(.tableau(0, 0), to: .tableau($0)) }, "a card with nowhere to go stays")
        check(t.cards(at: .tableau(1, 0)).count == 2, "a run moves together")
        t.tableau[0] = [Card(rank: 13, suit: 1, up: true)]
        check(t.target(for: .tableau(0, 0)) == nil, "a king at the bottom doesn't hop to an empty column")
        check(!t.allows(.tableau(1, 1), to: .tableau(1)), "a card can't move onto its own column")
        check(try! JSONDecoder().decode(SolitaireGame.self, from: JSONEncoder().encode(t)).tableau == t.tableau, "solitaire saves")
        var end = SolitaireGame(draw: .one, seed: 0)
        end.stock = []
        end.foundations = (0..<4).map { s in (1...10).map { Card(rank: $0, suit: s, up: true) } }
        end.tableau = [[Card(rank: 13, suit: 0, up: true), Card(rank: 12, suit: 1, up: true), Card(rank: 11, suit: 0, up: true)], [Card(rank: 13, suit: 1, up: true), Card(rank: 12, suit: 0, up: true), Card(rank: 11, suit: 1, up: true)], [Card(rank: 13, suit: 2, up: true), Card(rank: 12, suit: 3, up: true), Card(rank: 11, suit: 2, up: true)], [Card(rank: 13, suit: 3, up: true), Card(rank: 12, suit: 2, up: true), Card(rank: 11, suit: 3, up: true)], [], [], []]
        check(end.canFinish, "all face up can finish")
        while end.finishStep() {}
        check(end.won && !end.canFinish, "finish sends every card home")
        var wins = 0
        for seed in UInt64(0)..<200 {
            var play = SolitaireGame(draw: .one, seed: seed)
            var steps = 0
            while let h = play.hint, steps < 2000 {
                switch h {
                case .move(let s): check(play.move(s, to: play.target(for: s)!), "a hinted move can be made")
                case .turn: play.turn()
                }
                steps += 1
            }
            check(steps < 2000, "hints never go round in circles")
            while play.finishStep() {}
            if play.won { wins += 1 }
        }
        print("Solitaire: following hints wins \(wins) of 200 Draw 1 deals")
        check(wins > 0, "hints can win a game")

        for level in MahjongLogic.Level.allCases {
            check(level.tiles % 2 == 0, "mahjong \(level) has whole pairs")
            for seed in UInt64(0)..<30 {
                var m = MahjongLogic.generate(level, seed: seed)
                for _ in 0..<10 where !m.won {  // hints alone can paint themselves into a corner; that's what Shuffle is for
                    while let (a, b) = m.hint { check(m.match(a, b), "a hinted mahjong pair clears") }
                    if !m.won { check(m.shuffle(seed: seed), "a stuck mahjong board can be shuffled") }
                }
                check(m.won, "mahjong \(level) seed \(seed) can be cleared")
            }
        }
        check(MahjongLogic.generate(.hard, seed: 4).tiles == MahjongLogic.generate(.hard, seed: 4).tiles, "mahjong seed repeats")
        var mj = MahjongLogic.generate(.easy, seed: 2)
        let top = mj.tiles.indices.first { mj.tiles[$0].z == 1 }!
        let under = mj.tiles.indices.first { mj.tiles[$0].z == 0 && mj.covered($0) }!
        check(mj.free(top) && !mj.free(under), "covered tiles aren't free")
        check(!mj.free(mj.tiles.indices.first { mj.tiles[$0].z == 0 && mj.tiles[$0].x == 2 && mj.tiles[$0].y == 0 }!), "a tile with both sides taken isn't free")
        let (a, b) = mj.hint!
        let other = mj.left.first { mj.free($0) && mj.tiles[$0].face != mj.tiles[a].face }!
        check(!mj.match(a, other) && !mj.match(a, a), "different faces don't clear")
        check(mj.match(a, b) && mj.left.count == 30 && mj.undo() && mj.left.count == 32, "match then undo")
        _ = mj.match(a, b)
        check(try! JSONDecoder().decode(MahjongGame.self, from: JSONEncoder().encode(mj)).gone == mj.gone, "mahjong saves")
        for level in JigsawLogic.Level.allCases {
            let jg = JigsawLogic.generate(level, picture: 1, seed: 4)
            check(jg.loose.sorted() == Array(0..<level.pieces) && jg.loose != Array(0..<level.pieces), "\(level.rawValue) jigsaw has every piece, shuffled")
            let n = level.size
            for p in 0..<level.pieces {
                let e = jg.edges(p)
                check((e[0] == 0) == (p < n) && (e[1] == 0) == (p % n == n - 1) && (e[2] == 0) == (p >= n * (n - 1)) && (e[3] == 0) == (p % n == 0), "only border sides are flat")
                if p % n < n - 1 { check(e[1] == -jg.edges(p + 1)[3], "side-by-side pieces interlock") }
                if p < n * (n - 1) { check(e[2] == -jg.edges(p + n)[0], "stacked pieces interlock") }
            }
            var play = jg
            check(!play.place(0, at: 1) && play.loose.count == level.pieces, "a piece doesn't go in another spot")
            for p in jg.loose { check(play.place(p, at: p) && play.isPlaced(p), "a piece goes in its own spot") }
            check(play.solved && !play.place(0, at: 0) && play.stars == JigsawLogic.Level.allCases.firstIndex(of: level)! + 1, "placing every piece solves it, once")
        }
        check(JigsawLogic.generate(.hard, picture: 0, seed: 9).across == JigsawLogic.generate(.hard, picture: 0, seed: 9).across, "jigsaw seed repeats")
        var js = JigsawLogic.generate(.medium, picture: 2, seed: 3)
        _ = js.place(5, at: 5)
        check(try! JSONDecoder().decode(JigsawGame.self, from: JSONEncoder().encode(js)).loose == js.loose, "jigsaw saves")
        var dominoWins = 0
        for level in DominoLogic.Level.allCases {
            for seed in UInt64(0)..<200 {
                var d = DominoLogic.generate(level, seed: seed)
                var moves = 0
                var opener: Domino?
                while !d.over {
                    if let i = d.hint { check(d.play(i, on: d.sides(d.board.you[i])[0]), "a hinted domino plays") }
                    else { check(d.draw() || d.pass(), "you can always draw or pass when stuck") }
                    let b = d.board
                    check(b.line.count + b.you.count + b.computer.count + b.pile.count == 28, "every domino is somewhere")
                    check(zip(b.line, b.line.dropFirst()).allSatisfy { $0.b == $1.a }, "the line's ends touch")
                    if !b.line.isEmpty { opener = opener ?? b.line[b.left]; check(b.line[b.left] == opener, "the first tile stays in the middle") }
                    let spots = DominoLogic.layout(b.line, first: b.left, width: 12)
                    let boxes = spots.map { s -> (x: ClosedRange<Double>, y: ClosedRange<Double>) in
                        let (w, h) = s.vertical ? (0.5, 1.0) : (1.0, 0.5)  // half sizes
                        return (s.x - w...s.x + w, s.y - h...s.y + h)
                    }
                    check(boxes.allSatisfy { $0.x.lowerBound >= -6 && $0.x.upperBound <= 6 }, "table tiles stay inside the edges")
                    func overlap(_ a: ClosedRange<Double>, _ b: ClosedRange<Double>) -> Bool { min(a.upperBound, b.upperBound) - max(a.lowerBound, b.lowerBound) > 0.001 }
                    for (k, box) in boxes.enumerated() { for other in boxes[(k + 1)...] { check(!(overlap(box.x, other.x) && overlap(box.y, other.y)), "table tiles don't overlap") } }
                    moves += 1
                    check(moves < 100, "a domino game ends")
                }
                if d.result == .won { dominoWins += 1 }
            }
        }
        print("Dominoes: following hints wins \(dominoWins) of 400 games")
        check(dominoWins > 0, "hints can win dominoes")
        check(DominoLogic.set.count == 28 && Set(DominoLogic.set).count == 28, "double-six set")
        var dg = DominoLogic.generate(.hard, seed: 5)
        let hand = dg.board.you
        let misfit = dg.board.you.indices.first { dg.sides(dg.board.you[$0]).isEmpty }
        if let misfit, !dg.board.line.isEmpty { check(!dg.play(misfit, on: .left) && !dg.play(misfit, on: .right), "a tile that doesn't fit can't be played") }
        if let i = dg.hint { check(dg.play(i, on: dg.sides(dg.board.you[i])[0]) && dg.undo() && dg.board.you == hand, "play then undo") }
        else { check(dg.draw() && dg.undo() && dg.board.you == hand, "draw then undo") }
        check(try! JSONDecoder().decode(DominoGame.self, from: JSONEncoder().encode(dg)).board.you == dg.board.you, "dominoes saves")

        check(NonogramLogic.clue([true, true, false, true, false]) == [2, 1] && NonogramLogic.clue([false, false]) == [], "nonogram clues")
        check(NonogramLogic.placements([2, 1], 5).count == 3 && NonogramLogic.placements([3, 2], 5).count == 0, "run placements")
        check(!NonogramLogic.solvesLineByLine([true, false, false, true], size: 2), "a picture with two answers isn't accepted")
        for level in NonogramLogic.Level.allCases {
            let start = Date()
            let pic = NonogramLogic.generate(level, seed: 11)
            print("Nonogram \(level.rawValue): \(Int(Date().timeIntervalSince(start) * 1000)) ms")
            let n = level.size
            check(pic.count == n * n && (0..<n * n).allSatisfy { pic[$0] == pic[$0 / n * n + n - 1 - $0 % n] }, "\(level.rawValue) picture is mirrored")
            check(pic == NonogramLogic.generate(level, seed: 11), "nonogram seed repeats")
            var ng = NonogramGame(solution: pic, level: level)
            let wrong = (0..<n * n).first { !pic[$0] && ng.marks[$0] == .blank }
            if let wrong { check(!ng.mark(wrong, fill: true) && ng.marks[wrong] == .cross && ng.mistakes == 1, "a wrong fill is crossed and counted") }
            if let miss = (0..<n * n).first(where: { pic[$0] && ng.marks[$0] == .blank }) {
                check(!ng.mark(miss, fill: false) && ng.marks[miss] == .fill && ng.wrong.contains(miss), "a wrong cross is filled and remembered as wrong")
            }
            for i in 0..<n * n where pic[i] { check(ng.mark(i, fill: true), "a right fill counts") }
            check(ng.solved && !ng.marks.contains(.blank), "filling the picture solves it and crosses the rest")
            check(ng.stars == NonogramLogic.Level.allCases.firstIndex(of: level)! + 1, "a wrong guess only loses the bonus star")
            check(try! JSONDecoder().decode(NonogramGame.self, from: JSONEncoder().encode(ng)).marks == ng.marks, "nonogram saves")
        }
        var lesson = NonogramGame(solution: NonogramLogic.lesson.picture, level: .easy)
        for line in NonogramLogic.lesson.lines {
            for i in NonogramLogic.lines(5)[line] where lesson.solution[i] && lesson.marks[i] == .blank { check(lesson.mark(i, fill: true), "lesson fill") }
        }
        check(lesson.solved && !lesson.marks.contains(.blank), "the lesson's steps solve the house and cross off the rest")
        print("All checks passed")
    }
}
