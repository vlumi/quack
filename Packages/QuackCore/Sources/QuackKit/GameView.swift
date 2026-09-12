import SpriteKit
import SwiftUI

/// The whole game on screen: the SpriteKit scene in its fixed 16:9 box,
/// letterboxed in a dark frame on any other shape of screen or window.
/// Milestone 1 has no menus — the app opens straight into the air.
public struct GameView: View {
    @State private var scene = FlightScene()

    public init() {}

    public var body: some View {
        let scene = self.scene
        let frame = Color(red: 0.12, green: 0.12, blue: 0.12)
        let view = SpriteView(scene: scene, preferredFramesPerSecond: 60)
        #if os(macOS)
        // The window resizes freely; the game keeps its box inside it. Keyboard
        // stands in for the thumbs: ↓ nose up, ↑ nose down, space fires.
        return ZStack {
            frame.ignoresSafeArea()
            view.aspectRatio(16 / 9, contentMode: .fit)
        }
        .focusable().focusEffectDisabled()
        .onKeyPress(phases: [.down, .up]) { press in
            scene.keyboard(press)
            return .handled
        }
        #else
        // Full bleed: the scene letterboxes itself and the bars stay touch surface.
        return view.ignoresSafeArea().background(frame.ignoresSafeArea())
        #endif
    }
}
