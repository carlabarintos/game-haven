# Senior Games App: Plan & Ads Setup

Nov 17, 2026 · @Carl

## Summary

We build one iOS app (Godot) with a bundle of calm, large-print puzzle and card games for people 55+, launching in Australia first, then the US, Canada, New Zealand and the UK. It is free with **light, player-friendly ads** (mostly opt-in rewarded ads, no ads mid-game), plus a one-time **Remove Ads** purchase at about A$9.99.

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

- **Text size setting 100–200%.** Apple asks for text that can grow to at least 200%. Godot doesn't follow iOS Dynamic Type automatically, so add an in-game slider.
- **Big cards, tiles and buttons.** Every control at least 44×44 pt; design cards and tiles at about 2× the usual size.
- **High contrast.** Text contrast 4.5:1 (3:1 for 18 pt or bold). Offer a high-contrast theme.
- **Never rely on colour alone.** Use shapes or symbols too, e.g. four-colour suits with clear symbols.
- **No timers, ever by default.** Unlimited undo and hints.
- **Tap to select, tap to place.** Drag is optional, and there are no multi-finger gestures.
- **Calm effects.** Respect Reduce Motion, let players turn off effects and background sound.
- **Easy start.** A one-screen "how to play", auto-save, and no penalty for leaving mid-game.
- **Clear words.** Labelled buttons, not icons alone. Avoid health claims like "prevents dementia"; "keeps your mind active" is safe.

## Monetisation model

Free to play with gentle ads, and one Remove Ads purchase that also unlocks everything. Ad rules are tuned so seniors can't tap an ad by accident.

| Ad type | Where it shows | Rule |
| --- | --- | --- |
| Rewarded video | Player taps "Watch a short video for a free hint / extra deal / undo pack" | Always optional; the main earner |
| Interstitial (full screen) | Only between games, never mid-game | At most 1 every 3 games or 4 minutes; none in the first session or first 3 games |
| Banner | Bottom of menu screens only, not on the game board | Keep a clear gap from buttons; consider dropping it entirely |

**In-app purchases (Apple IAP only)**

| Product | Type | Price (AUD, suggested) | What it does |
| --- | --- | --- | --- |
| Remove Ads + Unlock All | Non-consumable | A$9.99 | Removes banners and interstitials, unlocks every game; rewarded bonuses become free |
| Hint pack (optional) | Consumable | A$2.99 | 50 hints, for players who don't want to watch ads |

- Join Apple's **Small Business Program** so Apple takes 15% instead of 30%.
- No subscriptions at launch. Seniors dislike surprise renewals, and reviews punish them.
- No loot boxes, energy timers or multiple currencies.

## Ads setup, step by step

Use Google AdMob with the [Poing Studios AdMob plugin](https://store.godotengine.org/asset/poingstudios/admob/) for Godot. It covers iOS and Android, banner, interstitial and rewarded ads, Google's consent tool (UMP), and mediation. Use v5.0.0: the newest v5.1.0 (Sept 2026) is marked unstable, and the plugin needs Godot 4.5+.

**A. AdMob account (one time)**

1. Create an AdMob account at admob.google.com with the business Google account. Add payment details (bank account in AUD) and tax info.
2. Add the app: platform iOS. You can add it before it's on the App Store and link the store listing later.
3. Copy the **App ID** (format `ca-app-pub-xxxxxxxxxxxxxxxx~yyyyyyyyyy`).
4. Create three **ad units**: one Rewarded, one Interstitial, one Banner. Copy each **ad unit ID**.
5. In **Privacy & messaging**, create a GDPR consent message (EEA/UK/Switzerland) and a US state regulations message. Optionally add an IDFA explainer message shown before Apple's tracking prompt.

**B. Plugin in Godot**

1. In Godot's AssetLib, search "AdMob" by Poing Studios, then Download and Install.
2. Enable it: Project → Project Settings → Plugins. It downloads the native iOS/Android files itself. If that fails: Project → Tools → AdMob Manager → iOS → Download & Install.
3. Make sure the iOS template is in `res://ios/plugins`.
4. Open `res://ios/plugins/poing-godot-admob-ads.gdip` and set `GADApplicationIdentifier` to your App ID.
5. In Project → Export → iOS, tick the "Ad Mob" plugin. No manual Xcode or CocoaPods steps are needed.
6. Check that the exported Info.plist has `SKAdNetworkItems`, starting with Google's `cstr6suwn9.skadnetwork`, plus `NSUserTrackingUsageDescription` (the text in Apple's tracking prompt).

