import AppKit
import ScreenCaptureKit
import ApplicationServices

struct BarItem: Identifiable {
    let id: CGWindowID
    let pid: pid_t
    let title: String
    let appName: String
    let bundleID: String
    var frame: CGRect
    var onScreen: Bool
    var element: AXUIElement? = nil
    var identifier: String = ""
    var hostPID: pid_t? = nil
    var actualWindowID: CGWindowID? = nil
    var key: String { "\(bundleID)|\(identifier.isEmpty ? title : identifier)" }
    var name: String { title.isEmpty || title == appName ? appName : "\(appName) · \(title)" }
    var protected: Bool { bundleID == "com.apple.controlcenter" || bundleID == "com.apple.systemuiserver" || bundleID == "com.apple.Spotlight" }
    var fallbackImage: NSImage { NSRunningApplication(processIdentifier: pid)?.icon ?? NSImage(systemSymbolName: "app.dashed", accessibilityDescription: appName)! }
}

enum WindowServer {
    static var accessibilityItems: [BarItem] = []
    // Private read-only window enumeration, also used by Ice. Runtime symbol lookup
    // avoids a load-time crash if an OS update removes this API.
    static func menuIDs() -> Set<CGWindowID>? {
        typealias Connection = @convention(c) () -> Int32
        typealias List = @convention(c) (Int32, Int32, Int32, UnsafeMutablePointer<UInt32>, UnsafeMutablePointer<Int32>) -> Int32
        guard let handle = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY),
              let cp = dlsym(handle, "CGSMainConnectionID"), let lp = dlsym(handle, "CGSGetProcessMenuBarWindowList") else { return nil }
        defer { dlclose(handle) }
        let connection = unsafeBitCast(cp, to: Connection.self), list = unsafeBitCast(lp, to: List.self)
        var ids = [UInt32](repeating: 0, count: 2048), count: Int32 = 0
        guard list(connection(), 0, 2048, &ids, &count) == 0, count >= 0, count <= 2048 else { return nil }
        return Set(ids.prefix(Int(count)))
    }
    static func items(includeOwn: Bool = false) -> [BarItem] {
        if AXIsProcessTrusted(), !accessibilityItems.isEmpty {
            return accessibilityItems.filter { includeOwn || $0.pid != getpid() }
        }
        return rawItems(includeOwn:includeOwn)
    }
    static func rawItems(includeOwn: Bool = false) -> [BarItem] {
        let ids = menuIDs()
        guard let windows = CGWindowListCopyWindowInfo(.optionAll, kCGNullWindowID) as? [[String: Any]] else { return [] }
        return windows.compactMap { w -> BarItem? in
            guard let id = w[kCGWindowNumber as String] as? UInt32,
                  let pid = w[kCGWindowOwnerPID as String] as? Int32,
                  let bounds = w[kCGWindowBounds as String] as? [String:Any],
                  let frame = CGRect(dictionaryRepresentation: bounds as CFDictionary),
                  frame.height > 0, frame.height <= 64, frame.width > 0,
                  (w[kCGWindowLayer as String] as? Int) == 25,
                  includeOwn || pid != getpid() else { return nil }
            if let ids { guard ids.contains(id) else { return nil } }
            else { guard (w[kCGWindowLayer as String] as? Int) == 25 else { return nil } }
            let app = NSRunningApplication(processIdentifier: pid)
            return BarItem(id:id, pid:pid, title:w[kCGWindowName as String] as? String ?? "", appName:app?.localizedName ?? w[kCGWindowOwnerName as String] as? String ?? "菜单栏图标", bundleID:app?.bundleIdentifier ?? "pid:\(pid)", frame:frame, onScreen:w[kCGWindowIsOnscreen as String] as? Bool ?? false)
        }.sorted { $0.frame.minX < $1.frame.minX }
    }
    static func item(_ id: CGWindowID) -> BarItem? { items(includeOwn:true).first { $0.id == id } }
    static func interfaceWindows(pid: pid_t) -> Set<CGWindowID> {
        let list = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] ?? []
        return Set(list.compactMap { w in
            guard w[kCGWindowOwnerPID as String] as? Int32 == pid,
                  let b = w[kCGWindowBounds as String] as? [String:Any],
                  let r = CGRect(dictionaryRepresentation:b as CFDictionary), r.height > 64 else { return nil }
            return w[kCGWindowNumber as String] as? UInt32
        })
    }
}

