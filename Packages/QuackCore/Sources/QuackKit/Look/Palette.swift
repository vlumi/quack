import QuackCore
import SpriteKit

/// A colour as plain numbers, so the palette can mix, lighten and shade them.
struct RGB: Equatable {
    var r: Double
    var g: Double
    var b: Double

    init(_ hex: UInt32) {
        r = Double((hex >> 16) & 0xFF) / 255
        g = Double((hex >> 8) & 0xFF) / 255
        b = Double(hex & 0xFF) / 255
    }

    init(r: Double, g: Double, b: Double) {
        self.r = r
        self.g = g
        self.b = b
    }

    static let white = RGB(0xFFFFFF)
    static let black = RGB(0x000000)

    /// `t` of the way from this colour to `other`.
    func mix(_ other: RGB, _ t: Double) -> RGB {
        RGB(r: r + (other.r - r) * t, g: g + (other.g - g) * t, b: b + (other.b - b) * t)
    }

    func lighter(_ t: Double) -> RGB { mix(.white, t) }
    func darker(_ t: Double) -> RGB { mix(.black, t) }

    func color(alpha: Double = 1) -> SKColor {
        SKColor(red: CGFloat(r), green: CGFloat(g), blue: CGFloat(b), alpha: CGFloat(alpha))
    }
}

/// The colours of a run's hour: the sky, the light that tints everything, the
/// haze that fades the far layers into the sky, and the sun or the moon. The
/// look is the poster's shapes over a quiet, smooth sky.
struct Palette {
    /// Where the sun or moon hangs, in box points from the anchor, and how big.
    struct Body {
        let position: CGPoint
        let radius: CGFloat
        let colour: RGB
        let isMoon: Bool
    }

    /// Top of the sky, the middle, and the horizon.
    let sky: [RGB]
    /// The light's colour, and how far it tints everything toward itself.
    let tint: RGB
    let tintAmount: Double
    /// What distance fades toward.
    let haze: RGB
    /// 1 in full daylight, lower as it darkens.
    let light: Double
    /// How bright the stars are; 0 by day.
    let stars: Double
    /// How strongly windows glow; 0 by day.
    let windows: Double
    let body: Body

    /// How far each layer fades into the haze, back to front, the strip last.
    static let layerHaze = [0.62, 0.38, 0.16, 0]

    /// The unlit colours of things, before the hour touches them.
    enum Base {
        static let layers = [RGB(0x6F8F6A), RGB(0x5F8A52), RGB(0x4C7B41)]
        static let ground = RGB(0x6B9E52)
        static let field = RGB(0xC7AE7A)
        static let wall = RGB(0xEFE6D2)
        static let wall2 = RGB(0xD9C7A8)
        static let roof = RGB(0xB5553C)
        static let roof2 = RGB(0x687282)
        static let trunk = RGB(0x6B4A2E)
        static let tree = RGB(0x3F7A3C)
        static let pine = RGB(0x2F5E3A)
        static let hangar = RGB(0xB3B9C0)
        static let door = RGB(0x5F666F)
        static let sock = RGB(0xEE7326)
        static let sail = RGB(0xE9E1CF)
        static let window = RGB(0x3B4452)
        static let lamplight = RGB(0xFFCE66)
        static let balloons = [
            RGB(0xD93333), RGB(0xF2B705), RGB(0x3373D9), RGB(0x4DA64D), RGB(0xE67326),
            RGB(0x994DB3),
        ]
    }

    init(_ hour: TimeOfDay) {
        switch hour {
        case .dawn:
            sky = [RGB(0x34457C), RGB(0xB98AA8), RGB(0xF7C59F)]
            tint = RGB(0xF0A27A)
            (tintAmount, light, stars, windows) = (0.2, 0.9, 0.18, 0.4)
            haze = RGB(0xE6B6A6)
            body = Body(
                position: CGPoint(x: -410, y: 49), radius: 34, colour: RGB(0xFFE2B0), isMoon: false)
        case .noon:
            sky = [RGB(0x4A82C4), RGB(0x8CB8E6), RGB(0xCFE3F2)]
            tint = RGB(0xFFF4D0)
            (tintAmount, light, stars, windows) = (0, 1, 0, 0)
            haze = RGB(0xCFE3F2)
            body = Body(
                position: CGPoint(x: 390, y: 386), radius: 30, colour: RGB(0xFFF6D8), isMoon: false)
        case .evening:
            sky = [RGB(0x4A64A2), RGB(0xDD9F72), RGB(0xF8D58A)]
            tint = RGB(0xFFAC52)
            (tintAmount, light, stars, windows) = (0.22, 0.94, 0, 0.15)
            haze = RGB(0xF0C490)
            body = Body(
                position: CGPoint(x: 420, y: 114), radius: 40, colour: RGB(0xFFD27A), isMoon: false)
        case .night:
            sky = [RGB(0x060A1A), RGB(0x121A36), RGB(0x26325A)]
            tint = RGB(0x18234C)
            (tintAmount, light, stars, windows) = (0.64, 0.52, 1, 1)
            haze = RGB(0x1F2B52)
            body = Body(
                position: CGPoint(x: 320, y: 369), radius: 22, colour: RGB(0xE8ECF5), isMoon: true)
        }
    }

    /// A colour in this hour's light.
    func lit(_ c: RGB) -> RGB { c.mix(tint, tintAmount) }

    /// A colour in this hour's light on layer `layer` (0 far … 3 the strip), faded into the haze.
    func onLayer(_ c: RGB, _ layer: Int) -> RGB {
        lit(c).mix(haze, Palette.layerHaze[min(layer, Palette.layerHaze.count - 1)])
    }

    /// A balloon's colour, darkened as the light goes.
    func balloon(_ index: Int) -> SKColor {
        let base = Base.balloons[index % Base.balloons.count]
        return lit(base).darker((1 - light) * 0.35).color()
    }

    /// Readouts: dark ink by day, pale at night.
    var hudInk: SKColor {
        stars > 0.5 ? SKColor(white: 0.92, alpha: 1) : SKColor(white: 0.12, alpha: 1)
    }
}
