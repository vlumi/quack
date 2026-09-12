import QuackCore
import SpriteKit
import SwiftUI

/// Two inputs at most, each doing one thing. Left half of the screen: a
/// vertical drag from wherever the thumb landed sets the elevator, the thumb
/// defining its own centre. Right half: reserved for the gun. The throttle is
/// open for the whole flight (see docs/design.md), so `power` is always on;
/// the sim keeps the input for the landing assist and AI pilots.
final class ThumbControls {
    /// Points of drag for full elevator.
    var throwDistance: CGFloat = 80
    /// Aircraft convention by default: pull the thumb (or ↓) toward you and the
    /// nose comes up. Flipping this is a planned setting; the seam is here.
    var invertedPitch = false

    private var pitchTouch: (id: ObjectIdentifier, origin: CGPoint)?
    private var pitch: Double = 0
    private var keyPitch: Double = 0

    var input: PlaneInput {
        let raw = pitch != 0 ? pitch : keyPitch
        return PlaneInput(pitch: invertedPitch ? -raw : raw, power: true)
    }

    #if os(iOS)
    func began(_ touch: UITouch, in scene: SKScene) {
        let p = touch.location(in: scene.view)
        guard p.x < (scene.view?.bounds.width ?? 0) / 2, pitchTouch == nil else { return }
        pitchTouch = (ObjectIdentifier(touch), p)
    }

    func moved(_ touch: UITouch, in scene: SKScene) {
        guard let pt = pitchTouch, pt.id == ObjectIdentifier(touch) else { return }
        let p = touch.location(in: scene.view)
        // Screen y grows downward; dragging the thumb down (stick back) pulls
        // the nose up.
        pitch = Double(min(1, max(-1, (p.y - pt.origin.y) / throwDistance)))
    }

    func ended(_ touch: UITouch) {
        guard pitchTouch?.id == ObjectIdentifier(touch) else { return }
        pitchTouch = nil
        pitch = 0
    }
    #endif

    #if os(macOS)
    func keyboard(_ press: KeyPress) {
        let down = press.phase == .down
        switch press.key {
        // Same sense as the thumb: ↓ is stick back, nose up.
        case .downArrow: keyPitch = down ? 1 : (keyPitch > 0 ? 0 : keyPitch)
        case .upArrow: keyPitch = down ? -1 : (keyPitch < 0 ? 0 : keyPitch)
        default: break
        }
    }
    #endif
}
