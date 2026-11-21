# Senior Games App: Plan & Ads Setup

Nov 17, 2026 · @Carl · updated Nov 21, 2026

## Summary

We build one iOS app (native Swift and SwiftUI) with a bundle of calm, large-print puzzle and card games for people 55+, launching in Australia first, then the US, Canada, New Zealand and the UK. It is free with **light, player-friendly ads** (an occasional full-screen ad between games, never mid-game), plus a one-time **Remove Ads** purchase at A$0.99.

- **Why this audience:** 67% of Australians 65+ play games, and card/board and puzzle are their top two genres. In the US, 49% of adults 50+ play, mostly on smartphones.
- **Why this model:** ad complaints are common in reviews of the big free solitaire, jigsaw and mahjong apps. Paid, ad-free versions are praised for it. A clear "pay once, no ads" option is our angle.
- **Why iOS first:** iPhones carry 50–65% of mobile web traffic in AU, US, CA and UK, versus 26–28% in DE, ES, BR and MX.

## Target markets

Launch in Australia, then add English-speaking countries with the same build. Translation waits until the app earns.

| Rank | Market | Older players | iOS share (Oct 2026) | Why | Watch out for |
| --- | --- | --- | --- | --- | --- |
| 1 | Australia | 67% of 65+ play (\~3.3M) | 62% | Home market, card/board is the top genre for 65+, Five Hundred (500) has a weak incumbent | Small market |
| 2 | United States | 31.5M Boomers play (ESA); 49% of 50+ (AARP) | 52% | Biggest pool, measured spending ($49 per six months) | Most crowded store; needs US card games (Gin Rummy, Euchre) |
| 3 | Canada | No age rate found; 35% of weekly players are 55+ | 65% | Highest iOS share, same English build | Québec wants French |
| 4 | New Zealand | 61% of 65+ play | 49% | Same tastes as AU; 500 and cryptics carry over | Tiny |
| 5 | United Kingdom | 25% of 65+ play (Ofcom) | 50% | English, strong cryptic-crossword culture | Lowest participation in the list |
| 6 | Japan or France | FR: 5.4M players 65+; JP: oldest player base surveyed | JP 54%, FR 36% | Large older audiences | Both need full translation |

Later, Android-led markets: Germany, Spain, Italy, Brazil, Mexico (iOS 26–39%), the Philippines (14%) and India (5%). Full figures and caveats are in `../research/games-for-older-adults.md` §8.

## Game lineup

Launch with six games that need little or no translation, and add regional card games one at a time once the shared card engine exists.

| Phase | Game | Why it's in | Shared engine |
| --- | --- | --- | --- |
| Launch | Solitaire (Klondike, Spider, FreeCell) | Most-played senior game worldwide, no words | Cards |
| Launch | Sudoku | Numbers only; puzzles can be generated | Grid |
| Launch | Word search | Easy, popular with 65+; English word list first | Grid |
| Launch | Jigsaw | Relaxing; new image packs over time | Pieces |
| Launch | Mahjong solitaire | Big in US, Europe and Asia; leader is ad-heavy | Tiles |
| Launch | Dominoes | Popular in Latin America, Spain and the US South | Tiles |
| Update 1 | Five Hundred (500) | Australia's national card game; weak competition | Cards + trick-taking AI |
| Update 2 | Gin Rummy, Euchre | US and Canada favourites | Cards |
| Later | Crossword / mini cryptic | Daily habit; strong in AU and UK | Grid + clue writing |
| Later, with translation | Belote (FR), Scopa (IT), Chinchón (ES), Tong-its (PH) | Regional favourites | Cards |

Regional card-game popularity is well-known tradition, not survey data.

## Design for seniors

Accessibility is the product, so build these in from day one and show them in the first App Store screenshot.

