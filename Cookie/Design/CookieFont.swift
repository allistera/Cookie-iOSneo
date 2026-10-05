import SwiftUI

/// The app's bundled typefaces. Sizes follow the design and scale with
/// Dynamic Type relative to the given system text style.
enum CookieFont {
    enum Weight: String {
        case regular = "Figtree-Regular"
        case semibold = "Figtree-SemiBold"
        case bold = "Figtree-Bold"
    }

    static func text(_ weight: Weight, size: CGFloat, relativeTo style: Font.TextStyle) -> Font {
        .custom(weight.rawValue, size: size, relativeTo: style)
    }

    /// JetBrains Mono Medium, used for counts and times.
    static func mono(size: CGFloat, relativeTo style: Font.TextStyle) -> Font {
        .custom("JetBrainsMono-Medium", size: size, relativeTo: style)
    }
}
