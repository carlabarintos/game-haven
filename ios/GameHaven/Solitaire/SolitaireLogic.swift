import Foundation

/// One playing card.
nonisolated struct Card: Codable, Hashable {
    /// 1 is the ace, 11 jack, 12 queen, 13 king.
    let rank: Int
    /// 0 spades, 1 hearts, 2 diamonds, 3 clubs.
    let suit: Int
    var up = false

    var id: Int { suit * 13 + rank - 1 }
    var red: Bool { suit == 1 || suit == 2 }
    /// What the corner shows: A, 2 … 10, J, Q, K.
    var short: String { ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"][rank - 1] }
    var name: String { "\(["Ace", "2", "3", "4", "5", "6", "7", "8", "9", "10", "Jack", "Queen", "King"][rank - 1]) of \(Self.suits[suit])" }
    static let suits = ["spades", "hearts", "diamonds", "clubs"]
}

/// One saved game of Klondike: deal, turn the deck, move cards, undo.
/// Piles list their cards bottom first, so the top card is last.
nonisolated struct SolitaireGame: Codable {
    /// How many cards each tap on the deck turns over.
    enum Draw: Int, Codable, CaseIterable { case one = 1, three = 3 }
    /// A card the player tapped: the top turned card, a home pile's top card, or a column and the card's place in it.
    enum Spot: Equatable { case waste, foundation(Int), tableau(Int, Int) }
    enum Target: Equatable { case foundation, tableau(Int) }
    enum Hint: Equatable { case move(Spot), turn }

    let draw: Draw
    var stock: [Card] = []
    var waste: [Card] = []
    /// One home pile per suit, in suit order.
    var foundations: [[Card]] = Array(repeating: [], count: 4)
    var tableau: [[Card]] = Array(repeating: [], count: 7)
    /// Earlier positions for Undo, newest last, each without its own history.
    var history: [SolitaireGame] = []

    /// A seed always gives the same deal.
    init(draw: Draw, seed: UInt64) {
        self.draw = draw
        var rng = SplitMix64(seed: seed)
        var deck = (0..<4).flatMap { s in (1...13).map { Card(rank: $0, suit: s) } }.shuffled(using: &rng)
        for p in 0..<7 {
            for i in 0...p {
                var c = deck.removeLast()
                c.up = i == p
                tableau[p].append(c)
            }
        }
        stock = deck
    }

    var won: Bool { foundations.allSatisfy { $0.count == 13 } }
    /// Every card is dealt out and face up, so the rest can go home on its own.
    var canFinish: Bool { !won && stock.isEmpty && waste.isEmpty && tableau.allSatisfy { $0.allSatisfy(\.up) } }
    /// Turning one card earns 2, turning three earns 3. Undo and hints never cost a star.
    var stars: Int { draw == .one ? 2 : 3 }

    /// The cards that move together when this spot is tapped. Empty for a face-down card.
    func cards(at spot: Spot) -> [Card] {
        switch spot {
        case .waste: return Array(waste.suffix(1))
        case .foundation(let s): return Array(foundations[s].suffix(1))
        case .tableau(let p, let i): return tableau[p].indices.contains(i) && tableau[p][i].up ? Array(tableau[p][i...]) : []
        }
    }

    func fitsHome(_ c: Card) -> Bool { foundations[c.suit].count == c.rank - 1 }

    /// One lower and the other colour, or a king on an empty column.
    func fits(_ c: Card, on p: Int) -> Bool {
        guard let top = tableau[p].last else { return c.rank == 13 }
        return top.up && top.red != c.red && top.rank == c.rank + 1
    }

    /// Whether the cards at spot may go there: a single card home on its suit, or onto another column that takes it.
    func allows(_ spot: Spot, to target: Target) -> Bool {
        let moving = cards(at: spot)
        guard let c = moving.first else { return false }
        switch target {
        case .foundation: return moving.count == 1 && spot != .foundation(c.suit) && fitsHome(c)
        case .tableau(let p):
            if case .tableau(p, _) = spot { return false }
            return fits(c, on: p)
        }
    }

    /// A good place for these cards, for Hint: home if a single card can go, else the first column that takes them,
    /// preferring a card over an empty column. Nil if nowhere.
    func target(for spot: Spot) -> Target? {
        if allows(spot, to: .foundation) { return .foundation }
        // A king already at the bottom of a column gains nothing from an empty one.
        var kingAtBottom = false
        if case .tableau(_, 0) = spot { kingAtBottom = true }
        let piles = (0..<7).filter { allows(spot, to: .tableau($0)) && !(kingAtBottom && tableau[$0].isEmpty) }
        return (piles.first { !tableau[$0].isEmpty } ?? piles.first).map { .tableau($0) }
    }

    /// Moves the cards at spot to the target the player chose, and turns up the card they uncover. False if the move isn't allowed.
    @discardableResult mutating func move(_ spot: Spot, to target: Target) -> Bool {
        guard allows(spot, to: target) else { return false }
        let moving = cards(at: spot)
        remember()
        switch spot {
        case .waste: waste.removeLast()
        case .foundation(let s): foundations[s].removeLast()
        case .tableau(let p, let i):
            tableau[p].removeSubrange(i...)
            if let last = tableau[p].indices.last { tableau[p][last].up = true }
        }
        switch target {
        case .foundation: foundations[moving[0].suit].append(moving[0])
        case .tableau(let p): tableau[p] += moving
        }
        return true
    }

    /// Turns over the next card (three on Draw 3), or turns the pile back over once the deck runs out.
    @discardableResult mutating func turn() -> Bool {
        guard !stock.isEmpty || !waste.isEmpty else { return false }
        remember()
        if stock.isEmpty {
            stock = waste.reversed().map { var c = $0; c.up = false; return c }
            waste = []
        } else {
            for _ in 0..<min(draw.rawValue, stock.count) {
                var c = stock.removeLast()
                c.up = true
                waste.append(c)
            }
        }
        return true
    }

    @discardableResult mutating func undo() -> Bool {
        guard let last = history.popLast() else { return false }
        let rest = history
        self = last
        history = rest
        return true
    }

    private mutating func remember() {
        var snapshot = self
        snapshot.history = []
        history.append(snapshot)
        if history.count > 300 { history.removeFirst() }  // keeps the save file small
    }

    /// Sends the lowest top card home. For Finish, when canFinish is true.
    @discardableResult mutating func finishStep() -> Bool {
        let tops = (0..<7).compactMap { p in tableau[p].last.map { (p, $0) } }.filter { fitsHome($0.1) }
        guard let (p, _) = tops.min(by: { $0.1.rank < $1.1.rank }) else { return false }
        return move(.tableau(p, tableau[p].count - 1), to: .foundation)
    }

    /// A helpful next step: send a card home, free a face-down card or empty a column, play the turned card, else turn the deck.
    /// Nil when nothing helps.
    var hint: Hint? {
        let tops: [Spot] = [.waste] + (0..<7).compactMap { p in tableau[p].indices.last.map { .tableau(p, $0) } }
        if let s = tops.first(where: { target(for: $0) == .foundation }) { return .move(s) }
        // Only a column's whole face-up run is worth moving; part of one just swaps it between columns.
        for p in 0..<7 {
            if let i = tableau[p].firstIndex(where: \.up), target(for: .tableau(p, i)) != nil { return .move(.tableau(p, i)) }
        }
        if target(for: .waste) != nil { return .move(.waste) }
        // shortcut: on Draw 3 not every deck card can come up, so this can suggest turning when it won't help; upgrade with a full solver.
        let deck = stock + waste
        return deck.contains { c in fitsHome(c) || (0..<7).contains { fits(c, on: $0) } } ? .turn : nil
    }
}
