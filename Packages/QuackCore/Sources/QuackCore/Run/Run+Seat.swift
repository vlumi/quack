import Foundation

/// One seat's share of a step: its flight, tank, belt and rounds.
extension Run {
    /// One human seat's step: the tank, the flight, the damage settled at a
    /// stop, the belt, and its rounds. Wrecked, it keeps nothing in the air.
    mutating func flyHuman(at i: Int, input given: PlaneInput, dt: Double) {
        if pilots[i].falling || pilots[i].down {
            fall(at: i, dt: dt)
            return
        }
        // An empty tank is a dead engine, whatever the throttle.
        var input = given
        if !engineRunning(at: i) || engineShotOut(at: i) { input.power = false }
        burnAndRefuel(at: i, dt: dt)
        var flown = pilots[i].plane
        var next = pilots[i].phase
        pilots[i].lastEvent = model.advance(&flown, &next, input: input, dt: dt)
        flown.x = model.strip.wrap(flown.x)
        pilots[i].plane = flown
        pilots[i].phase = next
        if case .wrecked = pilots[i].phase {
            pilots[i].bullets.removeAll()
            if i == 0 { shells.removeAll() }
            pilots[i].hits = 0
            pilots[i].repairDue = 0
            return
        }
        settleDamage(at: i)
        rearm(at: i, dt: dt)
        fireAndFlyRounds(at: i, input: input, dt: dt)
        let strip = model.strip
        let life = gun.bulletLife
        pilots[i].bullets.removeAll { $0.age >= life || $0.y < strip.surfaceHeight(at: $0.x) }
    }

    /// The balloon run ends parked after the last pop; a Duckfight when its time is up.
    mutating func finishTheRun() {
        guard finishedAt == nil, startedAt != nil else { return }
        switch mode {
        case .balloons:
            if remaining == 0, case .parked = phase { finishedAt = time }
        case .duckfight:
            if elapsed >= duckfight.duration { finishedAt = time }
        case .courier:
            break
        }
    }
    /// Parked on the field, the belt fills a round at a time; anywhere else the
    /// part-loaded round is lost. A belt over a lowered capacity is cut down.
    /// The courier pays for each round, on credit when broke; the balloon run
    /// pays nothing.
    mutating func rearm(at i: Int, dt: Double) {
        pilots[i].ammo = min(pilots[i].ammo, capacity)
        guard isRearming(at: i) else {
            pilots[i].rearmProgress = 0
            return
        }
        pilots[i].rearmProgress += gun.rearmRate * dt
        let loaded = min(Int(pilots[i].rearmProgress), capacity - pilots[i].ammo)
        if mode == .courier {
            money = max(0, money - Double(loaded) * courierTuning.roundPrice)
        }
        pilots[i].ammo += loaded
        pilots[i].rearmProgress -= Double(loaded)
        if pilots[i].ammo == capacity { pilots[i].rearmProgress = 0 }
    }

    /// Loading a round at a time while parked, and not yet full.
    public func isRearming(at i: Int) -> Bool {
        guard case .parked = pilots[i].phase else { return false }
        return pilots[i].ammo < capacity
    }
}
