import QuackCore
import SwiftUI

/// The Duckfight lobby: host or join; the host sees who is seated, sets the
/// fight up and starts it; a guest picks a host and waits.
struct LobbyScreen: View {
    @ObservedObject var session: FightSession
    @Binding var options: DuckfightOptions
    let start: () -> Void
    let back: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Text("Duckfight", bundle: .module)
                .font(.custom("AvenirNext-Heavy", size: 30, relativeTo: .title))
                .foregroundStyle(TitleScreen.ink)
            content
            MenuButton(title: Text("Back", bundle: .module), primary: false) {
                session.leave()
                back()
            }
        }
        .padding(.vertical, 22)
        .padding(.horizontal, 32)
        .frame(width: 520)
        .background(TitleScreen.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(TitleScreen.ink.opacity(0.25), lineWidth: 1.5))
    }

    @ViewBuilder private var content: some View {
        switch session.phase {
        case .idle:
            Text(
                "Two to four planes over nearby devices, one strip, most kills wins.",
                bundle: .module
            )
            .font(.custom("AvenirNext-DemiBold", size: 15, relativeTo: .body))
            .foregroundStyle(TitleScreen.ink.opacity(0.75))
            .multilineTextAlignment(.center)
            HStack(spacing: 10) {
                SmallButton(title: Text("Host a fight", bundle: .module)) { session.host() }
                SmallButton(title: Text("Join a fight", bundle: .module)) { session.join() }
            }
        case .hosting:
            roster
            settings
            SmallButton(title: Text("Start", bundle: .module), action: start)
        case .joining:
            Text("Looking for hosts nearby…", bundle: .module)
                .font(.custom("AvenirNext-DemiBold", size: 15, relativeTo: .body))
                .foregroundStyle(TitleScreen.ink.opacity(0.75))
            if let refusal = session.refusal {
                Text(refusal)
                    .font(.custom("AvenirNext-DemiBold", size: 14, relativeTo: .body))
                    .foregroundStyle(TitleScreen.trim)
            }
            ForEach(session.visibleHosts, id: \.self) { host in
                SmallButton(title: Text(verbatim: DeviceName.display(host))) {
                    session.askToJoin(host)
                }
            }
        case .awaitingSeat:
            Text("Asking to join…", bundle: .module)
                .font(.custom("AvenirNext-DemiBold", size: 15, relativeTo: .body))
                .foregroundStyle(TitleScreen.ink.opacity(0.75))
        case .lobby:
            roster
            Text("Waiting for the host to start", bundle: .module)
                .font(.custom("AvenirNext-DemiBold", size: 15, relativeTo: .body))
                .foregroundStyle(TitleScreen.ink.opacity(0.75))
        case .fighting:
            Text("Fighting", bundle: .module)
        case .ended(let reason):
            Text(reason)
                .font(.custom("AvenirNext-DemiBold", size: 15, relativeTo: .body))
                .foregroundStyle(TitleScreen.trim)
        }
    }

    private var roster: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(session.roster.entries, id: \.seat) { entry in
                HStack {
                    Text(verbatim: "\(entry.seat + 1).")
                    Text(verbatim: entry.name)
                    if entry.peer == session.me {
                        Text("(you)", bundle: .module).opacity(0.6)
                    }
                    if entry.seat == 0 {
                        Text("host", bundle: .module).opacity(0.6)
                    }
                }
                .font(.custom("AvenirNext-DemiBold", size: 15, relativeTo: .body))
                .foregroundStyle(TitleScreen.ink)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var settings: some View {
        VStack(spacing: 8) {
            Stepper(
                value: $options.rivals,
                in: 0...max(0, FightRoster.maxSeats - session.roster.humanCount)
            ) {
                Text("Rivals to fill: \(options.rivals)", bundle: .module)
            }
            Toggle(isOn: $options.guns) { Text("Anti-aircraft guns", bundle: .module) }
                .toggleStyle(.switch)
                .tint(TitleScreen.trim)
            Stepper(value: $options.duration, in: 60...600, step: 60) {
                Text("\(Int(options.duration) / 60) minutes", bundle: .module)
            }
        }
        .font(.custom("AvenirNext-DemiBold", size: 15, relativeTo: .body))
        .foregroundStyle(TitleScreen.ink)
    }
}

/// The fight is over: the standings, and the way back.
struct FightOverScreen: View {
    let standings: [HUDState.Standing]
    let back: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Text("Fight over", bundle: .module)
                .font(.custom("AvenirNext-Heavy", size: 30, relativeTo: .title))
                .foregroundStyle(TitleScreen.ink)
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(standings.enumerated()), id: \.offset) { i, s in
                    HStack {
                        Text(verbatim: "\(i + 1).")
                        Text(verbatim: s.name).fontWeight(s.isMe ? .heavy : .regular)
                        Spacer()
                        Text("\(s.kills) downed, \(s.downs) down", bundle: .module)
                    }
                    .font(.custom("AvenirNext-DemiBold", size: 16, relativeTo: .body))
                    .foregroundStyle(TitleScreen.ink)
                }
            }
            .frame(width: 360)
            MenuButton(title: Text("Back to lobby", bundle: .module), primary: true, action: back)
        }
        .padding(.vertical, 22)
        .padding(.horizontal, 32)
        .background(TitleScreen.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(TitleScreen.ink.opacity(0.25), lineWidth: 1.5))
    }
}
