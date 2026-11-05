import AppKit

@MainActor final class AppDelegate:NSObject,NSApplicationDelegate {
    var model:ShelfModel?
    func applicationDidFinishLaunching(_ notification:Notification) {
        NSApp.setActivationPolicy(.accessory)
        let model=ShelfModel(); self.model=model; model.start()
    }
    func applicationWillTerminate(_ notification:Notification) { model?.cleanup() }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender:NSApplication)->Bool { false }
    func applicationShouldHandleReopen(_ sender:NSApplication,hasVisibleWindows flag:Bool)->Bool { model?.showSettings(); return true }
}
MainActor.assumeIsolated {
    let app=NSApplication.shared
    let delegate=AppDelegate()
    app.delegate=delegate
    withExtendedLifetime(delegate) { app.run() }
}
