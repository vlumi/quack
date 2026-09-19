import Foundation

/// A job between two fields: pick up here, deliver there, and the pay falls
/// with time. Mail does not care how it is flown; a passenger does, and pays
/// more for the trouble.
public struct Contract: Equatable, Sendable {
    public enum Kind: String, CaseIterable, Sendable {
        case mail
        case passenger
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
    /// The passenger has had enough of the flying: comfort fell through a quarter mark.
    case complaint
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
    /// Offers on the board at a field: one mail, one passenger.
    public var offersPerField: Int = 2
    /// What a passenger pays over the mail for the same trip.
    public var passengerPremium: Double = 1.6
    /// Francs a round costs at the field.
    public var roundPrice: Double = 0.25
    /// Comfort lost a second flying inverted, or rolling.
    public var invertedCost: Double = 0.12
    /// Comfort lost per radian of turn beyond the gentle rate.
    public var turnCost: Double = 0.08
    /// Radians a second of pitch a passenger does not mind.
    public var gentleTurn: Double = 0.9
    /// Comfort lost a second in a stall.
    public var stallCost: Double = 0.15
    /// Comfort lost to a bounce or a broken undercarriage.
    public var bumpCost: Double = 0.2
    /// Comfort lost to a shell bursting on the plane.
    public var hitCost: Double = 0.25

    public init() {}
}

extension Run {
    /// What the contract aboard pays if delivered now: the fare fallen with
    /// time, and for a passenger cut by how the flight has been.
    public var payNow: Double? {
        guard let contract, let acceptedAt else { return nil }
        let pay = contract.pay(after: time - acceptedAt)
        return contract.kind == .passenger ? pay * comfort : pay
    }

    /// A passenger's comfort: 1 at pickup, falling with aerobatics to a floor
    /// of a quarter. Mail has no opinion.
    public var comfort: Double { max(0.25, 1 - discomfort) }

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
        var out: [Contract] = []
        return (0..<min(courierTuning.offersPerField, others.count)).map { _ in
            let to = pool.remove(at: min(pool.count - 1, Int(rng.unit() * Double(pool.count))))
            let a = strip.airfields[from], b = strip.airfields[to]
            let distance = abs(
                strip.offset(from: a.start + a.length / 2, to: b.start + b.length / 2))
            let fare = (courierTuning.baseFare + distance * courierTuning.farePerMetre).rounded()
            let straight = distance / model.flight.tuning.cruiseSpeed
            let window = courierTuning.windowFactor * straight + courierTuning.windowExtra
            // The first offer is mail, the second a passenger, and so on.
            let kind: Contract.Kind = out.count % 2 == 0 ? .mail : .passenger
            // A second seat carries two passengers, who pay two fares.
            let seats = kind == .passenger ? Double(career.seats) : 1
            let premium = (kind == .passenger ? courierTuning.passengerPremium : 1) * seats
            let contract = Contract(
                kind: kind, from: from, to: to, fare: (fare * premium).rounded(), window: window)
            out.append(contract)
            return contract
        }
    }

    /// Pick an offer from the board, by its place on it.
    public mutating func pick(_ index: Int) {
        guard offers.indices.contains(index) else { return }
        chosenOffer = index
    }

    /// The courier's step: the board at a field the plane is parked on, the
    /// pick loaded at lift-off, paid at the destination, and lost in a crash.
    mutating func advanceCourier(input: PlaneInput) {
        courierEvent = nil
        guard mode == .courier else { return }
        let strip = model.strip
        let here = strip.airfields.firstIndex {
            strip.image(of: $0, near: plane.x).contains(plane.x)
        }
        settle(here: here)
        ride(input: input)
        // The board: posted while parked with nothing aboard, cleared otherwise.
        if case .parked = phase, contract == nil, let here {
            if offers.isEmpty || offers[0].from != here {
                offers = offers(at: here)
                chosenOffer = 0
            }
        } else if !phase.isOnGround {
            offers = []
        }
    }

    /// A passenger's ride this step: inverted, hard turns, stalls and bumps all
    /// cost comfort, and each quarter lost is a complaint.
    private mutating func ride(input: PlaneInput) {
        guard let contract, contract.kind == .passenger else {
            discomfort = 0
            lastHeading = plane.heading
            return
        }
        let dt = FlightModel.dt
        let t = courierTuning
        var cost = 0.0
        if !phase.isOnGround {
            if !plane.upright { cost += t.invertedCost * dt }
            // Lift-off and touchdown snap the heading; that is not a turn.
            let snapped = lastEvent == .liftoff || lastEvent == .touchdown
            let turn = abs(FlightModel.shortestTurn(from: lastHeading, to: plane.heading)) / dt
            if turn > t.gentleTurn && !snapped { cost += (turn - t.gentleTurn) * dt * t.turnCost }
            if plane.speed < model.flight.tuning.stallSpeed { cost += t.stallCost * dt }
        }
        if lastEvent == .bounce || lastEvent == .brokenUndercarriage { cost += t.bumpCost }
        // The guns' hit from the last step: a shell bursting on the plane frightens anyone.
        if case .hit = hazardEvent { cost += t.hitCost }
        lastHeading = plane.heading
        guard cost > 0 else { return }
        let before = Int(discomfort * 4)
        discomfort = min(0.75, discomfort + cost)
        if Int(discomfort * 4) > before && courierEvent == nil { courierEvent = .complaint }
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
            if let contract, acceptedAt != nil, here == contract.to, let pay = payNow {
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