- **Text size setting 100–200%.** Apple asks for text that can grow to at least 200%. The app follows the iPhone's text size and adds its own Smaller/Bigger buttons in Settings.
- **Big cards, tiles and buttons.** Every control at least 44×44 pt; design cards and tiles at about 2× the usual size.
- **High contrast.** Text contrast 4.5:1 (3:1 for 18 pt or bold). Offer a high-contrast theme.
- **Never rely on colour alone.** Use shapes or symbols too, e.g. four-colour suits with clear symbols.
- **No timers, ever by default.** Unlimited undo and hints.
- **Tap to select, tap to place.** Drag is optional, and there are no multi-finger gestures.
- **Calm effects.** Respect Reduce Motion, let players turn off effects and background sound.
- **Easy start.** A one-screen "how to play", auto-save, and no penalty for leaving mid-game.
- **Clear words.** Labelled buttons, not icons alone. Avoid health claims like "prevents dementia"; "keeps your mind active" is safe.

## Monetisation model

Free to play with gentle ads, and one Remove Ads purchase. Every game is free; nothing is locked. Ad rules are tuned so seniors can't tap an ad by accident.

| Ad type | Where it shows | Rule |
| --- | --- | --- |
| Rewarded video (not built yet) | Player taps "Watch a short video for a free hint / extra deal / undo pack" | Always optional; the main earner |
| Interstitial (full screen) | Only between games, never mid-game | At most 1 every 3 games and 4 minutes; none in the first session or first 3 games. **Built** (`AdRules.swift`) |
| Banner (not built) | Bottom of menu screens only, not on the game board | Keep a clear gap from buttons; consider dropping it entirely |

**In-app purchases (Apple IAP only)**

| Product | Type | Price (AUD) | What it does |
| --- | --- | --- | --- |
| Remove Ads | Non-consumable, `com.sachiri.gamehaven.removeads` | A$0.99 (decided) | Removes all ads for good; Family Sharing on |
| Hint pack (optional) | Consumable | A$2.99 | 50 hints, for players who don't want to watch ads |

- Join Apple's **Small Business Program** so Apple takes 15% instead of 30%.
- No subscriptions at launch. Seniors dislike surprise renewals, and reviews punish them.
- No loot boxes, energy timers or multiple currencies.

## Ads setup, step by step

The app uses Google's own iOS SDKs (Google Mobile Ads and User Messaging Platform) through Swift Package Manager, listed in `ios/project.yml`. There is no plugin to install.

**A. AdMob account (done)**

1. AdMob account created; app **Game Haven** added for iOS.
2. **App ID:** `ca-app-pub-3607911339265372~1320298320`
3. **Interstitial unit "between games":** `ca-app-pub-3607911339265372/7644491539`. Leave the "real-time bidding on another mediation platform" box **unticked** when making units; an earlier unit made with it ticked (`…/7488578867`) can't serve AdMob ads and should be archived.
4. [ ] In **Privacy & messaging**, create and publish a GDPR message (EEA/UK/Switzerland) and a US state regulations message.

**B. Where the IDs live**

Both IDs are build settings in `ios/project.yml`. Debug builds use Google's test IDs; only the `Release:` block has the real ones, so testing from Xcode can't click live ads.

**C. Code (done, `ios/GameHaven/Ads.swift`)**

1. On every launch, request consent info (UMP) and show the form if required.
2. Only after consent: show the tracking (ATT) prompt, then start the ads SDK.
3. Load an interstitial and show it only when the player leaves the "game finished" screen, under the frequency cap in Monetisation.
4. Skip all ad loading and showing when the player owns Remove Ads.
5. Settings has a "Privacy settings" button that reopens the consent form where consent applies.
6. Not built: rewarded "watch a video for a hint" and banners.

**D. Test before release**

- Never tap ads in a Release or TestFlight build on your own phone; live clicks on your own ads can get the account banned. Use a Debug build from Xcode, which always shows test ads.
- Test consent with UMP's debug geography set to the EEA, then on a real iPhone through TestFlight.
- Expect few or no real ads until the app is live and the App Store listing is linked in AdMob.

**E. Later: mediation**

Once you have steady traffic, add AdMob mediation (e.g. AppLovin, Meta, Unity Ads) to raise fill rates and prices. Skip it at launch.

