import QuackCore
import SpriteKit
import SwiftUI

/// Two inputs, each doing one thing. Left half of the screen: a vertical drag
/// from wherever the thumb landed sets the elevator, the thumb defining its
/// own centre. Right half: holding fires the gun. The throttle is open for the
/// whole flight (see docs/design.md), so `power` is always on; the sim keeps
/// the input for the landing assist and AI pilots. Every touch event also
/// updates the overlay state, which draws the pads where the thumbs are.
final class ThumbControls {
    /// Points of drag for full elevator, at most; near an edge the throw in
    /// that direction shrinks to the room there, so full elevator is always
    /// reachable from wherever the thumb landed.
    var throwDistance: CGFloat = 80
    /// The least a throw shrinks to, so a landing right at the edge is not a hair trigger.
    var minimumThrow: CGFloat = 28
    /// Aircraft convention by default: pull the thumb (or ↓) toward you and the
    /// nose comes up. Flipping this is a planned setting; the seam is here.
    var invertedPitch = false

    let overlay: ThumbOverlayState

    private struct PitchTouch {
        let id: ObjectIdentifier
        let origin: CGPoint
        let up: CGFloat
        let down: CGFloat
    }

    private var pitchTouch: PitchTouch?
    private var fireTouches = Set<ObjectIdentifier>()
    private var pitch: Double = 0
    private var keyPitch: Double = 0
    private var keyFire = false

    init(overlay: ThumbOverlayState) {
        self.overlay = overlay
    }

    var input: PlaneInput {
        let raw = pitch != 0 ? pitch : keyPitch
        return PlaneInput(
            pitch: invertedPitch ? -raw : raw, power: true, fire: !fireTouches.isEmpty || keyFire)
    }

    #if os(iOS)
    func began(_ touch: UITouch, in scene: SKScene) {
        guard let view = scene.view else { return }
        let p = touch.location(in: view)
        let id = ObjectIdentifier(touch)
        if p.x < view.bounds.width / 2 {
            guard pitchTouch == nil else { return }
            let insets = view.safeAreaInsets
            let up = max(minimumThrow, min(throwDistance, p.y - insets.top))
            let down = max(
                minimumThrow, min(throwDistance, view.bounds.height - insets.bottom - p.y))
            pitchTouch = PitchTouch(id: id, origin: p, up: up, down: down)
            overlay.pitchOrigin = p
            overlay.pitchKnob = p
            overlay.throwUp = up
            overlay.throwDown = down
            overlay.pitch = 0
        } else {
            fireTouches.insert(id)
            overlay.fireOrigin = p
            overlay.firing = true
        }
    }

    func moved(_ touch: UITouch, in scene: SKScene) {
        guard let pt = pitchTouch, pt.id == ObjectIdentifier(touch), let view = scene.view else {
            return
        }
        let p = touch.location(in: view)
        // Screen y grows downward; dragging the thumb down (stick back) pulls
        // the nose up. Each direction has its own throw.
        let dy = p.y - pt.origin.y
        pitch = Double(dy >= 0 ? min(1, dy / pt.down) : max(-1, dy / pt.up))
        overlay.pitchKnob = p
        overlay.pitch = invertedPitch ? -pitch : pitch
    }

    func ended(_ touch: UITouch) {
        let id = ObjectIdentifier(touch)
        if pitchTouch?.id == id {
            pitchTouch = nil
            pitch = 0
            overlay.pitchKnob = nil
            overlay.pitch = 0
        }
        if fireTouches.remove(id) != nil, fireTouches.isEmpty {
            overlay.firing = false
        }
    }
    #endif

    #if os(macOS)
    func keyboard(_ press: KeyPress) {
        let down = press.phase == .down
        switch press.key {
        // Same sense as the thumb: ↓ is stick back, nose up.
        case .downArrow: keyPitch = down ? 1 : (keyPitch > 0 ? 0 : keyPitch)
        case .upArrow: keyPitch = down ? -1 : (keyPitch < 0 ? 0 : keyPitch)
        case .space: keyFire = down
        default: break
        }
    }
    #endif
}