**C. Code: the order matters**

1. On every launch, request consent info (UMP), and show the consent form if required.
2. Only after consent: show the tracking (ATT) prompt, then initialise the ads SDK. Don't request ads until UMP says ads can be requested.
3. Load a rewarded ad in the background. Show it only when the player taps "Watch video for a hint", and grant the reward in the reward callback, not when the ad closes.
4. Load an interstitial and show it only on the "game finished" screen, under the frequency cap in Monetisation.
5. Skip all banner and interstitial calls when the player owns Remove Ads.
6. Add a "Privacy settings" button in Settings that reopens the consent form (Google requires one where consent applies).

**D. Test before release**

- Use Google's test ad unit IDs until launch. Clicking your own live ads can get the AdMob account banned.

| Format | iOS test ad unit ID |
| --- | --- |
| Banner (adaptive) | `ca-app-pub-3940256099942544/2435281174` |
| Interstitial | `ca-app-pub-3940256099942544/4411468910` |
| Rewarded | `ca-app-pub-3940256099942544/1712485313` |

- Test consent with UMP's debug geography set to the EEA, then on a real iPhone through TestFlight.
- Swap in your real ad unit IDs only in the release build.

**E. Later: mediation**

Once you have steady traffic, add AdMob mediation (e.g. AppLovin, Meta, Unity Ads) to raise fill rates and prices. The plugin supports all AdMob mediation networks. Skip it at launch.

## Remove Ads purchase setup

Sell Remove Ads as an Apple non-consumable, using the [godot-iap](https://hyochan.github.io/godot-iap) plugin (StoreKit 2, Godot 4.3+, iOS 15+, Xcode 16+). Add a Restore Purchases button, or App Review will reject the app.

**A. App Store Connect**

1. Sign the **Paid Apps Agreement** and add bank and tax details (needs ABN and GST registration; see `../research/australia-business-setup.md` §4).
2. Apply for the **Small Business Program** (15% commission).
3. In the app, go to Monetization → In-App Purchases and create a **Non-Consumable** with product ID `remove_ads_unlock_all`, price A$9.99, a display name and a review screenshot.
4. Create a **Sandbox tester** account for testing.

**B. Plugin in Godot**

1. Download `godot-iap-{version}.zip` from its GitHub Releases and copy `addons/godot-iap/` into the project's `addons/`.
2. Enable it: Project → Project Settings → Plugins.
3. Enable **GodotIap** in Project → Export → iOS → Plugins.
4. Add a Node with `addons/godot-iap/godot_iap.gd` attached, named `GodotIapWrapper`. In the editor it runs in mock mode, so you can build the UI without a device.

**C. Code**

1. On launch, fetch the product to show its local price (never hard-code "A$9.99"; other countries see their own price).
2. On purchase success, finish the transaction as non-consumable, save `ads_removed = true`, and hide ads straight away.
3. **Restore Purchases** in Settings: call `get_available_purchases()`, and if `remove_ads_unlock_all` is there, set `ads_removed = true`.
4. Also check owned purchases on every launch, so a reinstall or a new iPhone stays ad-free.

**D. Test**

- Test in the simulator with a StoreKit configuration file, then on a real iPhone via TestFlight with the sandbox tester. A Godot forum user reported a TestFlight build that never showed the payment sheet, so test early.

## Privacy & compliance

Most App Store rejections for ad-funded games come from the items below. Tick them off before submitting.

- [ ] **Consent (UMP):** consent requested on every launch, ads only after UMP allows them, and a Privacy settings button that reopens the form.
- [ ] **App Tracking Transparency:** `NSUserTrackingUsageDescription` set in plain words (e.g. "This lets us show you ads that are more relevant. Your choice doesn't affect the game."). Ask after consent, not on the first screen.
- [ ] **App Privacy label** in App Store Connect declares what the AdMob SDK collects (device ID, usage data, crash data, coarse location), and whether it's used for tracking.
- [ ] **Privacy manifest:** the AdMob and UMP SDKs ship their own; confirm they're in the exported Xcode project.
- [ ] **SKAdNetworkItems** in Info.plist (see Ads setup, step B6).
- [ ] **app-ads.txt:** host it at the root of the developer website listed on the App Store page, with the line AdMob gives you. Without it, many advertisers won't buy your ad space. (From memory; AdMob's console shows the exact line.)
- [ ] **Privacy policy URL** on the App Store page and in the app's Settings, naming Google AdMob.
- [ ] **Not in the Kids category,** and age rating set honestly. Kids rules ban most ad SDKs.
- [ ] **No health claims** in the listing ("prevents dementia"); Apple and the ACCC can act on them.
- [ ] **GST:** Apple collects and pays GST on App Store sales in Australia, but the business still needs GST registration to sell paid apps or IAPs. Ad income from Google is a separate business income.

