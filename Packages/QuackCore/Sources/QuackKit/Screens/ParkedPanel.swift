import QuackCore
import SwiftUI

/// What a parked plane can do, as buttons: pick a job from the board, and
/// take off one way or the other. The stick and the trigger are for the air.
struct ParkedPanel: View {
    @ObservedObject var state: HUDState
    let pick: (Int) -> Void
    let takeOff: (Double) -> Void

    var body: some View {
        VStack(spacing: 10) {
            if let carrying = state.carrying {
                Text(job(carrying) + " " + String(localized: "aboard", bundle: .module))
                    .font(.custom("AvenirNext-DemiBold", size: 15, relativeTo: .body))
                    .foregroundStyle(TitleScreen.ink.opacity(0.8))
            } else if !state.board.isEmpty {
                HStack(spacing: 8) {
                    ForEach(state.board.indices, id: \.self) { i in
                        card(state.board[i], picked: i == state.chosen) { pick(i) }
                    }
                }
            }
            HStack(spacing: 10) {
                SmallButton(title: Text(verbatim: "◀ ") + Text("Take off", bundle: .module)) {
                    takeOff(-1)
                }
                SmallButton(title: Text("Take off", bundle: .module) + Text(verbatim: " ▶")) {
                    takeOff(1)
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(TitleScreen.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(TitleScreen.ink.opacity(0.25), lineWidth: 1.5))
    }

    private func job(_ c: Contract) -> String {
        let name = state.fieldNames.indices.contains(c.to) ? state.fieldNames[c.to] : ""
        return c.kind == .passenger
            ? String(localized: "Passenger to \(name)", bundle: .module)
            : String(localized: "Mail for \(name)", bundle: .module)
    }

    private func card(_ c: Contract, picked: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(job(c))
                    .font(.custom("AvenirNext-Bold", size: 15, relativeTo: .body))
                Text("\(Int(c.fare)) fr", bundle: .module)
                    .font(.custom("AvenirNext-DemiBold", size: 13, relativeTo: .caption))
                    .opacity(0.8)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 14)
            .foregroundStyle(picked ? Color.white : TitleScreen.ink)
            .background(
                picked ? TitleScreen.trim : TitleScreen.ink.opacity(0.08),
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

/// A compact capsule button for the parked panel.
struct SmallButton: View {
    let title: Text
    let action: () -> Void

    var body: some View {
        Button(action: action) { title }
            .buttonStyle(SmallButtonStyle())
    }
}

private struct SmallButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.custom("AvenirNext-Bold", size: 16, relativeTo: .body))
            .padding(.vertical, 8)
            .padding(.horizontal, 18)
            .foregroundStyle(Color.white)
            .background(TitleScreen.trim, in: Capsule())
            .contentShape(Capsule())
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}
