import Combine
import QuackCore

/// What the SwiftUI layer needs to know about the run, published by the scene
/// when it changes: whether the plane is parked, and the board at the field.
@MainActor
public final class HUDState: ObservableObject {
    @Published public var parked = false
    @Published public var board: [Contract] = []
    @Published public var chosen = 0
    @Published public var carrying: Contract?
    @Published public var fieldNames: [String] = []
}
