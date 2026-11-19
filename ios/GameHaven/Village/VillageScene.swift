import SpriteKit
import SwiftUI

/// The village in SpriteKit, drawn on the mock-up's 390×844 board.
/// A painted PNG replaces a stand-in with no code change: `place-<id>` for a building, `village-N` for a stage's layer.
struct VillageView: View {
    let stage: Int
    /// Fill the frame and trim the edges (small previews), instead of showing the whole board.
    var crop = false
    @State private var scene = VillageScene()

    var body: some View {
        SpriteView(scene: scene, options: [.allowsTransparency])
            .background(Color(uiColor: VillageScene.Sky.now.grass))
            .onAppear {
                scene.scaleMode = crop ? .aspectFill : .aspectFit
                scene.stage = stage
            }
            .onChange(of: stage) { scene.stage = stage }
            .accessibilityElement()
            .accessibilityLabel("Your village: " + (stage == 0 ? Village.stages[0].name : Village.stages[1...stage].map(\.name).joined(separator: ", ")))
    }
}

final class VillageScene: SKScene {
    static let board = CGSize(width: 390, height: 844)

    /// Sky, grass and lamps follow the phone's clock.
    struct Sky {
        let top, bottom, farHill, midHill, grass, path, water, shoji, sun: UIColor
        let night: Bool

        static var now: Sky {
            switch Calendar.current.component(.hour, from: .now) {
            case 5..<12: Sky(top: c(0xBFDCE6), bottom: c(0xEEF0E2), farHill: c(0xA9B8CF), midHill: c(0x8FAE8C), grass: c(0xA9C58F),
                             path: c(0xE6D9C0), water: c(0x9CCFCF), shoji: c(0xF4EEDF), sun: c(0xFFE7A8), night: false)
            case 12..<18: Sky(top: c(0xF2B88A), bottom: c(0xF8DDB4), farHill: c(0xC7A3AE), midHill: c(0x9FA67E), grass: c(0xB5BE86),
                              path: c(0xEBD6B4), water: c(0xA8CCC4), shoji: c(0xFBE8BE), sun: c(0xFFC873), night: false)
            default: Sky(top: c(0x1C2545), bottom: c(0x4A4468), farHill: c(0x2E3557), midHill: c(0x3C4C55), grass: c(0x55684F),
                         path: c(0x8E8573), water: c(0x4F7187), shoji: c(0xFFD98A), sun: c(0xF7EBC8), night: true)
            }
        }
    }

    /// Walking routes, as cubic Bézier points: start, then (control, control, end) for each curve.
    private static let routes: [[CGPoint]] = ([
        [(200, 870), (195, 810), (250, 790), (240, 750), (230, 712), (175, 692), (195, 645), (212, 610), (210, 560), (200, 520),
         (190, 488), (118, 478), (110, 440), (102, 400), (140, 370), (172, 345), (200, 322), (214, 292), (236, 252)],
        [(-40, 612), (40, 596), (110, 604), (160, 614), (220, 626), (250, 690), (300, 690), (340, 690), (380, 660), (430, 650)],
        [(430, 372), (360, 366), (330, 346), (290, 336), (250, 326), (220, 352), (172, 345), (130, 340), (60, 386), (-40, 378)],
    ] as [[(CGFloat, CGFloat)]]).map { $0.map { p($0) } }

    /// The visitors (visitor-<id>-… frames from ios/art/visitors.py), picked at random. More come with each stage, all eight by the last.
    private static let visitors = ["tanuki", "fox", "rabbit", "shiba", "cat", "monkey", "deer", "bear"]

    private struct Walker {
        let node: SKNode
        let body: SKSpriteNode
        let id: String
        var last: CGPoint
        var facing = "front"
        var state = ""
        var greeted: TimeInterval = 0
    }

    var stage = -1 {
        didSet { if stage != oldValue { build() } }
    }

    private var walkers: [Walker] = []
    private var lastTouch: TimeInterval = 0
    private let still = UIAccessibility.isReduceMotionEnabled

