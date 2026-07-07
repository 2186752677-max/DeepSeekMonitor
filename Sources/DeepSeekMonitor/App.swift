import SwiftUI

@main
struct DeepSeekMonitorApp: App {
    @StateObject private var appState = AppState()

    init() {
        // Hide from Dock — menu bar only
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(appState)
        } label: {
            menuBarLabel
        }

        Window("DeepSeek Monitor 设置", id: "settings") {
            SettingsView()
                .environmentObject(appState)
                .frame(minWidth: 450, minHeight: 400)
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
    }

    // MARK: - Menu Bar Label

    @ViewBuilder
    private var menuBarLabel: some View {
        if appState.isLoading && appState.balanceInfo == nil {
            Image(systemName: "arrow.triangle.2.circlepath")
                .imageScale(.small)
        } else if appState.balanceInfo == nil && appState.errorMessage != nil {
            Image(systemName: "exclamationmark.triangle.fill")
                .imageScale(.small)
        } else if let balance = appState.balanceInfo {
            Text(balance.formattedCompact)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
        } else {
            Image(systemName: "brain.head.profile")
                .imageScale(.small)
        }
    }
}
