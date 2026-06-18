import SwiftUI

@main
struct ImageHosterApp: App {
    @StateObject private var settings = SettingsStore()
    @StateObject private var uploader = UploadViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(settings)
                .environmentObject(uploader)
                .frame(minWidth: 980, minHeight: 660)
        }
        .windowStyle(.titleBar)
    }
}
