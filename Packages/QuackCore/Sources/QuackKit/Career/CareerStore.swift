import Foundation
import QuackCore

/// The company on this device: kept in UserDefaults as JSON, read at launch,
/// written on every change. A saved career from another version of the game
/// is dropped rather than half-read.
@MainActor
public final class CareerStore: ObservableObject {
    static let key = "quack.career"

    @Published public var career: Career {
        didSet { save() }
    }

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: CareerStore.key),
            let saved = try? JSONDecoder().decode(Career.self, from: data),
            saved.version == Career.version
        {
            career = saved
        } else {
            career = Career()
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(career) {
            defaults.set(data, forKey: CareerStore.key)
        }
    }
}
