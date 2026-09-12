import QuackCore
import SpriteKit
import SwiftUI

/// Two inputs, each doing one thing. Left half of the screen: a vertical drag
/// from wherever the thumb landed sets the elevator, the thumb defining its
/// own centre. Right half: holding fires the gun. The throttle is open for the
/// whole flight (see docs/design.md), so `power` is always on; the sim keeps
/// the input for the landing assist and AI pilots.
final class ThumbControls {
    /// Points of drag for full elevator.
    var throwDistance: CGFloat = 80
    /// Aircraft convention by default: pull the thumb (or ↓) toward you and the
    /// nose comes up. Flipping this is a planned setting; the seam is here.
    var invertedPitch = false

    private var pitchTouch: (id: ObjectIdentifier, origin: CGPoint)?
    private var fireTouches = Set<ObjectIdentifier>()
    private var pitch: Double = 0
    private var keyPitch: Double = 0
    private var keyFire = false

    var input: PlaneInput {
        let raw = pitch != 0 ? pitch : keyPitch
        return PlaneInput(
            pitch: invertedPitch ? -raw : raw, power: true, fire: !fireTouches.isEmpty || keyFire)
    }

    #if os(iOS)
    func began(_ touch: UITouch, in scene: SKScene) {
        let p = touch.location(in: scene.view)
        let id = ObjectIdentifier(touch)
        if p.x < (scene.view?.bounds.width ?? 0) / 2 {
            if pitchTouch == nil { pitchTouch = (id, p) }
        } else {
            fireTouches.insert(id)
        }
    }

    func moved(_ touch: UITouch, in scene: SKScene) {
        guard let pt = pitchTouch, pt.id == ObjectIdentifier(touch) else { return }
        let p = touch.location(in: scene.view)
        // Screen y grows downward; dragging the thumb down (stick back) pulls
        // the nose up.
        pitch = Double(min(1, max(-1, (p.y - pt.origin.y) / throwDistance)))
    }

    func ended(_ touch: UITouch) {
        let id = ObjectIdentifier(touch)
        if pitchTouch?.id == id {
            pitchTouch = nil
            pitch = 0
        }
        fireTouches.remove(id)
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
