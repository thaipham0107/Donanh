import SwiftUI

@main
struct DonAnhApp: App {
    @StateObject private var lib = PhotoLibrary()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(lib)
        }
    }
}
