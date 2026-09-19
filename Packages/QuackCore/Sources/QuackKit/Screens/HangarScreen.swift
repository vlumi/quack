import QuackCore
import SwiftUI

/// The hangar: what the company has and what it can buy. Each upgrade shows
/// its level and the price of the next; a courier run starts with them.
struct HangarScreen: View {
    @ObservedObject var store: CareerStore
    let close: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Text("Hangar", bundle: .module)
                .font(.custom("AvenirNext-Heavy", size: 30, relativeTo: .title))
                .foregroundStyle(TitleScreen.ink)
            Text("\(Int(store.career.money.rounded())) fr in the till", bundle: .module)
                .font(.custom("AvenirNext-DemiBold", size: 16, relativeTo: .body))
                .foregroundStyle(TitleScreen.ink.opacity(0.75))
            VStack(spacing: 8) {
                ForEach(Career.Upgrade.allCases, id: \.self) { upgrade in
                    row(upgrade)
                }
            }
            .frame(width: 440)
            MenuButton(title: Text("Back", bundle: .module), primary: false, action: close)
        }
        .padding(.vertical, 22)
        .padding(.horizontal, 32)
        .background(TitleScreen.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(TitleScreen.ink.opacity(0.25), lineWidth: 1.5))
    }

    private func row(_ upgrade: Career.Upgrade) -> some View {
        let career = store.career
        let level = career.level(upgrade)
        return HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                name(upgrade)
                    .font(.custom("AvenirNext-Bold", size: 17, relativeTo: .body))
                    .foregroundStyle(TitleScreen.ink)
                detail(upgrade, level: level)
                    .font(.custom("AvenirNext-Medium", size: 13, relativeTo: .caption))
                    .foregroundStyle(TitleScreen.ink.opacity(0.7))
            }
            Spacer(minLength: 12)
            if let price = career.nextPrice(upgrade) {
                buyButton(upgrade, price: price, affordable: career.canBuy(upgrade))
            } else {
                Text("Bought", bundle: .module)
                    .font(.custom("AvenirNext-Bold", size: 15, relativeTo: .body))
                    .foregroundStyle(TitleScreen.ink.opacity(0.6))
            }
        }
    }

    private func buyButton(_ upgrade: Career.Upgrade, price: Double, affordable: Bool) -> some View
    {
        Button {
            store.career.buy(upgrade)
        } label: {
            Text("Buy, \(Int(price)) fr", bundle: .module)
                .font(.custom("AvenirNext-Bold", size: 15, relativeTo: .body))
                .padding(.vertical, 7)
                .padding(.horizontal, 14)
                .foregroundStyle(affordable ? Color.white : TitleScreen.ink.opacity(0.5))
                .background(
                    affordable ? TitleScreen.trim : TitleScreen.ink.opacity(0.12), in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!affordable)
    }

    private func name(_ upgrade: Career.Upgrade) -> Text {
        switch upgrade {
        case .tank: return Text("Bigger tank", bundle: .module)
        case .engine: return Text("Stronger engine", bundle: .module)
        case .seat: return Text("Second seat", bundle: .module)
        }
    }

    private func detail(_ upgrade: Career.Upgrade, level: Int) -> Text {
        switch upgrade {
        case .tank:
            return Text(
                "Level \(level) of \(upgrade.maxLevel): +\(Int(upgrade.tankPerLevel)) s of engine each",
                bundle: .module)
        case .engine:
            return Text("Level \(level) of \(upgrade.maxLevel): more thrust each", bundle: .module)
        case .seat:
            return Text("Two passengers a job, two fares", bundle: .module)
        }
    }
}
