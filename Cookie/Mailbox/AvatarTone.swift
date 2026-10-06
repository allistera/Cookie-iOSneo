/// Picks one of the design's avatar tones for a sender, stable across launches
/// (Swift's `hashValue` is randomised per process, so a plain hash is not).
enum AvatarTone {
    static let count = 6

    static func index(for name: String) -> Int {
        var hash: UInt32 = 0
        for scalar in name.unicodeScalars {
            hash = hash &* 31 &+ scalar.value
        }
        return Int(hash % UInt32(count))
    }
}
