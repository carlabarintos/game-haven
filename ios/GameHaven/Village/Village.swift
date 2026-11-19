import Foundation
import Observation

/// Yuzu Springs, the player's village on the home screen (see home-village.md). Every finished game earns stars,
/// and stars grow the village on their own: nothing to spend, nothing to tap. Stars are never sold.
@Observable
final class Village {
    /// Each stage adds one layer to the village.
    /// `image` is a transparent PNG the size of the whole scene (e.g. village-3.png); until it exists a stand-in is drawn.
    struct Stage {
        let stars: Int
        let name: String
        var image: String
    }

    static let stages: [Stage] = [
        Stage(stars: 0, name: "A quiet valley", image: "village-0"),
        Stage(stars: 1, name: "A little hot spring", image: "village-1"),
        Stage(stars: 3, name: "Stone lanterns", image: "village-2"),
        Stage(stars: 10, name: "Cherry trees", image: "village-4"),
        Stage(stars: 15, name: "Koi and a red bridge", image: "village-5"),
        Stage(stars: 28, name: "Paper lanterns", image: "village-7"),
        Stage(stars: 45, name: "Fireflies", image: "village-9"),
    ]

    /// Index of the last stage reached with this many stars.
    static func stage(stars: Int) -> Int { stages.lastIndex { $0.stars <= stars }! }

    var stars: Int {
        didSet { UserDefaults.standard.set(stars, forKey: "stars") }
    }

    init() { stars = UserDefaults.standard.integer(forKey: "stars") }

    var stage: Int { Self.stage(stars: stars) }
    var next: Stage? { Self.stages.indices.contains(stage + 1) ? Self.stages[stage + 1] : nil }

    /// Adds stars and returns the stage just unlocked, if any, so the win screen can show it.
    func earn(_ amount: Int) -> Stage? {
        let before = stage
        stars += amount
        return stage > before ? Self.stages[stage] : nil
    }
}
