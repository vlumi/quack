import Foundation

/// The courier company between runs: the money in the till and what it has
/// bought. Kept on the device; every courier run starts from it and pays
/// into it. Versioned and `Codable`, so a saved career survives the game
/// changing under it.
public struct Career: Equatable, Sendable, Codable {
    public static let version = 1

    public var version = Career.version
    public var money: Double = 0
    /// Levels bought of each upgrade, from 0.
    public var levels: [Upgrade: Int] = [:]

    public init(money: Double = 0, levels: [Upgrade: Int] = [:]) {
        self.money = money
        self.levels = levels
    }

    /// What money buys, in the hangar.
    public enum Upgrade: String, CaseIterable, Sendable, Codable {
        /// Seconds of engine added to the tank per level.
        case tank
        /// Thrust added per level.
        case engine
        /// Room for a second passenger: passenger fares doubled.
        case seat

        /// The price of each level, so the count is the most levels.
        public var prices: [Double] {
            switch self {
            case .tank: return [60, 100, 150]
            case .engine: return [80, 120, 180]
            case .seat: return [200]
            }
        }

        public var maxLevel: Int { prices.count }

        /// What one level adds.
        public var tankPerLevel: Double { 50 }
        public var thrustPerLevel: Double { 1.5 }
    }

    public func level(_ upgrade: Upgrade) -> Int { levels[upgrade] ?? 0 }

    /// The price of the next level, or nil at the top.
    public func nextPrice(_ upgrade: Upgrade) -> Double? {
        let level = level(upgrade)
        return level < upgrade.maxLevel ? upgrade.prices[level] : nil
    }

    public func canBuy(_ upgrade: Upgrade) -> Bool {
        guard let price = nextPrice(upgrade) else { return false }
        return money >= price
    }

    /// Buy the next level if there is one and the money is there.
    @discardableResult
    public mutating func buy(_ upgrade: Upgrade) -> Bool {
        guard canBuy(upgrade), let price = nextPrice(upgrade) else { return false }
        money -= price
        levels[upgrade] = level(upgrade) + 1
        return true
    }

    /// Seconds of engine the tank holds over the stock one.
    public var tankBonus: Double { Double(level(.tank)) * Upgrade.tank.tankPerLevel }
    /// Thrust over the stock engine.
    public var thrustBonus: Double { Double(level(.engine)) * Upgrade.engine.thrustPerLevel }
    /// How many passengers a job carries: one, or two with the second seat.
    public var seats: Int { level(.seat) > 0 ? 2 : 1 }
}

extension Run {
    /// Every dial from the panel, with the career's upgrades on top: a bigger
    /// tank, a stronger engine. The seat is read where fares are set.
    public mutating func apply(_ tuning: Tuning) {
        model.flight.tuning = tuning.flight
        model.flight.tuning.thrust += career.thrustBonus
        model.landing = tuning.landing
        gun = tuning.gun
        windTuning = tuning.wind
        courierTuning = tuning.courier
        fuelTuning = tuning.fuel
        fuelTuning.tank += career.tankBonus
        hazardTuning = tuning.hazards
        rivalTuning = tuning.rival
    }
}
