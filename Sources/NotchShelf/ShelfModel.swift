import AppKit
import SwiftUI
import ApplicationServices
import Carbon

@MainActor final class ShelfModel: ObservableObject {
    @Published var items: [BarItem] = []
    @Published var foldedIDs: Set<CGWindowID> = []
    @Published var collapsed = false
    @Published var busy = false
    @Published var accessibility = AXIsProcessTrusted()
    @Published var capture = CGPreflightScreenCaptureAccess()
    @Published var message = "选择需要收纳的图标，或按住 ⌘ 将图标拖到分隔线左侧。"
    @Published var error: String?
    @Published var iconRevision = 0
    @Published var spacing: Double = UserDefaults.standard.object(forKey:"spacing") as? Double ?? 8 {
        didSet { UserDefaults.standard.set(spacing,forKey:"spacing"); redrawPanel() }
    }
    @Published var closeOutside = UserDefaults.standard.object(forKey:"closeOutside") as? Bool ?? true {
        didSet { UserDefaults.standard.set(closeOutside,forKey:"closeOutside") }
    }
    @Published var shortcutEnabled = UserDefaults.standard.object(forKey:"shortcutEnabled") as? Bool ?? true {
        didSet { UserDefaults.standard.set(shortcutEnabled,forKey:"shortcutEnabled"); updateHotkey() }
    }
    @Published var autoFold = UserDefaults.standard.object(forKey:"autoFold") as? Bool ?? false {
        didSet { UserDefaults.standard.set(autoFold,forKey:"autoFold") }
    }
    let cache = IconCache()
    var entry: NSStatusItem!, divider: NSStatusItem!
    var panel: ShelfPanel?, settingsWindow: NSWindow?
    var monitor: Any?, localMonitor: Any?, timer: Timer?
    var hotkey: EventHotKeyRef?, hotkeyHandler: EventHandlerRef?
    var temporary: (id: CGWindowID, neighbor: CGWindowID?, left: Bool, initialWindows: Set<CGWindowID>, pid: pid_t, start: Date)?
    var restoreTask: Task<Void,Never>?
    var refreshInFlight = false
    var shelfDragging=false
    var dragReceiver: DragToShelf?
    var unsafeEntryReadings = 0
    var entryRepairFailures = 0
    var lastEntryRepair = Date.distantPast
    var orderedKeys = UserDefaults.standard.stringArray(forKey:"orderedKeys") ?? []
    var shelfItems: [BarItem] {
        items.filter { foldedIDs.contains($0.id) }.sorted { a,b in
            let ai=orderedKeys.firstIndex(of:a.key) ?? Int.max, bi=orderedKeys.firstIndex(of:b.key) ?? Int.max
            return ai == bi ? a.frame.minX < b.frame.minX : ai < bi
        }
    }
    func start() {
        entry=NSStatusBar.system.statusItem(withLength:28)
        entry.autosaveName="NotchShelf.Entry"
        entry.button?.setAccessibilityIdentifier("NotchShelf.Entry")
        entry.button?.image=NSImage(systemSymbolName:"chevron.down.2",accessibilityDescription:"折叠栏双箭头")
        entry.button?.toolTip="折叠栏 · ⌘拖图标到此处收纳 · 点击展开，右键管理 · ⌃⌥B"
        entry.button?.target=self; entry.button?.action=#selector(entryClicked)
        entry.button?.sendAction(on:[.leftMouseUp,.rightMouseUp])
        divider=NSStatusBar.system.statusItem(withLength:12)
        divider.autosaveName="NotchShelf.Divider"
        divider.button?.setAccessibilityIdentifier("NotchShelf.Divider")
        divider.button?.title="│"; divider.button?.toolTip="按住 ⌘ 拖动：左侧收纳，右侧常驻"
        divider.button?.target=self; divider.button?.action=#selector(dividerClicked)
        monitor=NSEvent.addGlobalMonitorForEvents(matching:[.leftMouseDown,.rightMouseDown]) { [weak self] _ in
            Task { @MainActor in if self?.closeOutside == true { self?.panel?.orderOut(nil) } }
        }
        localMonitor=NSEvent.addLocalMonitorForEvents(matching:[.keyDown,.leftMouseDown,.rightMouseDown]) { [weak self] event in
            guard let self else { return event }
            if event.type == .keyDown, event.keyCode == 53 {
                if self.shelfDragging { return event }
                self.panel?.orderOut(nil); return nil
            }
            if self.closeOutside, event.type != .keyDown, event.window !== self.panel { self.panel?.orderOut(nil) }
            return event
        }
        updateHotkey()
        dragReceiver=DragToShelf(model:self); dragReceiver?.start()
        timer=Timer.scheduledTimer(withTimeInterval:4,repeats:true) { [weak self] _ in Task { @MainActor in await self?.refresh() } }
        NSWorkspace.shared.notificationCenter.addObserver(forName:NSWorkspace.activeSpaceDidChangeNotification,object:nil,queue:.main) { [weak self] _ in
            Task { @MainActor in self?.panel?.orderOut(nil); await self?.refresh() }
        }
        NotificationCenter.default.addObserver(forName:NSApplication.didChangeScreenParametersNotification,object:nil,queue:.main) { [weak self] _ in
            Task { @MainActor in self?.panel?.orderOut(nil); await self?.refresh() }
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds:450_000_000)
            await refresh()
            if autoFold && accessibility { setCollapsed(true) }
            if !UserDefaults.standard.bool(forKey:"onboardingSeen") || !accessibility || ProcessInfo.processInfo.arguments.contains("--settings") { showSettings() }
        }
    }
    @objc func entryClicked() {
        guard dragReceiver?.isActive != true, !NSEvent.modifierFlags.contains(.command) else { return }
        if NSApp.currentEvent?.type == .rightMouseUp { showMenu() } else { togglePanel() }
    }
    @objc func dividerClicked() { setCollapsed(!collapsed) }
    func dividerItem() -> BarItem? {
        if let found=WindowServer.accessibilityItems.first(where:{$0.pid==getpid() && $0.identifier=="NotchShelf.Divider"}) { return found }
        guard let number=divider.button?.window?.windowNumber, let id=CGWindowID(exactly:number) else { return nil }
        return WindowServer.item(id)
    }
    func entryItem() -> BarItem? {
        if let found=WindowServer.accessibilityItems.first(where:{$0.pid==getpid() && $0.identifier=="NotchShelf.Entry"}) { return found }
        guard let number=entry.button?.window?.windowNumber, let id=CGWindowID(exactly:number) else { return nil }
        return WindowServer.item(id)
    }
    func scanInventory() async -> [BarItem] {
        let top=NSScreen.screens.first?.frame.maxY ?? 0
        let areas=NSScreen.screens.map { screen in
            let area=screen.auxiliaryTopRightArea ?? CGRect(x:screen.frame.midX,y:screen.visibleFrame.maxY,width:screen.frame.width/2,height:screen.frame.maxY-screen.visibleFrame.maxY)
            return CGRect(x:area.minX,y:top-area.maxY,width:area.width,height:area.height)
        }
        return await Task.detached(priority:.userInitiated) { AXInventory.scan(visibleAreas:areas) }.value
    }
    func refresh() async {
        guard !refreshInFlight, !busy, !shelfDragging else { return }
        refreshInFlight=true; defer { refreshInFlight=false }
        accessibility=AXIsProcessTrusted(); capture=CGPreflightScreenCaptureAccess()
        if accessibility { dragReceiver?.start() }
        if accessibility {
            let scanned=await scanInventory()
            guard !busy, !shelfDragging else { return }
            if !scanned.isEmpty { WindowServer.accessibilityItems=scanned }
            if ProcessInfo.processInfo.arguments.contains("--diagnostics") {
                for i in scanned { NSLog("ShelfDiagnostic %@ %@ id=%u window=%u pid=%d host=%d frame=%@",i.appName,i.identifier,i.id,i.actualWindowID ?? 0,i.pid,i.hostPID ?? 0,NSStringFromRect(i.frame)) }
            }
        }
        let found=WindowServer.items()
        if let dividerItem=dividerItem() {
            // Only manage the display containing our separator. Other screens have
            // independent coordinates and may have mirrored status-item windows.
            items=found.filter { abs($0.frame.midY - dividerItem.frame.midY) < 4 || $0.frame.minX == -1 }
            foldedIDs=Set(items.filter { $0.frame.minX == -1 || Layout.isLeft($0.frame,of:dividerItem.frame) }.map(\.id))
        } else { items=found; foldedIDs=[] }
        if let temporary { foldedIDs.insert(temporary.id) }
        if capture && (panel?.isVisible == true || settingsWindow?.isVisible == true) { await cache.update(shelfItems); iconRevision += 1 }
        await ensureEntryVisible()
    }
    // A status item can exist while being covered by the notch. Test the whole
    // button against the unobstructed right-hand menu-bar area, not just screen bounds.
    func ensureEntryVisible() async {
        guard accessibility, !busy, temporary == nil, dragReceiver?.isActive != true, let item=entryItem() else { return }
        let screen=NSScreen.screens.first { screen in
            let id=(screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? CGMainDisplayID()
            return CGDisplayBounds(id).contains(CGPoint(x:item.frame.midX,y:item.frame.midY))
        } ?? NSScreen.main ?? NSScreen.screens.first
        guard let screen else { return }
        let top=NSScreen.screens.first?.frame.maxY ?? screen.frame.maxY
        let area=screen.auxiliaryTopRightArea ?? CGRect(x:screen.frame.minX,y:screen.visibleFrame.maxY,width:screen.frame.width,height:screen.frame.maxY-screen.visibleFrame.maxY)
        let safe=CGRect(x:area.minX,y:top-area.maxY,width:area.width,height:area.height)
        guard !Layout.entryFits(item.frame,in:safe) else { unsafeEntryReadings=0; return }
        unsafeEntryReadings += 1
        guard unsafeEntryReadings>=2, entryRepairFailures<2, Date().timeIntervalSince(lastEntryRepair)>15,
              !CGEventSource.buttonState(.combinedSessionState,button:.left),
              NSEvent.modifierFlags.intersection([.command,.control,.option,.shift]).isEmpty else { return }
        lastEntryRepair=Date()
        guard let target=WindowServer.items(includeOwn:true).reversed().first(where:{
            $0.pid != getpid() && $0.actualWindowID != nil && Layout.entryFits($0.frame,in:safe) && $0.frame.minX-item.frame.width-16>safe.minX
        }) else {
            entryRepairFailures += 1
            error="折叠栏入口暂时被挤出可见区域。请通过此窗口打开收纳栏，或减少常驻图标后重试。"
            showSettings(); return
        }
        busy=true
        do {
            try await ItemEvents.move(item,nextTo:target,left:true,minimumVisibleX:safe.minX+4)
            try? await Task.sleep(nanoseconds:250_000_000)
            if let element=item.element, let frame=await Task.detached(operation:{AXInventory.frame(element)}).value,
               let index=WindowServer.accessibilityItems.firstIndex(where:{$0.id==item.id}) {
                WindowServer.accessibilityItems[index].frame=frame
            }
            guard let moved=entryItem(), Layout.entryFits(moved.frame,in:safe) else { throw ShelfError.moveFailed }
            entryRepairFailures=0; unsafeEntryReadings=0
            message="已将折叠栏箭头移到刘海右侧可见区域。"
            if ProcessInfo.processInfo.arguments.contains("--diagnostics") { NSLog("ShelfEntryRepair before=%@ after=%@ safe=%@",NSStringFromRect(item.frame),NSStringFromRect(moved.frame),NSStringFromRect(safe)) }
        } catch {
            entryRepairFailures += 1
            self.error="入口自动归位失败，可先通过设置底部的「打开收纳栏」使用。\(error.localizedDescription)"
            showSettings()
        }
        busy=false
    }
    func setCollapsed(_ value: Bool) {
        guard !busy else { return }
        if value {
            guard let anchor=entryItem(), let separator=dividerItem(),
                  separator.frame.maxX <= anchor.frame.minX + 2 else {
                error="请先按住 ⌘，把「│」分隔线拖到折叠栏箭头的左侧。"; showSettings(); return
            }
            guard accessibility else { error=ShelfError.permission.localizedDescription; showSettings(); return }
        }
        collapsed=value; divider.length=value ? 10000 : 12
        divider.button?.title=value ? "" : "│"
        entry.button?.image=NSImage(systemSymbolName:"chevron.down.2",accessibilityDescription:"折叠栏双箭头")
        UserDefaults.standard.set(true,forKey:"onboardingSeen")
        Task { @MainActor in try? await Task.sleep(nanoseconds:200_000_000); await refresh() }
    }
    func togglePanel() {
        if panel?.isVisible == true { panel?.orderOut(nil); return }
        showPanel()
        Task { @MainActor in await refresh(); redrawPanel() }
    }
    func showPanel() {
        guard !shelfDragging else { return }
        guard let screen=entry.button?.window?.screen ?? NSScreen.main ?? NSScreen.screens.first else { return }
        let screenTop=NSScreen.screens.first?.frame.maxY ?? screen.frame.maxY
        let anchor: CGRect
        if let item=entryItem(), item.frame.minX>=screen.frame.minX, item.frame.maxX<=screen.frame.maxX {
            anchor=CGRect(x:item.frame.minX,y:screenTop-item.frame.maxY,width:item.frame.width,height:item.frame.height)
        } else {
            anchor=CGRect(x:screen.visibleFrame.maxX-80,y:screen.visibleFrame.maxY,width:28,height:24)
        }
        if panel == nil { panel=ShelfPanel(contentRect:.zero,styleMask:[.borderless,.nonactivatingPanel],backing:.buffered,defer:false) }
        let width=min(CGFloat(max(1,shelfItems.count)) * (32 + spacing) + 64, min(640,screen.visibleFrame.width-24))
        let height: CGFloat=shelfItems.isEmpty ? 94 : 56
        let size=CGSize(width:shelfItems.isEmpty ? min(360,screen.visibleFrame.width-24) : width,height:height)
        let origin=Layout.panelOrigin(anchor:anchor,size:size,visible:screen.visibleFrame,top:anchor.minY)
        panel?.setFrame(CGRect(origin:origin,size:size),display:true)
        panel?.contentView=NSHostingView(rootView:ShelfView(model:self))
        panel?.title="折叠栏 · 轻巧横条"
        panel?.makeKeyAndOrderFront(nil)
    }
    func redrawPanel() { if panel?.isVisible == true { showPanel() } }
    /// A collapsed separator extends thousands of points offscreen. macOS will
    /// not accept an actual drop at its left edge, so expand only during the move.
    /// Callers hold busy throughout this transaction to prevent overlapping work.
    func moveItemToGroup(_ id: CGWindowID, hidden: Bool) async throws {
        let wasCollapsed=collapsed
        if wasCollapsed { divider.length=12; divider.button?.title="│" }
        defer {
            if wasCollapsed { divider.length=10000; divider.button?.title="" }
        }
        if wasCollapsed {
            try await Task.sleep(nanoseconds:300_000_000)
            let fresh=await scanInventory()
            if !fresh.isEmpty { WindowServer.accessibilityItems=fresh }
        }
        guard let current=WindowServer.item(id), let target=dividerItem() else { throw ShelfError.missingItem }
        if ProcessInfo.processInfo.arguments.contains("--diagnostics") { NSLog("ShelfGroupMove %@ expanded=%d source=%@ target=%@",current.appName,wasCollapsed ? 1 : 0,NSStringFromRect(current.frame),NSStringFromRect(target.frame)) }
        try await ItemEvents.move(current,nextTo:target,left:hidden)
    }
    func changeGroup(_ item: BarItem, hidden: Bool) {
        guard !busy, !item.protected else { return }
        Task { @MainActor in
            await restoreTemporary()
            guard temporary == nil else { return }
            busy=true; error=nil
            do { try await moveItemToGroup(item.id,hidden:hidden); message="已将 \(item.appName) 设为\(hidden ? "收纳栏内" : "菜单栏常驻")。" }
            catch { self.error=error.localizedDescription }
            busy=false; await refresh(); redrawPanel()
        }
    }
    func acceptDroppedItem(_ item: BarItem) async {
        guard !busy, !item.protected else { return }
        // Refresh after the native drag, before routing the item to the separator.
        await refresh()
        guard WindowServer.item(item.id) != nil, dividerItem() != nil else {
            error=ShelfError.missingItem.localizedDescription; showSettings(); return
        }
        busy=true; error=nil
        do {
            try await moveItemToGroup(item.id,hidden:true)
            busy=false
            setCollapsed(true)
            try await Task.sleep(nanoseconds:300_000_000)
            while refreshInFlight { try await Task.sleep(nanoseconds:50_000_000) }
            await refresh()
            guard foldedIDs.contains(item.id), collapsed else { throw ShelfError.moveFailed }
            message="已收纳 \(item.appName)，点击双箭头即可使用。"
            if ProcessInfo.processInfo.arguments.contains("--diagnostics") { NSLog("ShelfDrag accepted %@",item.appName) }
            showPanel()
        } catch {
            busy=false; self.error="未能收纳 \(item.appName)：\(error.localizedDescription)"; showSettings()
        }
    }
    func reorder(_ item: BarItem, delta: Int) {
        var keys=shelfItems.map(\.key)
        guard let index=keys.firstIndex(of:item.key), keys.indices.contains(index+delta) else { return }
        keys.swapAt(index,index+delta); orderedKeys=keys; UserDefaults.standard.set(keys,forKey:"orderedKeys")
        objectWillChange.send(); redrawPanel()
    }
    func setShelfDragging(_ value:Bool) {
        shelfDragging=value
        if !value { Task { @MainActor in await refresh() } }
    }
    func moveShelfItem(_ source:String, to target:String, after:Bool)->Bool {
        guard !busy else { return false }
        let keys=shelfItems.map(\.key)
        guard keys.contains(source), keys.contains(target) else { return false }
        let updated=ShelfOrder.moving(keys,source:source,target:target,after:after)
        guard updated != keys else { return true }
        objectWillChange.send()
        orderedKeys=updated+orderedKeys.filter{!keys.contains($0)}
        UserDefaults.standard.set(orderedKeys,forKey:"orderedKeys")
        message="已保存横条顺序。按住 ⌘ 拖动图标可继续调整。"
        return true
    }
    func activate(_ item: BarItem, right: Bool) {
        guard !busy else { return }
        panel?.orderOut(nil)
        Task { @MainActor in
            await restoreTemporary()
            guard temporary == nil else { showSettings(); return }
            busy=true; error=nil
            do {
                guard let current=WindowServer.item(item.id), let screen=entry.button?.window?.screen ?? NSScreen.main else { throw ShelfError.missingItem }
                let bounds=CGDisplayBounds((screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? CGMainDisplayID())
                let rightArea=screen.auxiliaryTopRightArea
                let safeMin=rightArea.map { $0.minX } ?? bounds.minX+200
                if current.frame.minX != -1 && (current.frame.minX < safeMin || !current.onScreen || foldedIDs.contains(item.id)) {
                    guard let target=WindowServer.items(includeOwn:true).first(where:{ $0.id != item.id && $0.actualWindowID != nil && $0.frame.minX-current.frame.width-12>safeMin && abs($0.frame.midY-current.frame.midY)<4 }) else { throw ShelfError.noSpace }
                    let order=WindowServer.items(includeOwn:true).filter { abs($0.frame.midY-current.frame.midY)<4 }
                    let index=order.firstIndex(where:{$0.id==item.id})
                    let next=index.flatMap { $0+1 < order.count ? order[$0+1].id : nil }
                    let initial=WindowServer.interfaceWindows(pid:item.pid)
                    // Store before moving so failed click attempts still have a recovery path.
                    temporary=(item.id,next,true,initial,item.pid,Date())
                    try await ItemEvents.move(current,nextTo:target,left:true,minimumVisibleX:safeMin)
                }
                var handled=false
                if current.frame.minX == -1, let element=item.element {
                    let action=right ? kAXShowMenuAction : kAXPressAction
                    let result=await Task.detached { AXUIElementSetMessagingTimeout(element,0.3); return AXUIElementPerformAction(element,action as CFString) }.value
                    handled=result == .success || result == .cannotComplete
                }
                if !handled { try await ItemEvents.click(item,right:right) }
                message="已请求打开 \(item.appName) 的原生菜单。"
            } catch { self.error=error.localizedDescription; showSettings() }
            busy=false
            scheduleRestore()
        }
    }
    func scheduleRestore() {
        restoreTask?.cancel()
        restoreTask=Task { @MainActor in
            for _ in 0..<120 {
                do { try await Task.sleep(nanoseconds:1_000_000_000) } catch { return }
                guard let context=temporary else { return }
                let windows=WindowServer.interfaceWindows(pid:context.pid)
                if Date().timeIntervalSince(context.start)>3 && windows.subtracting(context.initialWindows).isEmpty && !CGEventSource.buttonState(.combinedSessionState,button:.left) { await restoreTemporary(); return }
            }
            message="菜单仍在使用，图标暂留顶部；可在右键菜单中选择「归位临时图标」。"
        }
    }
    func restoreTemporary() async {
        guard !busy, let context=temporary else { return }
        guard let item=WindowServer.item(context.id) else { temporary=nil; return }
        guard let target=context.neighbor.flatMap({WindowServer.item($0)}) ?? dividerItem() else { return }
        busy=true
        do { try await ItemEvents.move(item,nextTo:target,left:context.left); temporary=nil }
        catch { self.error="临时图标归位失败：\(error.localizedDescription)" }
        busy=false; await refresh()
    }
    func requestAccessibility() {
        let options=[kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String:true] as CFDictionary
        _=AXIsProcessTrustedWithOptions(options)
        NSWorkspace.shared.open(URL(string:"x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }
    func requestCapture() { CGRequestScreenCaptureAccess(); NSWorkspace.shared.open(URL(string:"x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!) }
    func showSettings() {
        panel?.orderOut(nil)
        if settingsWindow == nil {
            let window=NSWindow(contentRect:NSRect(x:0,y:0,width:620,height:620),styleMask:[.titled,.closable,.miniaturizable,.resizable],backing:.buffered,defer:false)
            window.title="折叠栏 · 设置"; window.isReleasedWhenClosed=false
            window.contentMinSize=NSSize(width:540,height:480)
            window.contentView=NSHostingView(rootView:SettingsView(model:self)); window.center(); settingsWindow=window
        }
        NSApp.activate(ignoringOtherApps:true); settingsWindow?.makeKeyAndOrderFront(nil)
    }
    func showMenu() {
        let menu=NSMenu()
        for (title,action) in [("打开收纳栏",#selector(menuShow)),(collapsed ? "展开全部图标" : "折叠图标",#selector(menuFold)),("归位临时图标",#selector(menuRestore)),("设置…",#selector(menuSettings)),("退出折叠栏",#selector(menuQuit))] {
            let item=NSMenuItem(title:title,action:action,keyEquivalent:""); item.target=self; menu.addItem(item)
        }
        entry.menu=menu; entry.button?.performClick(nil); entry.menu=nil
    }
    @objc func menuShow() { togglePanel() }
    @objc func menuFold() { setCollapsed(!collapsed) }
    @objc func menuRestore() { Task { await restoreTemporary() } }
    @objc func menuSettings() { showSettings() }
    @objc func menuQuit() { Task { await restoreTemporary(); NSApp.terminate(nil) } }
    func updateHotkey() {
        if let hotkey { UnregisterEventHotKey(hotkey); self.hotkey=nil }
        if let hotkeyHandler { RemoveEventHandler(hotkeyHandler); self.hotkeyHandler=nil }
        guard shortcutEnabled else { return }
        var type=EventTypeSpec(eventClass:OSType(kEventClassKeyboard),eventKind:UInt32(kEventHotKeyPressed))
        let result=InstallEventHandler(GetApplicationEventTarget(),{ _,_,ptr in
            guard let ptr else { return OSStatus(eventNotHandledErr) }
            let model=Unmanaged<ShelfModel>.fromOpaque(ptr).takeUnretainedValue()
            Task { @MainActor in model.togglePanel() }; return noErr
        },1,&type,Unmanaged.passUnretained(self).toOpaque(),&hotkeyHandler)
        let id=EventHotKeyID(signature:0x4E534846,id:1)
        guard result == noErr, RegisterEventHotKey(UInt32(kVK_ANSI_B),UInt32(controlKey | optionKey),id,GetApplicationEventTarget(),0,&hotkey) == noErr else { message="快捷键 ⌃⌥B 已被占用，请用菜单栏箭头打开。"; return }
    }
    func cleanup() {
        dragReceiver?.stop()
        restoreTask?.cancel(); timer?.invalidate()
        if let monitor { NSEvent.removeMonitor(monitor) }; if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        if let hotkey { UnregisterEventHotKey(hotkey) }; if let hotkeyHandler { RemoveEventHandler(hotkeyHandler) }
        if divider != nil { divider.length=12; NSStatusBar.system.removeStatusItem(divider) }
        if entry != nil { NSStatusBar.system.removeStatusItem(entry) }
    }
}

final class ShelfPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override init(contentRect:NSRect,styleMask:NSWindow.StyleMask,backing:NSWindow.BackingStoreType,defer flag:Bool) {
        super.init(contentRect:contentRect,styleMask:styleMask,backing:backing,defer:flag)
        isOpaque=false; backgroundColor = .clear; hasShadow=true; level = .popUpMenu
        collectionBehavior=[.canJoinAllSpaces,.fullScreenAuxiliary]; hidesOnDeactivate=false; isReleasedWhenClosed=false
    }
}
