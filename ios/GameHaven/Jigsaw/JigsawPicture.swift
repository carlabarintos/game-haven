import UIKit

/// The jigsaw pictures (JigsawLogic.pictures): square crops of Hiroshige woodblock prints,
/// public domain (CC0) from The Metropolitan Museum of Art, bundled as Art/jigsaw-0…3.jpg.
enum JigsawPicture {
    private static var cache: [Int: UIImage] = [:]

    /// The picture, loaded once and kept.
    static func image(_ index: Int) -> UIImage {
        if let done = cache[index] { return done }
        let image = UIImage(named: "jigsaw-\(index).jpg") ?? UIImage()
        cache[index] = image
        return image
    }
}
