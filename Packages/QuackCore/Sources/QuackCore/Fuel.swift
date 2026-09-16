import Foundation

/// The tank, as a range clock: seconds of engine. It drains as long as the
/// engine runs, which is whenever the plane is not parked or wrecked, and it
/// fills while parked at a field, for money and time. Empty, the engine stops
/// and the plane glides.
public struct FuelTuning: Equatable, Sendable {
    /// Seconds of engine in a full tank.
    public var tank: Double = 150
    /// Seconds of fuel that go in each second parked.
    public var refuelRate: Double = 10
    /// Francs a second of fuel costs at the field.
    public var price: Double = 0.1

    public init() {}
}

extension Practice {
    /// Whether the engine has anything to burn.
    public var engineRunning: Bool { fuel > 0 }

    /// Fuel as a share of the tank, for a gauge.
    public var fuelShare: Double { min(1, max(0, fuel / max(1, fuelTuning.tank))) }

    /// Filling a round at a time while parked and not yet full.
    public var isRefuelling: Bool {
        guard case .parked = phase else { return false }
        return fuel < fuelTuning.tank
    }

    /// The tank this step: burning while the engine runs, filling while
    /// parked. Filling costs what the courier can pay and no more, so a broke
    /// courier is filled on credit rather than stranded; the balloon run pays
    /// nothing.
    mutating func burnAndRefuel(dt: Double) {
        fuel = min(fuel, fuelTuning.tank)
        switch phase {
        case .parked:
            let wanted = min(fuelTuning.refuelRate * dt, fuelTuning.tank - fuel)
            guard wanted > 0 else { return }
            if mode == .courier {
                money = max(0, money - wanted * fuelTuning.price)
            }
            fuel += wanted
        case .wrecked:
            break
        default:
            fuel = max(0, fuel - dt)
        }
    }
}
