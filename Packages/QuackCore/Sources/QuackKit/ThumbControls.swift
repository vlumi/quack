import QuackCore
import SpriteKit
import SwiftUI

/// Two inputs, each doing one thing. Left half of the screen: a vertical drag
/// from wherever the thumb landed sets the elevator, the thumb defining its
/// own centre. Right half: holding is power, releasing is glide. Nothing else.
final class ThumbControls {
    /// Points of drag for full elevator.
    var throwDistance: CGFloat = 80

    private var pitchTouch: (id: ObjectIdentifier, origin: CGPoint)?
    private var powerTouches = Set<ObjectIdentifier>()
    private var pitch: Double = 0
    private var keyPitch: Double = 0
    private var keyPower = false

    var input: PlaneInput {
        PlaneInput(pitch: pitch != 0 ? pitch : keyPitch, power: !powerTouches.isEmpty || keyPower)
    }

    #if os(iOS)
    func began(_ touch: UITouch, in scene: SKScene) {
        let p = touch.location(in: scene.view)
        let id = ObjectIdentifier(touch)
        if p.x < (scene.view?.bounds.width ?? 0) / 2 {
            if pitchTouch == nil { pitchTouch = (id, p) }
        } else {
            powerTouches.insert(id)
        }
    }

    func moved(_ touch: UITouch, in scene: SKScene) {
        guard let pt = pitchTouch, pt.id == ObjectIdentifier(touch) else { return }
        let p = touch.location(in: scene.view)
        // Screen y grows downward; dragging the thumb down pulls the nose up.
        pitch = Double(min(1, max(-1, (p.y - pt.origin.y) / throwDistance)))
    }

    func ended(_ touch: UITouch) {
        let id = ObjectIdentifier(touch)
        if pitchTouch?.id == id {
            pitchTouch = nil
            pitch = 0
        }
        powerTouches.remove(id)
    }
    #endif

    #if os(macOS)
    func keyboard(_ press: KeyPress) {
        let down = press.phase == .down
        switch press.key {
        case .upArrow: keyPitch = down ? 1 : (keyPitch > 0 ? 0 : keyPitch)
        case .downArrow: keyPitch = down ? -1 : (keyPitch < 0 ? 0 : keyPitch)
        case .space: keyPower = down
        default: break
        }
    }
    #endif
}
