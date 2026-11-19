import SwiftUI

/// Player settings shared by every game, saved as they change.
/// Reduce Motion and Bold Text come straight from iOS, so they aren't repeated here.
@Observable
final class AppSettings {
    /// Text sizes the in-app buttons step through: standard up to about 235%. nil follows the iPhone's own setting.
    static let textSizes: [DynamicTypeSize] = [.large, .xLarge, .xxLarge, .xxxLarge, .accessibility1, .accessibility2, .accessibility3]
    /// Body text point size at each step, to show the player a percentage.
    static let bodyPoints: [Double] = [17, 19, 21, 23, 28, 33, 40]

    var textSizeIndex: Int? {
        didSet { UserDefaults.standard.set(textSizeIndex ?? -1, forKey: "textSizeIndex") }
    }
    var highContrast: Bool {
        didSet { UserDefaults.standard.set(highContrast, forKey: "highContrast") }
    }
    var sound: Bool {
        didSet { UserDefaults.standard.set(sound, forKey: "sound") }
    }
    var music: Bool {
        didSet {
            UserDefaults.standard.set(music, forKey: "music")
            music ? Music.start() : Music.stop()
        }
    }
    /// Read straight from storage, so the games can play sounds without the settings object. On until turned off.
    static var soundOn: Bool { UserDefaults.standard.object(forKey: "sound") as? Bool ?? true }
    static var musicOn: Bool { UserDefaults.standard.object(forKey: "music") as? Bool ?? true }

    init() {
        let stored = UserDefaults.standard.object(forKey: "textSizeIndex") as? Int ?? -1
        textSizeIndex = Self.textSizes.indices.contains(stored) ? stored : nil
        highContrast = UserDefaults.standard.bool(forKey: "highContrast")
        sound = Self.soundOn
        music = Self.musicOn
    }

    var textSize: DynamicTypeSize? { textSizeIndex.map { Self.textSizes[$0] } }
}
