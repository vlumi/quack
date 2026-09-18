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
    public var engineRunning: Bool { engineRunning(at: 0) }
    public func engineRunning(at i: Int) -> Bool { pilots[i].fuel > 0 }

    /// Fuel as a share of the tank, for a gauge.
    public var fuelShare: Double { fuelShare(at: 0) }
    public func fuelShare(at i: Int) -> Double {
        min(1, max(0, pilots[i].fuel / max(1, fuelTuning.tank)))
    }

    /// Filling while parked and not yet full.
    public var isRefuelling: Bool { isRefuelling(at: 0) }
    public func isRefuelling(at i: Int) -> Bool {
        guard case .parked = pilots[i].phase else { return false }
        return pilots[i].fuel < fuelTuning.tank
    }

    /// The tank this step: burning while the engine runs, filling while
    /// parked. Filling costs what the courier can pay and no more, so a broke
    /// courier is filled on credit rather than stranded; the balloon run pays
    /// nothing.
    mutating func burnAndRefuel(at i: Int, dt: Double) {
        pilots[i].fuel = min(pilots[i].fuel, fuelTuning.tank)
        switch pilots[i].phase {
        case .parked:
            let wanted = min(fuelTuning.refuelRate * dt, fuelTuning.tank - pilots[i].fuel)
            guard wanted > 0 else { return }
            if mode == .courier {
                money = max(0, money - wanted * fuelTuning.price)
            }
            pilots[i].fuel += wanted
        case .wrecked:
            break
        default:
            pilots[i].fuel = max(0, pilots[i].fuel - dt)
        }
    }
}
