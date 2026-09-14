import QuackCore
import SpriteKit
import SwiftUI

/// The whole game on screen: the SpriteKit scene in its fixed 16:9 box,
/// letterboxed in a dark frame on any other shape of screen or window, with
/// the tuning panel a shake (or ⌥⌘T) away. Milestone 1 has no menus — the app
/// opens straight into the air.
public struct GameView: View {
    @StateObject private var overlay: ThumbOverlayState
    @StateObject private var tuning: TuningStore
    @State private var scene: FlightScene
    #if os(macOS)
    @FocusState private var focused: Bool
    #endif

    public init() {
        let overlay = ThumbOverlayState()
        let tuning = TuningStore()
        let scene = FlightScene(overlay: overlay)
        scene.tuning = tuning.tuning
        _overlay = StateObject(wrappedValue: overlay)
        _tuning = StateObject(wrappedValue: tuning)
        _scene = State(initialValue: scene)
    }

    public var body: some View {
        game
            .onReceive(tuning.$tuning) { scene.tuning = $0 }
            .tuningPanel(store: tuning) { open in
                scene.simulationPaused = open
                #if os(macOS)
                // The sheet took keyboard focus; hand it back so the arrows fly again.
                if !open { focused = true }
                #endif
            }
    }

    @ViewBuilder private var game: some View {
        let scene = self.scene
        let frame = Color(red: 0.12, green: 0.12, blue: 0.12)
        let view = SpriteView(scene: scene, preferredFramesPerSecond: 60)
        #if os(macOS)
        // The window resizes freely; the game keeps its box inside it. Keyboard
        // stands in for the thumbs: ↓ nose up, ↑ nose down, space fires.
        ZStack {
            frame.ignoresSafeArea()
            view.aspectRatio(16 / 9, contentMode: .fit)
        }
        .focusable()
        .focused($focused)
        .focusEffectDisabled()
        .onAppear { focused = true }
        .onKeyPress(phases: [.down, .up]) { press in
            scene.keyboard(press)
            return .handled
        }
        #else
        // Full bleed: the scene letterboxes itself and the bars stay touch
        // surface. The thumb pads draw over everything, bars included.
        view.ignoresSafeArea().background(frame.ignoresSafeArea())
            .overlay(
                ThumbOverlay(state: overlay, pitchInverted: tuning.tuning.invertedPitch)
                    .ignoresSafeArea())
        #endif
    }
}
