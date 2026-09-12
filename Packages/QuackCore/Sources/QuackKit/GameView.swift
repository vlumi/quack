import SpriteKit
import SwiftUI

/// The whole game on screen: the SpriteKit scene, full-bleed, landscape.
/// Milestone 1 has no menus — the app opens straight into the air.
public struct GameView: View {
    @State private var scene = FlightScene()

    public init() {}

    public var body: some View {
        let scene = self.scene
        let view = SpriteView(scene: scene, preferredFramesPerSecond: 60).ignoresSafeArea()
        #if os(macOS)
        // Keyboard stands in for the thumb on the Mac: ↓ nose up, ↑ nose down.
        return view.focusable().focusEffectDisabled()
            .onKeyPress(phases: [.down, .up]) { press in
                scene.keyboard(press)
                return .handled
            }
        #else
        return view
        #endif
    }
}