    override init() {
        super.init(size: Self.board)
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: Drawing

    private func build() {
        removeAllChildren()
        walkers = []
        let sky = Sky.now

        let skyNode = SKSpriteNode(texture: gradient([sky.top, sky.bottom], height: 240), size: CGSize(width: 390, height: 240))
        skyNode.anchorPoint = CGPoint(x: 0, y: 1)
        skyNode.position = p(0, 0)
        add(skyNode, z: -30)
        if sky.night {
            for _ in 0..<40 {
                let star = dot(c(0xFFF6E6), r: .random(in: 0.6...1.5), at: p(.random(in: 0...390), .random(in: 0...190)))
                star.alpha = .random(in: 0.4...1)
                add(star, z: -29.5)
                animate(star, .repeatForever(.sequence([.fadeAlpha(to: 0.2, duration: .random(in: 1.5...3)), .fadeAlpha(to: 1, duration: .random(in: 1.5...3))])))
            }
        } else {
            for (x, y, w) in [(60.0, 120.0, 70.0), (250.0, 60.0, 90.0), (380.0, 150.0, 60.0)] {
                let cloud = SKNode()
                for (dx, dy, r) in [(-w / 3, 4.0, w / 5), (0.0, -2.0, w / 4), (w / 3, 4.0, w / 6)] { cloud.addChild(dot(c(0xFFFFFF, 0.75), r: r, at: CGPoint(x: dx, y: dy))) }
                cloud.position = p(x, y)
                add(cloud, z: -29.5)
                animate(cloud, .repeatForever(.sequence([.moveBy(x: 460 - x, y: 0, duration: (460 - x) * 0.6), .moveBy(x: -500, y: 0, duration: 0),
                                                         .moveBy(x: x + 40, y: 0, duration: (x + 40) * 0.6)])))
            }
        }
        // Sun or moon sits right of the village sign, clear of the star line.
        add(glow(sky.sun.withAlphaComponent(0.5), r: 46, at: p(350, 112)), z: -29.2)
        add(dot(sky.sun, r: sky.night ? 15 : 19, at: p(350, 112)), z: -29)
        add(shape([(-10, 196), (50, 140), (100, 168), (180, 104), (250, 160), (300, 132), (400, 190), (400, 260), (-10, 260)], sky.farHill), z: -28)
        add(shape([(-10, 214), (90, 186), (170, 204), (260, 214), (400, 192), (400, 300), (-10, 300)], sky.midHill), z: -27)
        if let ground = painted("ground", sky) {
            add(ground, z: -26)
        } else {
            standInGround(sky)
        }

        // The places. z is the front corner's distance down the board, so nearer things cover farther ones.
        place("tea", house(110, 300, a: 56, b: 40, h: 34, r: 26, walls: (0xD6BC94, 0xEAD5B2), roof: (0x3A3A44, 0x4A4A55), noren: 0x2F4A6E, sky), z: 300, sky)
        place("books", house(300, 270, a: 48, b: 36, h: 30, r: 22, walls: (0xC4A57B, 0xDCC19A), roof: (0x46372B, 0x5A4636), noren: 0x3F6E4E, sky), z: 270, sky)
        place("bath", house(262, 388, a: 34, b: 28, h: 24, r: 18, walls: (0xB8936A, 0xCDAA80), roof: (0x2F4A50, 0x3E5E66), noren: 0xC8433A, sky, window: false), z: 388, sky)
        place("spring", spring(sky), z: 394, sky)
        place("maple", house(76, 545, a: 42, b: 32, h: 28, r: 20, walls: (0xA67A50, 0xBD9064), roof: (0x6E2F22, 0x8E3E2C), noren: nil, sky), z: 545, sky)
        place("pine", house(312, 612, a: 42, b: 32, h: 28, r: 20, walls: (0xB8936A, 0xCDAA80), roof: (0x2E4834, 0x3E5E46), noren: 0x8E2F2A, sky), z: 612, sky)
        place("pond", pond(sky), z: 676, sky)
        // Neon billboards bolted to the walls, Tokyo-style, in each game's plaque colour. (x, y) is the sign's top centre.
        for (text, neon, x, y) in [("茶屋", 0x7CFF8A, 172.0, 236.0), ("本屋", 0x3FE0FF, 356.0, 214.0), ("ゆ", 0xFFD84A, 303.0, 346.0),
                                   ("紅葉", 0xFF4F7B, 42.0, 472.0), ("松屋", 0xC77DFF, 363.0, 546.0)] as [(String, UInt32, CGFloat, CGFloat)] {
            add(billboard(text, c(neon), x, y, sky), z: 880)  // over the houses, under the stage layers
        }
        // Lit windows of the painted houses, after dark only. Untinted, so they glow against the night tint.
        if sky.night, UIImage(named: "lights") != nil {
            let lights = SKSpriteNode(imageNamed: "lights")
            lights.anchorPoint = .zero
            add(lights, z: 899)
        }

        for i in Village.stages.indices.dropFirst() where i <= stage {
            let art = painted(Village.stages[i].image, sky)
            if let art { add(art, z: 900 + CGFloat(i)) }  // shortcut: drawn over the visitors too; split per prop if that shows
            layer(Village.stages[i].image, sky, painted: art != nil)
        }

        for (i, id) in Self.visitors.shuffled().prefix(stage + stage / 3).enumerated() {
            walk(id, route: Self.routes[(i + Int.random(in: 0..<3)) % 3])
        }
        lastTouch = 0
        view?.isPaused = false
    }

    /// Meadow, paths and trees as flat shapes, until ground.png exists.
    private func standInGround(_ sky: Sky) {
        let grass = shape([(-10, 228), (120, 206), (230, 216), (320, 208), (400, 206), (400, 900), (-10, 900)], .white)
        grass.fillTexture = gradient([mix(sky.grass, sky.midHill, 0.4), sky.grass, mix(sky.grass, .black, 0.12)], height: 700)
        add(grass, z: -26)
        // A row of far pines along the meadow's top edge.
        let ridge: [(CGFloat, CGFloat)] = [(-10, 228), (120, 206), (230, 216), (320, 208), (400, 206)]
        for x in stride(from: CGFloat(-6), to: 400, by: 11) {
            let i = ridge.lastIndex { $0.0 <= x }!, a = ridge[i], b = ridge[min(i + 1, ridge.count - 1)]
            let y = a.1 + (b.1 - a.1) * (x - a.0) / max(b.0 - a.0, 1) + 3, h = CGFloat.random(in: 9...17), w = CGFloat.random(in: 5...7)
            add(shape([(x - w, y), (x + w, y), (x, y - h)], mix(sky.midHill, .black, 0.25)), z: -25.5)
        }
        for route in Self.routes {
            for (width, color) in [(21.0, mix(sky.path, .black, 0.18)), (16.0, sky.path)] {
                let road = SKShapeNode(path: curve(route))
                road.strokeColor = color
                road.lineWidth = width
                road.lineCap = .round
                add(road, z: width == 16 ? -20 : -21)
            }
        }
        for (x, y) in [(22.0, 312.0), (376.0, 336.0), (300.0, 470.0), (16.0, 740.0), (372.0, 520.0)] { add(pine(x, y, sky), z: y) }
        for (x, y) in [(244.0, 470.0), (180.0, 590.0), (262.0, 760.0), (360.0, 700.0), (70.0, 640.0), (140.0, 280.0)] { add(bush(x, y, sky), z: y) }
    }

    /// A stage's motion, plus flat stand-ins for its props until its painted village-N.png exists.
    private func layer(_ image: String, _ sky: Sky, painted: Bool) {
        let glow: CGFloat = sky.night ? 1 : 0.3
        switch image {
        case "village-1":  // steam over the spring
            for k in 0..<3 {
                let puff = dot(c(0xFFFFFF, 0.7), r: 9, at: p(185 + CGFloat(k) * 15, 420))
                add(puff, z: 470)
                puff.alpha = 0
                animate(puff, .sequence([.wait(forDuration: Double(k) * 1.3), .repeatForever(.sequence([
                    .group([.moveBy(x: 0, y: 30, duration: 4), .sequence([.fadeAlpha(to: 0.8, duration: 1.4), .fadeOut(withDuration: 2.6)])]),
                    .moveBy(x: 0, y: -30, duration: 0),
                ]))]))
            }
        case "village-2":  // stone lanterns
            for (x, y) in [(171.0, 800.0), (275.0, 772.0), (157.0, 566.0)] {
                if painted {
                    if sky.night { add(self.glow(c(0xFFD27A, 0.6), r: 24, at: p(x, y - 16)), z: y) }
                    continue
                }
                let lantern = SKNode()
                lantern.addChild(shape([(x - 7, y), (x + 7, y), (x + 7, y - 6), (x + 3, y - 6), (x + 3, y - 16), (x + 9, y - 16), (x + 3, y - 24),
                                        (x - 9, y - 24), (x - 15, y - 16), (x - 9, y - 16), (x - 3, y - 16), (x - 3, y - 6), (x - 7, y - 6)], c(0x9C968A)))
                lantern.addChild(shape([(x - 4, y - 16), (x + 4, y - 16), (x + 4, y - 10), (x - 4, y - 10)], c(0xFFD27A, glow)))
                if sky.night { lantern.addChild(self.glow(c(0xFFD27A, 0.6), r: 24, at: p(x, y - 13))) }
                add(lantern, z: y)
            }
        case "village-4":  // cherry trees with falling petals
            for (x, y) in [(30.0, 404.0), (362.0, 470.0), (207.0, 226.0)] {
                let tree = SKNode()
                if !painted { add(tree, z: y) }
                tree.addChild(shape([(x - 3, y), (x + 3, y), (x + 2, y - 30), (x - 2, y - 30)], c(0x6B4A33)))
                for (dx, dy, r, col) in [(-10.0, -36.0, 18.0, 0xF2B8C2), (10.0, -42.0, 16.0, 0xEFA8B6), (0.0, -54.0, 14.0, 0xF7CDD4)] {
                    tree.addChild(dot(c(UInt32(col)), r: r, at: p(x + dx, y + dy)))
                }
                let petal = SKShapeNode(ellipseOf: CGSize(width: 8, height: 5))
                petal.fillColor = c(0xF2B8C2)
                petal.strokeColor = .clear
                petal.position = p(x, y - 40)
                add(petal, z: 950)
                petal.alpha = 0
                animate(petal, .sequence([.wait(forDuration: .random(in: 0...8)), .repeatForever(.sequence([
                    .fadeIn(withDuration: 0.5),
                    .group([.moveBy(x: -60, y: -400, duration: 15), .rotate(byAngle: 5, duration: 15), .sequence([.wait(forDuration: 12), .fadeOut(withDuration: 3)])]),
                    .moveBy(x: 60, y: 400, duration: 0),
                ]))]))
            }
        case "village-5":  // koi and a red bridge
            for (radius, look, seconds) in [(30.0, 0xF08A3C, 13.0), (-22.0, 0xFFF6E6, -18.0)] {
                let swim = SKNode()
                swim.position = p(105, 705)
                swim.yScale = 0.5
                let fish = SKShapeNode(ellipseOf: CGSize(width: 18, height: 8))
                fish.fillColor = c(UInt32(look))
                fish.strokeColor = .clear
                fish.position = CGPoint(x: 0, y: radius)
                swim.addChild(fish)
                add(swim, z: 690)
                animate(swim, .repeatForever(.rotate(byAngle: .pi * 2, duration: seconds)))
            }
            if painted { break }
            let bridge = CGMutablePath()
            bridge.move(to: p(70, 724))
            bridge.addQuadCurve(to: p(142, 690), control: p(104, 686))
            let arch = SKShapeNode(path: bridge)
            arch.strokeColor = c(0xC8433A)
            arch.lineWidth = 7
            arch.lineCap = .round
            add(arch, z: 724)
        case "village-7":  // paper lanterns on a string by the spring
            let string = SKShapeNode(path: curve([p(140, 352), p(170, 362), p(230, 362), p(262, 350)]))
            string.strokeColor = c(0x3B2A1E)
            string.lineWidth = 1.5
            add(string, z: 395)
            for k in 0..<5 {
                let lantern = SKNode()
                lantern.position = p(152 + CGFloat(k) * 24, 359)
                let paper = SKShapeNode(rectOf: CGSize(width: 9, height: 12), cornerRadius: 4)
                paper.fillColor = sky.night ? c(0xF5A35C) : c(0xC8433A)
                paper.strokeColor = .clear
                paper.position = CGPoint(x: 0, y: -7)
                lantern.addChild(paper)
                add(lantern, z: 396)
                animate(lantern, .repeatForever(.sequence([.rotate(toAngle: 0.09, duration: 1.8), .rotate(toAngle: -0.09, duration: 1.8)])))
            }
        case "village-9":  // fireflies, brightest at night
            for _ in 0..<12 {
                let fly = dot(c(0xFFE38A), r: 2, at: p(.random(in: 20...370), .random(in: 300...800)))
                fly.alpha = sky.night ? 1 : 0.4
                add(fly, z: 960)
                animate(fly, .repeatForever(.sequence([
                    .group([.fadeAlpha(to: 0.15, duration: 1.3), .moveBy(x: .random(in: -12...12), y: .random(in: -8...8), duration: 1.3)]),
                    .fadeAlpha(to: sky.night ? 1 : 0.4, duration: 1.3),
                ])))
            }
        default: break
        }
    }

    /// A 2.5D box with a gable roof; (x, y) is the front corner on the ground.
    private func house(_ x: CGFloat, _ y: CGFloat, a: CGFloat, b: CGFloat, h: CGFloat, r: CGFloat, walls: (UInt32, UInt32), roof: (UInt32, UInt32),
                       noren: UInt32?, _ sky: Sky, window: Bool = true) -> SKNode {
        typealias P = (CGFloat, CGFloat)
        let B: P = (x, y), L: P = (x - b, y - b / 2), R: P = (x + a, y - a / 2), K: P = (x + a - b, y - a / 2 - b / 2)
        func up(_ q: P, _ d: CGFloat) -> P { (q.0, q.1 - d) }
        func mid(_ q: P, _ s: P) -> P { ((q.0 + s.0) / 2, (q.1 + s.1) / 2) }
        func ext(_ q: P, _ from: P) -> P { (q.0 + (q.0 - from.0) * 0.3, q.1 + (q.1 - from.1) * 0.3) }
        func lerp(_ q: P, _ s: P, _ f: CGFloat) -> P { (q.0 + (s.0 - q.0) * f, q.1 + (s.1 - q.1) * f) }
        func quad(_ q: P, _ s: P, _ f1: CGFloat, _ f2: CGFloat, _ z1: CGFloat, _ z2: CGFloat) -> [P] {
            [up(lerp(q, s, f1), z1), up(lerp(q, s, f2), z1), up(lerp(q, s, f2), z2), up(lerp(q, s, f1), z2)]
        }
        let Bh = up(B, h), Lh = up(L, h), Rh = up(R, h), Kh = up(K, h)
        let M1 = up(mid(Bh, Lh), r), M2 = up(mid(Rh, Kh), r)
        let node = SKNode()
        node.addChild(shape([L, B, R, K].map { ($0.0 + 8, $0.1 + 4) }, c(0x000000, 0.13)))
        node.addChild(shape([ext(Lh, M1), ext(Kh, M2), M2, M1], c(roof.0)))
        node.addChild(shape([L, B, Bh, Lh], c(walls.0)))
        node.addChild(shape([B, R, Rh, Bh], c(walls.1)))
        node.addChild(shape([Lh, Bh, M1], c(walls.0)))
        if window { node.addChild(shape(quad(L, B, 0.22, 0.72, h * 0.35, h * 0.8), sky.shoji)) }
        if window && sky.night { node.addChild(glow(c(0xFFC870, 0.45), r: 30, at: p(up(lerp(L, B, 0.47), h * 0.58)))) }
        node.addChild(shape(quad(B, R, 0.5, 0.8, 0, h * 0.72), c(0x5E3B26)))
        if let noren { node.addChild(shape(quad(B, R, 0.5, 0.8, h * 0.45, h * 0.72), c(noren))) }
        node.addChild(shape([ext(Bh, M1), ext(Rh, M2), M2, M1], c(roof.1)))
        return node
    }

    /// A vertical neon sign on a wall bracket, flickering now and then.
    private func billboard(_ text: String, _ neon: UIColor, _ x: CGFloat, _ y: CGFloat, _ sky: Sky) -> SKNode {
        let node = SKNode(), h = CGFloat(text.count) * 15 + 8
        node.addChild(shape([(x - 12, y - 2), (x + 12, y - 2), (x + 12, y + 1), (x - 12, y + 1)], c(0x2A2A30)))
        node.addChild(glow(neon.withAlphaComponent(sky.night ? 0.55 : 0.3), r: h * 0.9, at: p(x, y + h / 2)))
        let board = SKShapeNode(rectOf: CGSize(width: 20, height: h), cornerRadius: 3)
        board.fillColor = c(0x16112A, 0.95)
        board.strokeColor = neon
        board.lineWidth = 1.5
        board.glowWidth = 2
        board.position = p(x, y + h / 2)
        node.addChild(board)
        let label = SKLabelNode(text: text.map(String.init).joined(separator: "\n"))
        label.numberOfLines = 0
        label.fontName = "HiraKakuProN-W6"
        label.fontSize = 13
        label.fontColor = neon
        label.verticalAlignmentMode = .center
        label.position = board.position
        node.addChild(label)
        animate(node, .repeatForever(.sequence([.wait(forDuration: 4, withRange: 6), .fadeAlpha(to: 0.5, duration: 0.05),
                                                .fadeAlpha(to: 1, duration: 0.05), .fadeAlpha(to: 0.6, duration: 0.05), .fadeAlpha(to: 1, duration: 0.08)])))
        return node
    }

    private func spring(_ sky: Sky) -> SKNode {
        let node = SKNode()
        node.addChild(shape([(130, 428), (200, 462), (270, 428), (270, 438), (200, 472), (130, 438)], c(0x6F6A62)))
        node.addChild(shape([(130, 428), (200, 394), (270, 428), (200, 462)], c(0x8A857A)))
        node.addChild(shape([(142, 428), (200, 400), (258, 428), (200, 456)], sky.water))
        node.addChild(shimmer([(180, 420, 22), (214, 432, 16), (196, 444, 12)]))
        for (x, y, r) in [(132.0, 428.0, 9.0), (268, 430, 10), (200, 464, 9), (164, 448, 7), (238, 448, 8), (170, 406, 6)] {
            node.addChild(dot(c(0x9C968A), r: r, at: p(x, y)))
        }
        return node
    }

    private func pond(_ sky: Sky) -> SKNode {
        let node = SKNode()
        node.addChild(shape([(47, 705), (105, 676), (163, 705), (105, 734)], c(0x8A857A)))
        node.addChild(shape([(57, 705), (105, 681), (153, 705), (105, 729)], sky.water))
        node.addChild(shimmer([(92, 698, 18), (122, 712, 12)]))
        node.addChild(dot(c(0x9C968A), r: 7, at: p(50, 706)))
        node.addChild(dot(c(0xA7A196), r: 8, at: p(160, 707)))
        return node
    }

    private func pine(_ x: CGFloat, _ y: CGFloat, _ sky: Sky) -> SKNode {
        let node = SKNode()
        node.addChild(dot(c(0x000000, 0.13), r: 9, at: p(x + 5, y + 1)))
        node.addChild(shape([(x - 2, y), (x + 2, y), (x + 2, y - 8), (x - 2, y - 8)], c(0x5A3E2B)))
        for (k, dark) in [(0.0, 0.3), (1.0, 0.2), (2.0, 0.1)] {
            let base = y - 6 - k * 10, w = 14 - k * 3.5
            node.addChild(shape([(x - w, base), (x + w, base), (x, base - 16)], mix(sky.grass, .black, dark + 0.15)))
        }
        return node
    }

    private func bush(_ x: CGFloat, _ y: CGFloat, _ sky: Sky) -> SKNode {
        let node = SKNode()
        for (dx, dy, r, dark) in [(-7.0, -4.0, 7.0, 0.28), (7.0, -4.0, 6.0, 0.28), (0.0, -8.0, 7.5, 0.18)] {
            node.addChild(dot(mix(sky.grass, .black, dark), r: r, at: p(x + dx, y + dy)))
        }
        return node
    }

    /// Soft light streaks on water.
    private func shimmer(_ lines: [(CGFloat, CGFloat, CGFloat)]) -> SKNode {
        let node = SKNode()
        for (x, y, w) in lines {
            let line = SKShapeNode(rectOf: CGSize(width: w, height: 2), cornerRadius: 1)
            line.fillColor = c(0xFFFFFF, 0.55)
            line.strokeColor = .clear
            line.position = p(x, y)
            node.addChild(line)
            animate(line, .repeatForever(.sequence([.fadeAlpha(to: 0.2, duration: .random(in: 1.5...2.5)), .fadeAlpha(to: 1, duration: .random(in: 1.5...2.5))])))
        }
        return node
    }

    /// Uses `place-<id>.png` when it exists, else the stand-in.
    private func place(_ id: String, _ standIn: SKNode, z: CGFloat, _ sky: Sky) {
        add(painted("place-\(id)", sky) ?? standIn, z: z)
    }

    /// A painted layer drawn on the full board (so it lines up), tinted for the time of day. Rendered by ios/art/village.py.
    private func painted(_ name: String, _ sky: Sky) -> SKSpriteNode? {
        guard UIImage(named: name) != nil else { return nil }
        let node = SKSpriteNode(imageNamed: name)
        node.anchorPoint = .zero
        node.color = sky.night ? c(0x26305A) : sky.top
        node.colorBlendFactor = sky.night ? 0.5 : 0.12
        return node
    }

    // MARK: Visitors

    private func walk(_ id: String, route: [CGPoint]) {
        let walker = SKNode()
        let body = SKSpriteNode(imageNamed: "visitor-\(id)-front-0")
        body.anchorPoint = CGPoint(x: 0.5, y: 0.125)  // feet sit 8 of the frame's 64 points up
        body.name = "visitor"
        walker.addChild(body)
        walker.position = route[Int.random(in: 1..<route.count - 1)]
        add(walker, z: 0)
        walkers.append(Walker(node: walker, body: body, id: id, last: walker.position))
        guard !still else { return }

        let speed = CGFloat.random(in: 12...22)
        let rest = SKAction.wait(forDuration: 3, withRange: 4)
        let path = curve(route)
        walker.alpha = 0
        walker.position = route[0]
        walker.run(.repeatForever(.sequence([
            .follow(path, asOffset: false, orientToPath: false, speed: speed), rest,
            .follow(path, asOffset: false, orientToPath: false, speed: speed).reversed(), rest,
        ])), withKey: "route")
        // Skip ahead a random way along so visitors start spread out, then fade in.
        walker.speed = 100
        run(.sequence([.wait(forDuration: .random(in: 0.05...0.4)), .run { walker.speed = 1; walker.run(.fadeIn(withDuration: 0.6)) }]))
    }

    /// Frames face down-right ("front") or up-right ("back"); walking left mirrors them.
    private func frames(_ id: String, _ facing: String) -> [SKTexture] {
        (0..<4).map { SKTexture(imageNamed: "visitor-\(id)-\(facing)-\($0)") }
    }

    override func update(_ currentTime: TimeInterval) {
        for i in walkers.indices {
            let w = walkers[i], at = w.node.position
            w.node.zPosition = Self.board.height - at.y
            let dx = at.x - w.last.x, dy = at.y - w.last.y
            walkers[i].last = at
            if w.body.action(forKey: "wave") != nil { continue }
            let moving = abs(dx) + abs(dy) > 0.01
            if moving {
                walkers[i].facing = dy > 0 ? "back" : "front"  // heading up the screen shows their back
                if abs(dx) > 0.02 { w.body.xScale = dx < 0 ? -1 : 1 }
            }
            let state = (moving ? "walk-" : "stand-") + walkers[i].facing
            guard state != w.state else { continue }
            walkers[i].state = state
            let steps = frames(w.id, walkers[i].facing)
            if moving {
                w.body.run(.repeatForever(.animate(with: steps, timePerFrame: 0.14)), withKey: "step")
            } else {
                w.body.removeAction(forKey: "step")
                w.body.texture = steps[0]
            }
        }
        // Two visitors passing close stop and bow to each other; the cooldown lets them part before they can meet again.
        for i in walkers.indices where !still { for j in walkers.indices where j > i {
            let a = walkers[i], b = walkers[j]
            guard hypot(a.node.position.x - b.node.position.x, a.node.position.y - b.node.position.y) < 40,
                  currentTime - a.greeted > 10, currentTime - b.greeted > 10, a.node.speed == 1, b.node.speed == 1,
                  a.body.action(forKey: "wave") == nil, b.body.action(forKey: "wave") == nil else { continue }
            walkers[i].greeted = currentTime
            walkers[j].greeted = currentTime
            for (k, other) in [(i, b), (j, a)] {
                let dir: CGFloat = other.node.position.x > walkers[k].node.position.x ? 1 : -1
                walkers[k].body.xScale = dir
                pause(k, .sequence([.setTexture(frames(walkers[k].id, "front")[0]), .wait(forDuration: 0.3),
                                    .group([.rotate(toAngle: -0.55 * dir, duration: 0.4), .scaleY(to: 0.88, duration: 0.4)]), .wait(forDuration: 1),
                                    .group([.rotate(toAngle: 0, duration: 0.4), .scaleY(to: 1, duration: 0.4)]), .wait(forDuration: 0.4)]))
            }
        } }
        if lastTouch == 0 { lastTouch = currentTime }
        // Save battery: stop drawing after a minute without a touch (soon after with Reduce Motion, which has nothing to move).
        if currentTime - lastTouch > (still ? 2 : 60) { view?.isPaused = true }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        lastTouch = 0
        view?.isPaused = false
        guard let touch = touches.first, let body = nodes(at: touch.location(in: self)).first(where: { $0.name == "visitor" }) as? SKSpriteNode,
              let i = walkers.firstIndex(where: { $0.body === body }), body.action(forKey: "wave") == nil else { return }
        pause(i, .sequence([.setTexture(SKTexture(imageNamed: "visitor-\(walkers[i].id)-wave")), .wait(forDuration: 1.4)]))
    }

    /// Stops a visitor for a little moment (a wave or a bow), then they carry on.
    private func pause(_ i: Int, _ action: SKAction) {
        let w = walkers[i]
        walkers[i].state = ""
        w.body.removeAction(forKey: "step")
        // Only the walk pauses: node.speed would freeze the body's own actions too, since children inherit it.
        let route = w.node.action(forKey: "route")
        route?.speed = 0
        w.body.run(.sequence([action, .run { route?.speed = 1 }]), withKey: "wave")
    }

    // MARK: Helpers

    private func add(_ node: SKNode, z: CGFloat) {
        node.zPosition = z
        addChild(node)
    }

    /// Calm motion only, and none with Reduce Motion.
    private func animate(_ node: SKNode, _ action: SKAction) {
        if !still { node.run(action) }
    }

    private func shape(_ points: [(CGFloat, CGFloat)], _ color: UIColor) -> SKShapeNode {
        let path = CGMutablePath()
        path.addLines(between: points.map { p($0) })
        path.closeSubpath()
        let node = SKShapeNode(path: path)
        node.fillColor = color
        node.strokeColor = .clear
        return node
    }

    private func dot(_ color: UIColor, r: CGFloat, at point: CGPoint) -> SKShapeNode {
        let node = SKShapeNode(circleOfRadius: r)
        node.fillColor = color
        node.strokeColor = .clear
        node.position = point
        return node
    }

    /// A top-to-bottom gradient, stretched to whatever it fills.
    private func gradient(_ colors: [UIColor], height: CGFloat) -> SKTexture {
        SKTexture(image: UIGraphicsImageRenderer(size: CGSize(width: 1, height: height)).image { ctx in
            let g = CGGradient(colorsSpace: nil, colors: colors.map(\.cgColor) as CFArray, locations: nil)!
            ctx.cgContext.drawLinearGradient(g, start: .zero, end: CGPoint(x: 0, y: height), options: [])
        })
    }

    /// A soft round light that fades to nothing at its edge.
    private func glow(_ color: UIColor, r: CGFloat, at point: CGPoint) -> SKSpriteNode {
        let image = UIGraphicsImageRenderer(size: CGSize(width: r * 2, height: r * 2)).image { ctx in
            let g = CGGradient(colorsSpace: nil, colors: [color.cgColor, color.withAlphaComponent(0).cgColor] as CFArray, locations: nil)!
            let mid = CGPoint(x: r, y: r)
            ctx.cgContext.drawRadialGradient(g, startCenter: mid, startRadius: 0, endCenter: mid, endRadius: r, options: [])
        }
        let node = SKSpriteNode(texture: SKTexture(image: image))
        node.position = point
        node.blendMode = .add
        return node
    }

    private func curve(_ points: [CGPoint]) -> CGPath {
        let path = CGMutablePath()
        path.move(to: points[0])
        for i in stride(from: 1, to: points.count - 2, by: 3) {
            path.addCurve(to: points[i + 2], control1: points[i], control2: points[i + 1])
        }
        return path
    }
}

/// A board point from the mock-up (y down) to SpriteKit (y up).
private func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: VillageScene.board.height - y) }
private func p(_ q: (CGFloat, CGFloat)) -> CGPoint { p(q.0, q.1) }
private func mix(_ a: UIColor, _ b: UIColor, _ t: CGFloat) -> UIColor {
    var (r1, g1, b1, a1, r2, g2, b2, a2): (CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0, 0, 0, 0, 0)
    a.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
    b.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
    return UIColor(red: r1 + (r2 - r1) * t, green: g1 + (g2 - g1) * t, blue: b1 + (b2 - b1) * t, alpha: a1 + (a2 - a1) * t)
}
private func c(_ hex: UInt32, _ alpha: CGFloat = 1) -> UIColor { UIColor(Color(hex: hex)).withAlphaComponent(alpha) }
