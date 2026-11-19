import Foundation

/// When a between-games ad may show: never in the first session or first 3 games,
/// then at most one every 3 games and 4 minutes. Never for players who bought Remove Ads.
enum AdRules {
    static func interstitialAllowed(adsRemoved: Bool, launches: Int, gamesFinished: Int, gamesSinceAd: Int, secondsSinceAd: Double) -> Bool {
        !adsRemoved && launches > 1 && gamesFinished > 3 && gamesSinceAd >= 3 && secondsSinceAd >= 240
    }
}
