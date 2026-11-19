# Home Screen: Yuzu Springs Village

Nov 17, 2026 · decided: Option C (2.5D onsen village with animal visitors)

The home screen is a small Japanese hot-spring village drawn in 2.5D. Each game is a place in the village. Playing earns stars, and stars grow the village on their own: nothing to spend, nothing to tap.

Mock-ups (all three options, C is the chosen one): https://claude.ai/artifact/MkX6ZeQ7KaLrAswJgvfm9n

## Places

| Place | Game |
| --- | --- |
| Hot Spring (onsen) | Sudoku |
| Maple Cabin | Solitaire |
| Pine Cabin | Dominoes |
| Tea House | Mahjong |
| Bookshop | Word Search |
| Koi Pond | Jigsaw |
| Wooden sign at the entrance | Settings |

Every place has a cream plaque: game name large (20 pt+), place name small above it. Labels are words, never pictures alone. All games are open from day one; stars only add charm.

## Stars and growth

One currency, stars, earned by playing and never sold (matches the plan's "no multiple currencies" rule). Sudoku gives 1 / 2 / 3 stars for Easy / Medium / Hard, plus 1 bonus star for a win with no wrong numbers (hints are fine). Word Search and Mahjong give 1 / 2 / 3 stars for Easy / Medium / Hard, with no bonus star. Stars are only ever added, never taken away for mistakes or time.

| Stars | Village gains |
| --- | --- |
| 0 | A quiet valley |
| 1 | A little hot spring |
| 3 | Stone lanterns |
| 10 | Cherry trees with falling petals |
| 15 | Koi and a red bridge |
| 28 | Paper lanterns |
| 45 | Fireflies |

Later: seasons (autumn maples, winter snow), or a new place per chapter.

## Animal visitors

Original characters based on folklore animals, in yukata or with props: tanuki in a straw hat, fox in a blue yukata, rabbit with a basket, shiba with a red scarf, calico cat with tea, snow monkey with an onsen towel, Nara deer with little antlers, moon bear with a honey pot. More visitors come with each stage (all eight by the last), picked at random each time the screen opens; two that pass close may stop and bow to each other. Each picks a random path, speed and start every time the screen opens. In SpriteKit they also stop, sit in the hot spring, sip tea, nap, and wave when tapped. They are not copies of any existing game's characters.

## Look

- Soft watercolour / gouache, visible brush texture, no outlines or gloss.
- Colours: washi cream `#FFF6E6` plaques, sumi ink `#33261C` text, vermilion `#C8433A`, sakura `#F2B8C2`, moss `#A9C58F`, spring water `#9CCFCF`, roof tile `#4A4A55`, yuzu gold `#E2A93B`.
- Fonts: Shippori Mincho B1 for the village name, Nunito for labels.
- Sky and lamps follow the phone's clock: morning, golden afternoon, evening.
- Calm motion only: steam, petals, koi, swaying lanterns, fireflies, walking visitors. Everything stops with Reduce Motion.

## How it is built

- SpriteKit (built into iOS, free). Blender optional, only to keep painted layers consistent.
- Painted art arrives as PNG pieces: each building, tree, prop and per-stage layer separately, and a few frames per animal (walk, sit, wave). Until then the app draws stand-ins, and each painted file replaces its stand-in with no code change.
- Visitors are depth-sorted so they walk behind and in front of buildings.
- Pause animation after about a minute without a touch, to save battery.

## Status

- Built: stars and stages (`ios/GameHaven/Village/Village.swift`), stars from Sudoku wins, and the SpriteKit village on the home screen (`VillageScene.swift`) with stand-in shapes, every stage layer, wandering visitors (emoji stand-ins, wave when tapped), clock-based sky, Reduce Motion and the one-minute idle pause. Plaques are real SwiftUI buttons; the largest text sizes get a plain list instead.
- Art: `ios/art/village.py` builds the village in Blender (orthographic 2:1 camera mapped exactly to the board) and renders `ground`, `place-<id>`, `village-2/4/5` and a night-only `lights` layer into `ios/GameHaven/Village/Art/` at @3x. Re-run it in Blender after changing the model, then `xcodegen`. The app tints painted layers for the time of day.
- Visitors: `ios/art/visitors.py` models them in Blender and renders `visitor-<id>-front-0…3`, `-back-0…3` and `-wave` (64-pt frames at @3x). The app plays the walk cycle while moving, mirrors for leftward, stands still when resting, and stops to wave when tapped.
- Next: painted steam and paper lanterns (stages 1 and 7), and visitors sitting in the spring / sipping tea / napping.
