import SwiftUI

@main
struct ZeroTrueNASApp: App {
    @StateObject private var service = TrueNASService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(service)
                .preferredColorScheme(.dark)
        }
    }
}
