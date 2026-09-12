import QuackKit
import SwiftUI

@main
struct QuackApp: App {
    var body: some Scene {
        // A single Window, not a WindowGroup: one game, one view of it.
        Window("Quack Express", id: "main") {
            GameView()
                .frame(minWidth: 800, minHeight: 450)
        }
    }
}
