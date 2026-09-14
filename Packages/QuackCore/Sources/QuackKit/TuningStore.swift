import Foundation
import QuackCore

/// The dials in force on this device. The panel edits `tuning`; the game view
/// hands every change to the scene. Kept in UserDefaults while the tuning
/// panel is compiled in, so a tuned phone stays tuned between launches; a
/// build without the panel ignores anything stored and flies the defaults.
@MainActor
public final class TuningStore: ObservableObject {
    static let key = "quack.tuning"

    @Published public var tuning: Tuning {
        didSet { save() }
    }

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        #if QUACK_TUNING
        tuning = Tuning(
            values: defaults.dictionary(forKey: TuningStore.key) as? [String: Double] ?? [:])
        #else
        tuning = Tuning()
        #endif
    }

    func reset() {
        tuning = Tuning()
    }

    private func save() {
        #if QUACK_TUNING
        defaults.set(tuning.values, forKey: TuningStore.key)
        #endif
    }
}
