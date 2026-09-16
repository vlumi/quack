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
        case hangar
        case playing
        case paused
    }

    @StateObject private var overlay: ThumbOverlayState
    @StateObject private var tuning: TuningStore
    @StateObject private var careers: CareerStore
    @ObservedObject private var hud: HUDState
    @State private var scene: FlightScene
    @State private var screen = Screen.title
    #if os(macOS)
    @FocusState private var focused: Bool
    #endif

    public init() {
        let overlay = ThumbOverlayState()
        let tuning = TuningStore()
        let careers = CareerStore()
        let scene = FlightScene(overlay: overlay)
        scene.career = careers.career
        scene.onMoneyChange = { careers.career.money = $0 }
        scene.tuning = tuning.tuning
        scene.attract = true
        _overlay = StateObject(wrappedValue: overlay)
        _tuning = StateObject(wrappedValue: tuning)
        _careers = StateObject(wrappedValue: careers)
        hud = scene.hud
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
            TitleScreen(
                store: tuning,
                play: { mode in
                    scene.career = careers.career
                    scene.start(mode)
                    scene.attract = false
                    screen = .playing
                },
                hangar: { screen = .hangar })
        case .hangar:
            HangarScreen(store: careers) { screen = .title }
        case .playing:
            VStack {
                Spacer()
                if hud.parked {
                    ParkedPanel(
                        state: hud, pick: { scene.pick($0) },
                        takeOff: { scene.takeOff(direction: $0) }
                    )
                    .padding(.bottom, 8)
                }
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
            // Parked, the arrows are the takeoff buttons and the digits pick from the board.
            if hud.parked && press.phase == .down {
                switch press.key {
                case .leftArrow: scene.takeOff(direction: -1)
                case .rightArrow: scene.takeOff(direction: 1)
                case "1": scene.pick(0)
                case "2": scene.pick(1)
                default: break
                }
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
                    .opacity(screen == .playing && !hud.parked ? 1 : 0))
        #endif
    }
}
