import QuackCore
import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// **Shake the phone, or pick Debug › Tuning Panel on the Mac, to open the
/// tuning panel.** Skid Jam's pattern: a developer tool that occupies no pixels
/// and is reachable from anywhere, behind `QUACK_TUNING`, which is on unless a
/// build sets `QUACK_NO_TUNING=1`. Without the flag there is no shake hook, no
/// menu item and no panel, which is stronger than a hidden button.
enum TuningPanelRequest {
    /// Posted by the shake and by the menu item; the game view toggles the panel on it.
    static let toggle = Notification.Name("fi.misaki.quack.toggleTuningPanel")
}

#if QUACK_TUNING && canImport(UIKit)

/// UIKit's own shake recognizer, the one shake-to-undo uses, turned into the
/// panel request: no accelerometer, no thresholds, and it feels like every
/// other iOS shake because it is that gesture.
extension UIWindow {
    open override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        super.motionEnded(motion, with: event)
        guard motion == .motionShake else { return }
        NotificationCenter.default.post(name: TuningPanelRequest.toggle, object: nil)
    }
}

#endif

/// The Mac's way in: a Debug menu with the panel on ⌥⌘T. Empty without the flag.
public struct TuningCommands: Commands {
    public init() {}

    public var body: some Commands {
        #if QUACK_TUNING
        CommandMenu(Text("Debug", bundle: .module)) {
            Button {
                NotificationCenter.default.post(name: TuningPanelRequest.toggle, object: nil)
            } label: {
                Text("Tuning Panel", bundle: .module)
            }
            .keyboardShortcut("t", modifiers: [.command, .option])
        }
        #else
        EmptyCommands()
        #endif
    }
}

extension View {
    /// Present the tuning panel on request, over the game. `onPresentedChange`
    /// hears it open and close, so the game can pause. The identity without
    /// the flag.
    func tuningPanel(store: TuningStore, onPresentedChange: @escaping (Bool) -> Void) -> some View {
        #if QUACK_TUNING
        return modifier(TuningHost(store: store, onPresentedChange: onPresentedChange))
        #else
        return self
        #endif
    }
}

#if QUACK_TUNING

private struct TuningHost: ViewModifier {
    @ObservedObject var store: TuningStore
    let onPresentedChange: (Bool) -> Void
    @State private var showing = false

    func body(content: Content) -> some View {
        content
            .onAppear {
                // A simulator cannot be shaken, so a launch argument opens it for screenshots.
                if ProcessInfo.processInfo.arguments.contains("-quack-tuning") { showing = true }
            }
            .onReceive(NotificationCenter.default.publisher(for: TuningPanelRequest.toggle)) { _ in
                // Toggle, so the same shake or shortcut closes it again.
                showing.toggle()
            }
            .sheet(isPresented: $showing) {
                // A sheet, not an overlay: it blocks the controls underneath, and
                // the flight is paused while it is up.
                TuningPanel(store: store, close: { showing = false })
                    .onAppear { onPresentedChange(true) }
                    .onDisappear { onPresentedChange(false) }
            }
    }
}

/// The dials. Every change applies at once and is kept on the device; Copy puts
/// all values, with the defaults beside changed ones, on the clipboard.
struct TuningPanel: View {
    @ObservedObject var store: TuningStore
    let close: () -> Void
    @State private var copied = false

    var body: some View {
        VStack(spacing: 12) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    ForEach(TuningSection.allCases, id: \.self) { section in
                        header(title(for: section))
                        if section == .controls {
                            Toggle(isOn: $store.tuning.invertedPitch) {
                                Text("Invert pitch", bundle: .module).font(.footnote.bold())
                            }
                            .tint(.orange)
                        }
                        ForEach(TuningDial.dials(in: section)) { dial in
                            slider(dial)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            Text(
                "Changes apply at once and stay on this device. \(store.tuning.changedIDs.count) changed.",
                bundle: .module
            )
            .font(.caption2)
            .foregroundStyle(.white.opacity(0.6))
            .multilineTextAlignment(.center)
            HStack(spacing: 10) {
                pill(Text("Back", bundle: .module), action: close)
                pill(Text("Reset to defaults", bundle: .module)) { store.reset() }
                pill(copied ? Text("Copied", bundle: .module) : Text("Copy", bundle: .module)) {
                    copy()
                }
            }
        }
        .padding(20)
        .frame(maxWidth: 420)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(white: 0.1).ignoresSafeArea())
        .foregroundStyle(.white)
    }