## Remove Ads purchase setup

Remove Ads is an Apple non-consumable, built with StoreKit 2 (`ios/GameHaven/Purchases.swift`). Settings has Remove Ads and Restore Purchases buttons; App Review rejects an IAP without Restore.

**A. App Store Connect**

1. Sign the **Paid Apps Agreement** and add bank and tax details (needs ABN and GST registration; see `../research/australia-business-setup.md` §4).
2. Apply for the **Small Business Program** (15% commission).
3. In the app, go to Monetization → In-App Purchases and create a **Non-Consumable** with product ID `com.sachiri.gamehaven.removeads`, price A$0.99, a display name and a review screenshot.
4. Create a **Sandbox tester** account for testing.

**B. How the code works**

1. On launch, it fetches the product to show its local price (never hard-coded; other countries see their own price).
2. On a verified purchase, it finishes the transaction and ads stop straight away.
3. **Restore Purchases** syncs with the App Store and re-reads what the player owns.
4. It checks owned purchases on every launch and listens for later changes (Ask to Buy approvals, Family Sharing, refunds), so a reinstall or a new iPhone stays ad-free.

**C. Test**

- In the simulator, `ios/GameHaven.storekit` (set as the scheme's StoreKit configuration) lets you buy and restore without App Store Connect.
- Then on a real iPhone via TestFlight with the sandbox tester.

## Privacy & compliance

Most App Store rejections for ad-funded games come from the items below. Tick them off before submitting.

- [x] **Consent (UMP):** consent requested on every launch, ads only after UMP allows them, and a Privacy settings button that reopens the form.
- [x] **App Tracking Transparency:** `NSUserTrackingUsageDescription` set in plain words (e.g. "This lets us show you ads that are more relevant. Your choice doesn't affect the game."). Ask after consent, not on the first screen.
- [x] **App Privacy label** in App Store Connect declares what the AdMob SDK collects (device ID, usage data, crash data, coarse location), and whether it's used for tracking.
- [ ] **Privacy manifest:** the AdMob and UMP SDKs ship their own; confirm they're in the archived build.
- [x] **SKAdNetworkItems** in Info.plist (`ios/project.yml`; Google's own network only until mediation).
- [ ] **app-ads.txt:** host it at the root of the developer website listed on the App Store page (GitHub Pages, from `docs/`), with the line AdMob gives you. Without it, many advertisers won't buy your ad space. (From memory; AdMob's console shows the exact line.)
- [x] **Privacy policy:** <https://carlabarintos.github.io/game-haven/privacy.html> (source `docs/privacy.html`, also shown in the app's Settings). Also the App Store Support URL.
- [x] **Not in the Kids category,** and age rating set honestly (all None except Advertising; override Not Applicable). Kids rules ban most ad SDKs.
- [ ] **No health claims** in the listing ("prevents dementia"); Apple and the ACCC can act on them.
- [ ] **GST:** Apple collects and pays GST on App Store sales in Australia, but the business still needs GST registration to sell paid apps or IAPs. Ad income from Google is a separate business income.

Note: Google stops publishing the UMP CocoaPod from 2 December 2026. We use the Swift Package instead, so this doesn't affect us.

## Launch checklist

Ship the six-game bundle in Australia first, watch reviews and ad complaints for a month, then open the US, Canada, NZ and UK.

1. ~~Build the launch games.~~ Done: seven games (Nonogram added), plus the Yuzu Springs village.
2. ~~Add the accessibility settings (text size, high contrast, no timers).~~ Done.
3. Set up the AdMob account, ad units and consent messages. Account and interstitial unit done; consent messages still to publish.
4. ~~Add the AdMob SDK with test IDs.~~ Done for between-games interstitials; rewarded hints not built.
5. ~~Create the Remove Ads IAP and the Restore button.~~ Done: `com.sachiri.gamehaven.removeads`, A$0.99, Family Sharing on. The App Store Connect product ID must match `Purchases.removeAdsID`.
6. Write the privacy policy, App Privacy label and app-ads.txt. Policy and label done; app-ads.txt after approval.
7. TestFlight with 5–10 older testers (family, friends, a local seniors' club). Watch for accidental ad taps and confusing screens.
8. ~~Submit.~~ Done Nov 21, 2026: 1.0 (build 2611190357) and Remove Ads submitted together, manual release. See *After approval* below.
9. After a month: check ad revenue per user, the Remove Ads buy rate and review complaints, then tune the ad frequency.
10. Update 1: Five Hundred (500). Then open the other English markets.

### After approval

1. **Release:** the version is set to manual release, so press **Release** on the 1.0 page in App Store Connect.
2. **Link AdMob to the store listing:** AdMob → Apps → Game Haven → App settings → link to the App Store. Real ads only fill properly once linked.
3. **app-ads.txt:** copy the line AdMob shows into `docs/app-ads.txt`, push, and check it loads at the root of the developer website on the store page. GitHub Pages serves this repo under `/game-haven/`, so the root file may need a user site (`carlabarintos.github.io`) repo or a custom domain.
4. **Consent messages:** publish the GDPR (EEA/UK/Switzerland) and US state regulations messages in AdMob → Privacy & messaging.
5. **Test the live app** on a real iPhone: buy Remove Ads, delete and reinstall, then Restore Purchases.
6. **If rejected:** read the Resolution Center message, fix, upload a new build, and resubmit from the same version page.

Store screenshots: compile the `*Logic.swift` files and `Save.swift` (as `ios/tests/run.sh` does) with a small script that writes each game's save (`Save.store`) for a mid-game board, copy the JSON into the simulator's `Library/Application Support/saves/`, and launch the Debug build with `-screen <game>` (or `settings` for the IAP review screenshot). Sizes: iPhone 18 Pro Max for 6.9", iPhone 18 Pro for 6.3", iPad Pro 13" for 13".

**Open questions**

- [ ] One app with all games, or separate apps per game (better search ranking per keyword)?
- [ ] Add a banner at all? (Not built; launching without one.)
- [x] Remove Ads price: A$0.99.

## Sources

- [IGEA / Bond, *Australia Plays 2025*](https://igea.net/ap25-report-28_08-with-links/) and [*New Zealand Plays 2025*](https://igea.net/wp-content/uploads/2025/09/NZP25-Report-Final.pdf)
- [ESA, 2025 Healthy Aging one-pager](https://www.theesa.com/wp-content/uploads/2025/09/2025-Healthy-Aging-One-Pager-09-03-25-Digital.pdf) and [*Power of Play 2025*](https://www.theesa.com/wp-content/uploads/2025/09/PoP-2025-v10-web-spreads.pdf)
- [AARP, *Play on Purpose* (2026)](https://www.aarp.org/pri/topics/technology/internet-media-devices/play-purpose-video-games-older-adults/) and [2023 gamers 50+ study](https://www.aarp.org/pri/topics/social-leisure/activities-interests/2023-gamers-50-plus/)
- [SELL / Médiamétrie, *L'Essentiel du jeu vidéo*, Sept 2025](https://www.sell.fr/sites/default/files/essentiel-jeu-video/ejv_septembre_2025_def_0.pdf)
- [Ofcom, *Adults' Media Use and Attitudes 2025*](https://www.ofcom.org.uk/siteassets/resources/documents/research-and-data/media-literacy-research/adults/adults-media-use-and-attitudes-2025/adults-media-use-and-attitudes-report-2025.pdf) (figure from a search extract)
- [StatCounter, mobile OS market share](https://gs.statcounter.com/os-market-share/mobile/) (Oct 2026)
- [Apple HIG, Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility)
- [Google AdMob iOS: test ads](https://developers.google.com/admob/ios/test-ads), [privacy (UMP)](https://developers.google.com/admob/ios/privacy), [quick start](https://developers.google.com/admob/ios/quick-start)
- Full research notes with every figure and caveat: `../research/games-for-older-adults.md` (§1–8)
