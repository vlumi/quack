import QuackCore
import SpriteKit

/// The scene in a Duckfight: starting and leaving one, the host's step and a
/// guest's frame, and, for the courier, banking the till.
extension FlightScene {
    /// Fly a Duckfight the session agreed: the fight built from its start,
    /// this device's seat, and the session driving the traffic.
    public func startFight(_ start: FightStart, session: FightSession) {
        self.session = session
        mode = .duckfight
        localSeat = session.mySeat ?? 0
        practice = start.makeFight()
        fightTick = 0
        lastSeats = []
        moneyTold = nil
        attract = false
        applyTuning()
        markerNodes.forEach { $0.removeFromParent() }
        markerNodes = []
        rollShown = 0
        rollStart = nil
        planeNode.roll = 0
        flash = nil
        hud.fightOver = false
    }

    /// Out of a fight and back to single player behind the title.
    public func leaveFight() {
        session = nil
        localSeat = 0
        mode = .courier
        run += 1
        startRun()
    }

    /// One sim step: in a fight the host's, with every seat's input and a
    /// snapshot on the cadence ticks; else the single player's.
    func step(_ input: PlaneInput) {
        if let session {
            fightTick += 1
            practice.advance(inputs: session.hostInputs(mine: input))
            session.broadcast(practice, tick: fightTick)
        } else {
            practice.advance(input: input)
        }
    }

    /// A guest's frame: thumbs to the host, the host's word on screen. The
    /// guest never steps the sim.
    func guestFrame(_ session: FightSession, dt: TimeInterval, at now: TimeInterval) {
        session.publish(controls.input)
        if let snapshot = session.view(advancedBy: dt) {
            showDifferences(from: snapshot, at: now)
            snapshot.apply(to: &practice)
        }
        accumulator = 0
    }

    /// The till is banked whenever the plane is parked, which is where money changes hands.
    func bankTheTill() {
        if practice.mode == .courier, case .parked = me.phase, practice.money != moneyTold {
            moneyTold = practice.money
            onMoneyChange?(practice.money)
        }
    }
}
