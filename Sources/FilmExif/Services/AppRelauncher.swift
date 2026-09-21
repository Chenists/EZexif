import AppKit

/// Relaunches the app in a new process and quits this one — used after a
/// language change, since macOS reads `AppleLanguages` at process launch
/// and won't re-localize an already-running app's bundle lookups.
enum AppRelauncher {
    static func restart() {
        let bundlePath = Bundle.main.bundlePath
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        task.arguments = ["-n", bundlePath]
        try? task.run()
        NSApp.terminate(nil)
    }
}
