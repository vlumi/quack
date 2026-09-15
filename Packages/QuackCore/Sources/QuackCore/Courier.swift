import Foundation

/// A job between two fields: pick up here, deliver there, and the pay falls
/// with time. Mail does not care how it is flown; passengers will.
public struct Contract: Equatable, Sendable {
    public enum Kind: String, CaseIterable, Sendable {
        case mail
    }

    public var kind: Kind
    /// Indexes into the strip's fields.
    public var from: Int
    public var to: Int
    /// What it pays delivered at once.
    public var fare: Double
    /// Seconds over which the fare falls to its floor.
    public var window: Double

    public init(kind: Kind, from: Int, to: Int, fare: Double, window: Double) {
        self.kind = kind
        self.from = from
        self.to = to
        self.fare = fare
        self.window = window
    }

    /// The least it pays, however late.
    public var floor: Double { fare / 4 }

    /// What it pays `seconds` after pickup: the fare, falling in a straight
    /// line to the floor at the end of the window.
    public func pay(after seconds: Double) -> Double {
        max(floor, fare - (fare - floor) * seconds / max(1, window))
    }
}

/// What happened to the courier this step.
public enum CourierEvent: Equatable, Sendable {
    case loaded(Contract)
    case delivered(Contract, pay: Double)
    case lost(Contract)
}

/// How contracts are priced.
public struct CourierTuning: Equatable, Sendable {
    /// Francs for any job, before distance.
    public var baseFare: Double = 10
    /// Francs a metre the shorter way round.
    public var farePerMetre: Double = 0.07
    /// The fare falls to its floor over this many times a straight run at
    /// cruise, plus the seconds for a takeoff and a landing.
    public var windowFactor: Double = 4
    public var windowExtra: Double = 20
    /// Offers on the board at a field.
    public var offersPerField: Int = 2

    public init() {}
}

extension Practice {
    /// What the contract aboard pays if delivered now.
    public var payNow: Double? {
        guard let contract, let acceptedAt else { return nil }
        return contract.pay(after: time - acceptedAt)
    }

    /// The offer the trigger has picked at this field, if any.
    public var chosen: Contract? {
        offers.isEmpty ? nil : offers[chosenOffer % offers.count]
    }

    /// Where the contract aboard goes, as the field's index.
    public var destination: Airfield? {
        guard let contract else { return nil }
        return model.strip.airfields[contract.to]
    }

    /// Offers posted at field `from`, priced by the shorter way round to each
    /// other field, from the seed and how many jobs have been done, so a board
    /// is fresh after each delivery.
    func offers(at from: Int) -> [Contract] {
        let strip = model.strip
        let others = strip.airfields.indices.filter { $0 != from }
        guard !others.isEmpty else { return [] }
        var rng = SeededRNG(seed: seed ^ 0xC0A7_2AC7 ^ UInt64(from) << 8 ^ UInt64(deliveries) << 16)
        var pool = others
        return (0..<min(courierTuning.offersPerField, others.count)).map { _ in
            let to = pool.remove(at: min(pool.count - 1, Int(rng.unit() * Double(pool.count))))
            let a = strip.airfields[from], b = strip.airfields[to]
            let distance = abs(
                strip.offset(from: a.start + a.length / 2, to: b.start + b.length / 2))
            let fare = (courierTuning.baseFare + distance * courierTuning.farePerMetre).rounded()
            let straight = distance / model.flight.tuning.cruiseSpeed
            let window = courierTuning.windowFactor * straight + courierTuning.windowExtra
            return Contract(kind: .mail, from: from, to: to, fare: fare, window: window)
        }
    }

    /// The courier's step: the board at a field the plane is parked on, the
    /// trigger picking from it, the pick loaded at lift-off, paid at the
    /// destination, and lost in a crash.
    mutating func advanceCourier(input: PlaneInput) {
        courierEvent = nil
        defer { wasFiring = input.fire }
        guard mode == .courier else { return }
        let strip = model.strip
        let here = strip.airfields.firstIndex {
            strip.image(of: $0, near: plane.x).contains(plane.x)
        }
        settle(here: here)
        // The board: posted while parked with nothing aboard, cleared otherwise.
        if case .parked = phase, contract == nil, let here {
            if offers.isEmpty || offers[0].from != here {
                offers = offers(at: here)
                chosenOffer = 0
            }
            if input.fire && !wasFiring && !offers.isEmpty {
                chosenOffer = (chosenOffer + 1) % offers.count
            }
        } else if !phase.isOnGround {
            offers = []
        }
    }

    /// What this step's flight event does to the bag: loaded at lift-off, paid
    /// when parked at its field, lost in a crash.
    private mutating func settle(here: Int?) {
        switch lastEvent {
        case .liftoff:
            if contract == nil, let pick = chosen {
                contract = pick
                acceptedAt = time
                courierEvent = .loaded(pick)
            }
            offers = []
        case .parked:
            if let contract, let acceptedAt, here == contract.to {
                let pay = contract.pay(after: time - acceptedAt)
                money += pay
                deliveries += 1
                courierEvent = .delivered(contract, pay: pay)
                self.contract = nil
                self.acceptedAt = nil
            }
        case .crash:
            if let contract {
                courierEvent = .lost(contract)
                self.contract = nil
                acceptedAt = nil
            }
        default:
            break
        }
    }
}
