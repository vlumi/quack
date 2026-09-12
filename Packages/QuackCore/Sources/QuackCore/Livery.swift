/// The paint on a plane: three colours and an emblem. Pure data, so a picker,
/// a save file and a network peer can all carry one; QuackKit turns it into
/// the drawing.
public struct Livery: Equatable, Hashable, Codable, Sendable {
    /// A colour with no platform type behind it; components in 0...1.
    public struct Color: Equatable, Hashable, Codable, Sendable {
        public var red: Double
        public var green: Double
        public var blue: Double

        public init(red: Double, green: Double, blue: Double) {
            self.red = red
            self.green = green
            self.blue = blue
        }

        /// From a 0xRRGGBB literal.
        public init(hex: UInt32) {
            self.init(
                red: Double((hex >> 16) & 0xFF) / 255,
                green: Double((hex >> 8) & 0xFF) / 255,
                blue: Double(hex & 0xFF) / 255)
        }
    }

    /// The company symbol on the fin.
    public enum Emblem: String, CaseIterable, Codable, Sendable {
        case roundel
        case star
        case checker
    }

    /// Fuselage and fin.
    public var body: Color
    /// Wings, tailplane and wheel hubs.
    public var wing: Color
    /// Engine cowl.
    public var trim: Color
    public var emblem: Emblem
    /// The emblem's figure and its ground.
    public var emblemInk: Color
    public var emblemField: Color

    public init(
        body: Color, wing: Color, trim: Color,
        emblem: Emblem, emblemInk: Color, emblemField: Color
    ) {
        self.body = body
        self.wing = wing
        self.trim = trim
        self.emblem = emblem
        self.emblemInk = emblemInk
        self.emblemField = emblemField
    }

    /// The company's own: mailbag brown, cream wings, a red cowl and roundel.
    public static let courier = Livery(
        body: Color(hex: 0x8B5A2B), wing: Color(hex: 0xF3E6C8), trim: Color(hex: 0xC8102E),
        emblem: .roundel, emblemInk: Color(hex: 0xC8102E), emblemField: Color(hex: 0xF3E6C8))
    /// Duck yellow with navy wings and a star.
    public static let duck = Livery(
        body: Color(hex: 0xF2B705), wing: Color(hex: 0x1F2A44), trim: Color(hex: 0xE8702A),
        emblem: .star, emblemInk: Color(hex: 0x1F2A44), emblemField: Color(hex: 0xF2B705))
    /// The competition: red and black under a chequer.
    public static let rival = Livery(
        body: Color(hex: 0xB4202A), wing: Color(hex: 0x1A1A1A), trim: Color(hex: 0xF3E6C8),
        emblem: .checker, emblemInk: Color(hex: 0x1A1A1A), emblemField: Color(hex: 0xF3E6C8))

    /// Every built-in livery, the courier first.
    public static let all: [Livery] = [.courier, .duck, .rival]
}
