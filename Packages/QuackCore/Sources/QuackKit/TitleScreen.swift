import QuackCore
import SwiftUI

/// The front door: the name, the two things to do, and the one setting a
/// player needs. Drawn over the running world, which is the attract mode.
struct TitleScreen: View {
    @ObservedObject var store: TuningStore
    let play: (Practice.Mode) -> Void
    let hangar: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            VStack(spacing: 6) {
                Text("Quack Express", bundle: .module)
                    .font(.custom("AvenirNext-Heavy", size: 44, relativeTo: .largeTitle))
                    .foregroundStyle(TitleScreen.ink)
                Text("A duck, a biplane, and the mail to carry.", bundle: .module)
                    .font(.custom("AvenirNext-DemiBold", size: 16, relativeTo: .headline))
                    .foregroundStyle(TitleScreen.ink.opacity(0.75))
            }
            VStack(spacing: 10) {
                MenuButton(title: Text("Courier", bundle: .module), primary: true) {
                    play(.courier)
                }
                MenuButton(title: Text("Balloon run", bundle: .module), primary: false) {
                    play(.balloons)
                }
                MenuButton(title: Text("Hangar", bundle: .module), primary: false, action: hangar)
            }
            Toggle(isOn: $store.tuning.invertedPitch) {
                Text("Invert pitch", bundle: .module)
                    .font(.custom("AvenirNext-DemiBold", size: 16, relativeTo: .body))
                    .foregroundStyle(TitleScreen.ink)
            }
            .toggleStyle(.switch)
            .tint(TitleScreen.trim)
            .frame(maxWidth: 240)
            .help(Text("Pull the thumb toward you for nose down instead of up.", bundle: .module))
        }
        .padding(.vertical, 22)
        .padding(.horizontal, 40)
        .background(TitleScreen.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(TitleScreen.ink.opacity(0.25), lineWidth: 1.5))
    }

    static let ink = Color(white: 0.12)
    static let trim = Color(red: 0.71, green: 0.29, blue: 0.24)
    static let card = Color(red: 0.97, green: 0.94, blue: 0.86).opacity(0.94)
}

/// A poster-board button: solid for the main thing, outlined for the other.
struct MenuButton: View {
    let title: Text
    let primary: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) { title }
            .buttonStyle(MenuButtonStyle(primary: primary))
    }
}

/// The capsule is the button: the whole of it takes the tap, and pressing
/// dims it. Drawn here rather than by the platform's own style, which lays
/// its own highlight over the label.
private struct MenuButtonStyle: ButtonStyle {
    let primary: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.custom("AvenirNext-Bold", size: 20, relativeTo: .title2))
            .frame(minWidth: 200)
            .padding(.vertical, 9)
            .padding(.horizontal, 24)
            .foregroundStyle(primary ? Color.white : TitleScreen.ink)
            .background(primary ? TitleScreen.trim : TitleScreen.card, in: Capsule())
            .overlay(Capsule().strokeBorder(TitleScreen.trim, lineWidth: 2.5))
            .contentShape(Capsule())
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

/// The pause menu, over the frozen run.
struct PauseMenu: View {
    let resume: () -> Void
    let quit: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Text("Paused", bundle: .module)
                .font(.custom("AvenirNext-Heavy", size: 30, relativeTo: .title))
                .foregroundStyle(TitleScreen.ink)
            MenuButton(title: Text("Resume", bundle: .module), primary: true, action: resume)
            MenuButton(title: Text("Quit to title", bundle: .module), primary: false, action: quit)
        }
        .padding(.vertical, 22)
        .padding(.horizontal, 40)
        .background(TitleScreen.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(TitleScreen.ink.opacity(0.25), lineWidth: 1.5))
    }
}

/// The small pause control at the bottom middle of the screen, between the
/// two thumbs' halves, where neither lands.
struct PauseButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "pause.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(TitleScreen.ink.opacity(0.7))
                .frame(width: 44, height: 44)
                .background(Color.white.opacity(0.35), in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Pause", bundle: .module))
    }
}
