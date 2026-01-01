import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        AppState.shared.start()
        if !UserDefaults.standard.bool(forKey: "didShowPermissions") {
            UserDefaults.standard.set(true, forKey: "didShowPermissions")
            AppState.shared.statusBarController.showPermissions()
        }
    }
}
