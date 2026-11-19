import AppTrackingTransparency
import GoogleMobileAds
import UserMessagingPlatform

/// AdMob, in the order Google requires: consent form, then Apple's tracking prompt, then the ads SDK.
/// Only between-games ads for now, never mid-game, and none once Remove Ads is bought.
final class Ads: NSObject, FullScreenContentDelegate {
    static let shared = Ads()

    /// Set per build in project.yml: Google's test unit in Debug, the real one in Release.
    private let interstitialUnit = Bundle.main.object(forInfoDictionaryKey: "GADInterstitialID") as? String ?? ""
    private var interstitial: InterstitialAd?
    private var canRequest = false
    private var gamesSinceAd = 0
    private var lastAd = Date()  // so the first ad waits 4 minutes into the session too

    private var launches: Int {
        get { UserDefaults.standard.integer(forKey: "launches") }
        set { UserDefaults.standard.set(newValue, forKey: "launches") }
    }
    private var gamesFinished: Int {
        get { UserDefaults.standard.integer(forKey: "gamesFinished") }
        set { UserDefaults.standard.set(newValue, forKey: "gamesFinished") }
    }

    /// Called once at launch.
    func start() async {
        launches += 1
        do {
            try await ConsentInformation.shared.requestConsentInfoUpdate(with: nil)
            try await ConsentForm.loadAndPresentIfRequired(from: nil)
        } catch {
            print("Consent error: \(error)")  // the SDK falls back to the last stored consent
        }
        guard ConsentInformation.shared.canRequestAds else { return }
        _ = await ATTrackingManager.requestTrackingAuthorization()
        await MobileAds.shared.start()
        canRequest = true
        await loadInterstitial()
    }

    /// Call when a game is won or finished.
    func gameFinished() {
        gamesFinished += 1
        gamesSinceAd += 1
    }

    /// Call when the player leaves the "game finished" screen. Shows an ad only if the frequency rules allow it.
    func showBetweenGames() {
        guard let ad = interstitial else {
            Task { await loadInterstitial() }  // the last load failed; ready for next time
            return
        }
        guard AdRules.interstitialAllowed(
            adsRemoved: Purchases.shared.adsRemoved, launches: launches, gamesFinished: gamesFinished,
            gamesSinceAd: gamesSinceAd, secondsSinceAd: Date().timeIntervalSince(lastAd))
        else { return }
        ad.fullScreenContentDelegate = self
        Music.paused = true  // the ad may have its own sound
        ad.present(from: nil)
        interstitial = nil
        gamesSinceAd = 0
        lastAd = Date()
        Task { await loadInterstitial() }
    }

    /// Google requires a way to reopen the consent form where consent applies (EEA, UK, Switzerland).
    var privacyOptionsRequired: Bool {
        ConsentInformation.shared.privacyOptionsRequirementStatus == .required
    }

    func showPrivacyOptions() async {
        do {
            try await ConsentForm.presentPrivacyOptionsForm(from: nil)
        } catch {
            print("Privacy options error: \(error)")
        }
    }

    func adDidDismissFullScreenContent(_ ad: any FullScreenPresentingAd) { Music.paused = false }
    func ad(_ ad: any FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: any Error) { Music.paused = false }

    private func loadInterstitial() async {
        guard canRequest, !Purchases.shared.adsRemoved else { return }
        do {
            interstitial = try await InterstitialAd.load(with: interstitialUnit, request: Request())
        } catch {
            print("Interstitial failed to load: \(error)")  // no ad this time; try again after the next game
        }
    }
}