Note: Google stops publishing the UMP CocoaPod from 2 December 2026. The Poing plugin downloads its own native files, so this should not affect us, but check after the next plugin update.

## Launch checklist

Ship the six-game bundle in Australia first, watch reviews and ad complaints for a month, then open the US, Canada, NZ and UK.

1. Build the shared card, grid and tile engines, then the six launch games.
2. Add the accessibility settings (text size, high contrast, no timers).
3. Set up the AdMob account, ad units and consent messages.
4. Add the AdMob plugin with test IDs, and add rewarded hints first.
5. Create the Remove Ads IAP and the Restore button.
6. Write the privacy policy, App Privacy label and app-ads.txt.
7. TestFlight with 5–10 older testers (family, friends, a local seniors' club). Watch for accidental ad taps and confusing screens.
8. Swap in real ad unit IDs and submit. Screenshot 1 shows the large text; the listing promises "Pay once, no ads".
9. After a month: check ad revenue per user, the Remove Ads buy rate and review complaints, then tune the ad frequency.
10. Update 1: Five Hundred (500). Then open the other English markets.

**Open questions**

- [ ] One app with all games, or separate apps per game (better search ranking per keyword)?
- [ ] Keep the banner or drop it entirely?
- [ ] A$9.99 or A$14.99 for Remove Ads + Unlock All?

## Sources

- [IGEA / Bond, *Australia Plays 2025*](https://igea.net/ap25-report-28_08-with-links/) and [*New Zealand Plays 2025*](https://igea.net/wp-content/uploads/2025/09/NZP25-Report-Final.pdf)
- [ESA, 2025 Healthy Aging one-pager](https://www.theesa.com/wp-content/uploads/2025/09/2025-Healthy-Aging-One-Pager-09-03-25-Digital.pdf) and [*Power of Play 2025*](https://www.theesa.com/wp-content/uploads/2025/09/PoP-2025-v10-web-spreads.pdf)
- [AARP, *Play on Purpose* (2026)](https://www.aarp.org/pri/topics/technology/internet-media-devices/play-purpose-video-games-older-adults/) and [2023 gamers 50+ study](https://www.aarp.org/pri/topics/social-leisure/activities-interests/2023-gamers-50-plus/)
- [SELL / Médiamétrie, *L'Essentiel du jeu vidéo*, Sept 2025](https://www.sell.fr/sites/default/files/essentiel-jeu-video/ejv_septembre_2025_def_0.pdf)
- [Ofcom, *Adults' Media Use and Attitudes 2025*](https://www.ofcom.org.uk/siteassets/resources/documents/research-and-data/media-literacy-research/adults/adults-media-use-and-attitudes-2025/adults-media-use-and-attitudes-report-2025.pdf) (figure from a search extract)
- [StatCounter, mobile OS market share](https://gs.statcounter.com/os-market-share/mobile/) (Oct 2026)
- [Apple HIG, Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility)
- [Poing Studios AdMob plugin (Godot Asset Store)](https://store.godotengine.org/asset/poingstudios/admob/) and [GitHub](https://github.com/poingstudios/godot-admob-plugin)
- [godot-iap docs](https://hyochan.github.io/godot-iap)
- [Google AdMob iOS: test ads](https://developers.google.com/admob/ios/test-ads), [privacy (UMP)](https://developers.google.com/admob/ios/privacy), [quick start](https://developers.google.com/admob/ios/quick-start)
- Full research notes with every figure and caveat: `../research/games-for-older-adults.md` (§1–8)