    private func copy() {
        let text = store.tuning.report()
        #if canImport(UIKit)
        UIPasteboard.general.string = text
        #elseif canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #endif
        copied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
    }

    private func header(_ label: Text) -> some View {
        label
            .font(.caption.bold())
            .textCase(.uppercase)
            .foregroundStyle(.white.opacity(0.5))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 6)
    }

    private func slider(_ dial: TuningDial) -> some View {
        let value = Binding(
            get: { store.tuning[keyPath: dial.keyPath] },
            set: { store.tuning[keyPath: dial.keyPath] = $0 })
        let changed = store.tuning.changedIDs.contains(dial.id)
        return VStack(spacing: 2) {
            HStack {
                label(for: dial.id).font(.footnote.bold())
                Spacer()
                Text(verbatim: dial.format(value.wrappedValue))
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(changed ? .orange : .white.opacity(0.85))
            }
            Slider(value: value, in: dial.range, step: dial.step)
                .tint(.white.opacity(0.8))
        }
    }

    private func pill(_ label: Text, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            label
                .font(.footnote.bold())
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.white.opacity(0.15), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func title(for section: TuningSection) -> Text {
        switch section {
        case .flight: return Text("Flight", bundle: .module)
        case .stall: return Text("Stall", bundle: .module)
        case .landing: return Text("Landing", bundle: .module)
        case .controls: return Text("Controls", bundle: .module)
        case .gun: return Text("Gun", bundle: .module)
        case .feel: return Text("Feel", bundle: .module)
        }
    }

    // swiftlint:disable:next cyclomatic_complexity
    private func label(for id: String) -> Text {
        switch id {
        case "flight.gravity": return Text("Gravity", bundle: .module)
        case "flight.thrust": return Text("Thrust", bundle: .module)
        case "flight.cruiseSpeed": return Text("Cruise speed", bundle: .module)
        case "flight.pitchRate": return Text("Pitch rate", bundle: .module)
        case "flight.thinAirFrom": return Text("Thin air from", bundle: .module)
        case "flight.ceiling": return Text("Ceiling", bundle: .module)
        case "flight.liftDeficitSink": return Text("Slow-flight sink", bundle: .module)
        case "stall.speed": return Text("Stall speed", bundle: .module)
        case "stall.band": return Text("Stall band", bundle: .module)
        case "stall.dropRate": return Text("Nose drop", bundle: .module)
        case "stall.sink": return Text("Stall sink", bundle: .module)
        case "landing.approachAngle": return Text("Cone angle", bundle: .module)
        case "landing.approachBand": return Text("Cone width", bundle: .module)
        case "landing.coneLength": return Text("Cone length", bundle: .module)
        case "landing.diveLimit": return Text("Steepest entry", bundle: .module)
        case "landing.bounceMargin": return Text("Bounce margin", bundle: .module)
        case "landing.braking": return Text("Braking", bundle: .module)
        case "landing.takeoffAcceleration": return Text("Takeoff push", bundle: .module)
        case "landing.fieldLength": return Text("Field length", bundle: .module)
        case "landing.taxiSpeed": return Text("Taxi speed", bundle: .module)
        case "landing.turnTime": return Text("Turn time", bundle: .module)
        case "landing.repairTime": return Text("Repair time", bundle: .module)
        case "controls.throwDistance": return Text("Throw", bundle: .module)
        case "controls.minimumThrow": return Text("Minimum throw", bundle: .module)
        case "gun.muzzleSpeed": return Text("Muzzle speed", bundle: .module)
        case "gun.fireInterval": return Text("Fire interval", bundle: .module)
        case "gun.bulletLife": return Text("Round life", bundle: .module)
        case "gun.capacity": return Text("Belt size", bundle: .module)
        case "gun.rearmRate": return Text("Rearm rate", bundle: .module)
        case "feel.rollDuration": return Text("Roll time", bundle: .module)
        case "feel.hour": return Text("Hour (0 = seed's)", bundle: .module)
        default: return Text(verbatim: id)
        }
    }
}

#endif