// macOS 26 hosts status windows in Control Center. The original app's
// AXExtrasMenuBar remains the authoritative source for identity and geometry.
// This discovery strategy is also used by Thaw (GPL-3.0), see attribution.
enum AXInventory {
    private struct HostedOwner: Codable, Equatable {
        let pid:pid_t
        let bundle:String
        let launched:TimeInterval
    }
    private static var hostedOwners:[String:HostedOwner] = {
        guard let data=UserDefaults.standard.data(forKey:"hostedWindowOwnersV2"),
              let owners=try? PropertyListDecoder().decode([String:HostedOwner].self,from:data) else { return [:] }
        return owners
    }()
    static func attribute(_ element:AXUIElement,_ name:String)->CFTypeRef? {
        var value:CFTypeRef?
        guard AXUIElementCopyAttributeValue(element,name as CFString,&value) == .success else { return nil }
        return value
    }
    static func frame(_ element:AXUIElement)->CGRect? {
        if let value=attribute(element,"AXFrame"), CFGetTypeID(value)==AXValueGetTypeID() {
            var rect=CGRect.zero
            if AXValueGetValue(unsafeDowncast(value,to:AXValue.self),.cgRect,&rect) { return rect }
        }
        guard let p=attribute(element,kAXPositionAttribute),let s=attribute(element,kAXSizeAttribute), CFGetTypeID(p)==AXValueGetTypeID(),CFGetTypeID(s)==AXValueGetTypeID() else { return nil }
        var point=CGPoint.zero; var size=CGSize.zero
        guard AXValueGetValue(unsafeDowncast(p,to:AXValue.self),.cgPoint,&point),AXValueGetValue(unsafeDowncast(s,to:AXValue.self),.cgSize,&size) else { return nil }
        return CGRect(origin:point,size:size)
    }
    static func stableID(_ text:String)->UInt32 { text.utf8.reduce(UInt32(2166136261)) { ($0 ^ UInt32($1)) &* 16777619 } | 0x80000000 }
    static func scan(visibleAreas:[CGRect])->[BarItem] {
        guard AXIsProcessTrusted() else { return [] }
        let windows=WindowServer.rawItems(includeOwn:true)
        var result:[BarItem]=[]
        let start=Date()
        let apps=NSWorkspace.shared.runningApplications.sorted { ($0.processIdentifier==getpid() ? 0 : 1) < ($1.processIdentifier==getpid() ? 0 : 1) }
        for app in apps {
            if Date().timeIntervalSince(start)>4 { break }
            let element=AXUIElementCreateApplication(app.processIdentifier)
            AXUIElementSetMessagingTimeout(element,0.08)
            guard let value=attribute(element,kAXExtrasMenuBarAttribute),CFGetTypeID(value)==AXUIElementGetTypeID() else { continue }
            let bar=unsafeDowncast(value,to:AXUIElement.self)
            guard let children=attribute(bar,kAXChildrenAttribute) as? [AXUIElement] else { continue }
            for (index,child) in children.enumerated() {
                AXUIElementSetMessagingTimeout(child,0.08)
                guard let rect=frame(child),rect.height>0,rect.height<=64,rect.width>0 else { continue }
                let identifier=attribute(child,kAXIdentifierAttribute) as? String ?? ""
                let title=(attribute(child,kAXTitleAttribute) as? String).flatMap{$0.isEmpty ? nil : $0} ?? (attribute(child,kAXDescriptionAttribute) as? String) ?? ""
                let name=app.localizedName ?? "菜单栏图标"
                let bundle=app.bundleIdentifier ?? "pid:\(app.processIdentifier)"
                let identity=identifier.isEmpty ? "\(title)|\(index)" : identifier
                let matched=windows.first { abs($0.frame.midX-rect.midX)<3 && abs($0.frame.midY-rect.midY)<5 && $0.frame.width>=rect.width-2 && $0.frame.width<=rect.width+28 }
                var item=BarItem(id:stableID("\(bundle)|\(identity)"),pid:app.processIdentifier,title:title,appName:name,bundleID:bundle,frame:rect,onScreen:matched?.onScreen ?? (rect.minX>=0))
                item.element=child; item.identifier=identity; item.hostPID=matched?.pid; item.actualWindowID=matched?.id
                result.append(item)
            }
        }
        // Control Center may mirror other apps' items. Prefer the original owner's entry.
        let originals=result.filter { $0.bundleID != "com.apple.controlcenter" }
        var discovered=result.filter { item in
            item.bundleID != "com.apple.controlcenter" || !originals.contains { abs($0.frame.midX-item.frame.midX)<2 && abs($0.frame.midY-item.frame.midY)<2 }
        }
        // Some third-party toolkits do not publish AXExtrasMenuBar. Their own
        // real status windows still identify the app; keep those as a fallback.
        let claimed=Set(discovered.compactMap(\.actualWindowID))
        let previousOwners=hostedOwners
        let liveWindowKeys=Set(windows.map{String($0.id)})
        hostedOwners=hostedOwners.filter{liveWindowKeys.contains($0.key)}
        for var window in windows where !claimed.contains(window.id) {
            if ProcessInfo.processInfo.arguments.contains("--diagnostics") { NSLog("ShelfUnclaimed %@ pid=%d window=%u frame=%@",window.appName,window.pid,window.id,NSStringFromRect(window.frame)) }
            if window.bundleID == "com.apple.controlcenter" {
                let key=String(window.id)
                if let cached=hostedOwners[key], let app=NSRunningApplication(processIdentifier:cached.pid),
                   app.bundleIdentifier == cached.bundle, app.launchDate?.timeIntervalSince1970 == cached.launched {
                    var resolved=BarItem(id:window.id,pid:cached.pid,title:"",appName:app.localizedName ?? "菜单栏图标",bundleID:cached.bundle,frame:window.frame,onScreen:window.onScreen)
                    resolved.hostPID=window.pid; resolved.actualWindowID=window.id; resolved.identifier="window:\(window.id)"
                    discovered.append(resolved); continue
                }
                hostedOwners.removeValue(forKey:key)
                // Hit-testing behind the notch or under the front app's menus
                // can return an unrelated menu. Only discover owners in clear space.
                guard visibleAreas.contains(where:{$0.insetBy(dx:0,dy:-2).contains(window.frame)}) else { continue }
                let system=AXUIElementCreateSystemWide(); AXUIElementSetMessagingTimeout(system,0.08)
                var hit:AXUIElement?
                if AXUIElementCopyElementAtPosition(system,Float(window.frame.midX),Float(window.frame.midY),&hit) == .success, let hit {
                    var owner:pid_t=0; AXUIElementGetPid(hit,&owner)
                    if ProcessInfo.processInfo.arguments.contains("--diagnostics") { NSLog("ShelfHit window=%u owner=%d role=%@",window.id,owner,attribute(hit,kAXRoleAttribute) as? String ?? "") }
                    if owner != window.pid,
                       attribute(hit,kAXRoleAttribute) as? String == kAXMenuBarItemRole,
                       let hitFrame=frame(hit), abs(hitFrame.midX-window.frame.midX)<4,
                       abs(hitFrame.midY-window.frame.midY)<5, abs(hitFrame.width-window.frame.width)<16,
                       let app=NSRunningApplication(processIdentifier:owner), let bundle=app.bundleIdentifier {
                        var resolved=BarItem(id:window.id,pid:owner,title:"",appName:app.localizedName ?? "菜单栏图标",bundleID:bundle,frame:window.frame,onScreen:window.onScreen)
                        resolved.hostPID=window.pid; resolved.actualWindowID=window.id; resolved.identifier="window:\(window.id)"
                        discovered.append(resolved)
                        if let launched=app.launchDate?.timeIntervalSince1970 { hostedOwners[key]=HostedOwner(pid:owner,bundle:bundle,launched:launched) }
                    }
                }
            }
            guard !window.protected, window.pid != getpid() else { continue }
            window.actualWindowID=window.id; window.hostPID=window.pid
            window.identifier="window:\(window.id)"
            discovered.append(window)
        }
        if hostedOwners != previousOwners, let data=try? PropertyListEncoder().encode(hostedOwners) {
            UserDefaults.standard.set(data,forKey:"hostedWindowOwnersV2")
        }
        return discovered.sorted{$0.frame.minX<$1.frame.minX}
    }
}

@MainActor final class IconCache {
    var images: [CGWindowID:NSImage] = [:]
    private var loading = false
    func update(_ items: [BarItem]) async {
        guard CGPreflightScreenCaptureAccess(), !loading else { return }
        loading = true
        defer { loading = false }
        guard let content = try? await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly:false) else { return }
        let wanted = Set(items.map(\.id))
        images = images.filter { wanted.contains($0.key) }
        for item in items {
            guard let window=content.windows.first(where:{$0.windowID == (item.actualWindowID ?? item.id)}) else { continue }
            let filter = SCContentFilter(desktopIndependentWindow:window)
            let config = SCStreamConfiguration()
            config.width = max(1, Int(window.frame.width * 2)); config.height = max(1, Int(window.frame.height * 2))
            config.showsCursor = false
            config.ignoreShadowsSingleWindow = true
            if let image = try? await SCScreenshotManager.captureImage(contentFilter:filter, configuration:config) {
                images[item.id] = NSImage(cgImage:image, size:window.frame.size)
            }
        }
    }
}
