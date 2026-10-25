import SwiftUI

@main
struct NandeshoApp: App {
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                GameView(apiKey: Bundle.main.infoDictionary?["ANTHROPIC_API_KEY"] as? String ?? "")
            }
        }
    }
}
