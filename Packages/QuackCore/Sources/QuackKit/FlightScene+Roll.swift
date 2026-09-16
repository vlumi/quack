import QuackCore
import SpriteKit

/// The drawing's roll and swing, easing after the sim's instant flips.
extension FlightScene {
    /// The sim flips instantly; the drawing rolls, top toward the camera, with a
    /// little easing, and rolls back the same way in reverse. On the ground a
    /// plane never rolls: it swings round (`swingScale`), so the drawing snaps.
    func updateRoll(inverted: Bool, at now: TimeInterval) {
        let target: CGFloat = inverted ? 1 : 0
        if practice.phase.isOnGround {
            rollShown = target
            rollStart = nil
        }
        if rollShown != target && rollStart == nil {
            rollStart = now
            rollFrom = rollShown
        }
        if let start = rollStart {
            let t = min(1, (now - start) / rollDuration)
            let eased = t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2
            rollShown = rollFrom + (target - rollFrom) * CGFloat(eased)
            if t >= 1 {
                rollShown = target
                rollStart = nil
            }
        }
        planeNode.roll = rollShown * .pi
    }

    /// A plane swinging round on the ground is drawn narrowing to edge-on and
    /// widening again mirrored: a yaw seen from the side. The sim flips its
    /// facing at the end, where a mirrored drawing and a flipped one look the same.
    func swingScale() -> CGFloat {
        guard case .taxiing(let steps, _) = practice.phase, case .turn(let elapsed) = steps.first
        else { return 1 }
        return CGFloat(cos(.pi * min(1, elapsed / max(0.01, tuning.landing.turnTime))))
    }

    /// Each field at its lap nearest the plane. The approach guides are for
    /// the air: they fade out while the plane is on the ground or wrecked, and
    /// back in once it flies.
    func placeFields(near: (Double) -> CGFloat) {
        let inTheAir: CGFloat
        switch practice.phase {
        case .flying, .approach, .goAround: inTheAir = 1
        default: inTheAir = 0
        }
        for (node, field) in zip(fieldNodes, practice.model.strip.airfields) {
            node.position = CGPoint(x: near(field.start), y: field.elevation * scale)
            if let cones = node.childNode(withName: "cones") {
                cones.alpha += (inTheAir - cones.alpha) * 0.08
            }
        }
    }
}
