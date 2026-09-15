import QuackCore
import SpriteKit
import SwiftUI

/// The whole game on screen: the SpriteKit scene in its fixed 16:9 box,
/// letterboxed in a dark frame on any other shape of screen or window, with
/// the tuning panel a shake (or ⌥⌘T) away. The title screen sits over the
/// running world and picks what to fly; a run can be paused and quit back to
/// it (the button at the bottom, or Escape on the Mac).
public struct GameView: View {
    /// Where the player is: at the title, flying, or paused.
    enum Screen {
        case title
        case playing
        case paused
    }

    @StateObject private var overlay: ThumbOverlayState
    @StateObject private var tuning: TuningStore
    @State private var scene: FlightScene
    @State private var screen = Screen.title
    #if os(macOS)
    @FocusState private var focused: Bool
    #endif

    public init() {
        let overlay = ThumbOverlayState()
        let tuning = TuningStore()
        let scene = FlightScene(overlay: overlay)
        scene.tuning = tuning.tuning
        scene.attract = true
        _overlay = StateObject(wrappedValue: overlay)
        _tuning = StateObject(wrappedValue: tuning)
        _scene = State(initialValue: scene)
    }

    public var body: some View {
        game
            .overlay(menus)
            .onReceive(tuning.$tuning) { scene.tuning = $0 }
            .tuningPanel(store: tuning) { open in
                scene.simulationPaused = open || screen == .paused
                #if os(macOS)
                // The sheet took keyboard focus; hand it back so the arrows fly again.
                if !open { focused = true }
                #endif
            }
    }

    /// The title over the attract world, or the pause button and menu over a run.
    @ViewBuilder private var menus: some View {
        switch screen {
        case .title:
            TitleScreen(store: tuning) { mode in
                scene.start(mode)
                scene.attract = false
                screen = .playing
            }
        case .playing:
            VStack {
                Spacer()
                PauseButton { pause() }
                    .padding(.bottom, 12)
            }
        case .paused:
            PauseMenu(
                resume: {
                    scene.simulationPaused = false
                    screen = .playing
                },
                quit: {
                    scene.simulationPaused = false
                    scene.attract = true
                    screen = .title
                })
        }
    }

    private func pause() {
        guard screen == .playing else { return }
        scene.simulationPaused = true
        screen = .paused
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
            if press.key == .escape {
                if press.phase == .down { pause() }
                return .handled
            }
            scene.keyboard(press)
            return .handled
        }
        #else
        // Full bleed: the scene letterboxes itself and the bars stay touch
        // surface. The thumb pads draw over everything, bars included.
        view.ignoresSafeArea().background(frame.ignoresSafeArea())
            .overlay(
                ThumbOverlay(state: overlay, pitchInverted: tuning.tuning.invertedPitch)
                    .ignoresSafeArea()
                    .opacity(screen == .playing ? 1 : 0))
        #endif
    }
}
