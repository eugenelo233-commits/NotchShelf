// Event routing is adapted from jordanbaird/Ice (GPL-3.0).
// See THIRD_PARTY.md and LICENSE in the distribution.
import AppKit
import ApplicationServices

enum ShelfError: LocalizedError {
    case permission, missingItem, eventFailed, moveFailed, busy, noSpace
    var errorDescription: String? {
        switch self {
        case .permission: return "请先在系统设置中允许「折叠栏」使用辅助功能。"
        case .missingItem: return "这个菜单栏图标已退出或发生变化，请刷新列表后重试。"
        case .eventFailed: return "系统未接收菜单栏操作。请检查辅助功能权限，然后重试。"
        case .moveFailed: return "这个图标未能移动。可以先展开全部，再按住 ⌘ 手动拖到分隔线左侧。"
        case .busy: return "请松开鼠标和修饰键后再操作。"
        case .noSpace: return "刘海右侧空间不足，请先减少常驻图标。"
        }
    }
}

@MainActor private final class EventRelay {
    let event: CGEvent, pid: pid_t, token: Int64
    var ports: [CFMachPort] = [], sources: [CFRunLoopSource] = []
    var continuation: CheckedContinuation<Void, Error>?
    var sent = false, finished = false
    init(event: CGEvent, pid: pid_t) {
        self.event=event; self.pid=pid; token=Int64.random(in:1...Int64.max)
        event.setIntegerValueField(.eventSourceUserData,value:token)
    }
    func finish(_ error: Error? = nil) {
        guard !finished else { return }; finished=true
        for port in ports { CGEvent.tapEnable(tap:port,enable:false); CFMachPortInvalidate(port) }
        for source in sources { CFRunLoopRemoveSource(CFRunLoopGetMain(),source,.commonModes) }
        if let error { continuation?.resume(throwing:error) } else { continuation?.resume() }
        continuation=nil
    }
    func receive(_ type: CGEventType, _ incoming: CGEvent) -> Unmanaged<CGEvent>? {
        guard !finished else { return Unmanaged.passUnretained(incoming) }
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput { finish(ShelfError.eventFailed); return Unmanaged.passUnretained(incoming) }
        guard incoming.getIntegerValueField(.eventSourceUserData) == token else { return Unmanaged.passUnretained(incoming) }
        if type == .null {
            if !sent { sent=true; event.post(tap:.cgSessionEventTap) }
            return nil
        }
        if type == event.type { event.postToPid(pid); finish() }
        return Unmanaged.passUnretained(incoming)
    }
    func run() async throws {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation=continuation
            let callback: CGEventTapCallBack = { _, type, event, userInfo in
                guard let userInfo else { return Unmanaged.passUnretained(event) }
                return MainActor.assumeIsolated { Unmanaged<EventRelay>.fromOpaque(userInfo).takeUnretainedValue().receive(type,event) }
            }
            let ptr=Unmanaged.passUnretained(self).toOpaque()
            guard let first=CGEvent.tapCreateForPid(pid:pid,place:.headInsertEventTap,options:.defaultTap,eventsOfInterest:1 << CGEventType.null.rawValue,callback:callback,userInfo:ptr),
                  let second=CGEvent.tapCreate(tap:.cgSessionEventTap,place:.tailAppendEventTap,options:.listenOnly,eventsOfInterest:1 << event.type.rawValue,callback:callback,userInfo:ptr) else { finish(ShelfError.eventFailed); return }
            ports=[first,second]
            for port in ports {
                let source=CFMachPortCreateRunLoopSource(kCFAllocatorDefault,port,0)!
                sources.append(source); CFRunLoopAddSource(CFRunLoopGetMain(),source,.commonModes); CGEvent.tapEnable(tap:port,enable:true)
            }
            let trigger=CGEvent(source:nil)!
            trigger.setIntegerValueField(.eventSourceUserData,value:token); trigger.postToPid(pid)
            DispatchQueue.main.asyncAfter(deadline:.now()+0.4) { [self] in finish(ShelfError.eventFailed) }
        }
    }
}

@MainActor enum ItemEvents {
    static func event(type: CGEventType, item: BarItem, pid: pid_t, point: CGPoint, command: Bool = false, right: Bool = false) throws -> CGEvent {
        guard let source=CGEventSource(stateID:.hidSystemState), let event=CGEvent(mouseEventSource:source,mouseType:type,mouseCursorPosition:point,mouseButton:right ? .right : .left) else { throw ShelfError.eventFailed }
        event.flags=command ? .maskCommand : []
        event.setIntegerValueField(.eventTargetUnixProcessID,value:Int64(pid))
        for field in [CGEventField.mouseEventWindowUnderMousePointer,.mouseEventWindowUnderMousePointerThatCanHandleThisEvent,CGEventField(rawValue:0x33)!] { event.setIntegerValueField(field,value:Int64(item.actualWindowID ?? item.id)) }
        event.setIntegerValueField(.mouseEventClickState,value:1)
        return event
    }
    static func move(_ item: BarItem, nextTo target: BarItem, left: Bool, minimumVisibleX:CGFloat? = nil) async throws {
        guard AXIsProcessTrusted() else { throw ShelfError.permission }
        guard !CGEventSource.buttonState(.combinedSessionState,button:.left), NSEvent.modifierFlags.intersection([.command,.control,.option,.shift]).isEmpty else { throw ShelfError.busy }
        guard let current=WindowServer.item(item.id), let destination=WindowServer.item(target.id) else { throw ShelfError.missingItem }
        let oldPointer=CGEvent(source:nil)?.location
        defer { if let oldPointer { CGWarpMouseCursorPosition(oldPointer) } }
        let destinationBounds=WindowServer.rawItems(includeOwn:true).first(where:{$0.id==destination.actualWindowID})?.frame ?? destination.frame
        let end=CGPoint(x:left ? destinationBounds.minX-1 : destinationBounds.maxX+1,y:destination.frame.midY)
        let host=current.hostPID ?? item.pid
        let down=try event(type:.leftMouseDown,item:current,pid:host,point:CGPoint(x:20000,y:20000),command:true)
        let up=try event(type:.leftMouseUp,item:destination,pid:host,point:end)
        do {
            try await EventRelay(event:down,pid:host).run()
            try await Task.sleep(nanoseconds:60_000_000)
            try await EventRelay(event:up,pid:host).run()
        } catch {
            let release=try? event(type:.leftMouseUp,item:current,pid:item.pid,point:CGPoint(x:current.frame.midX,y:current.frame.midY))
            release?.post(tap:.cgSessionEventTap)
            throw error
        }
        for _ in 0..<12 {
            try await Task.sleep(nanoseconds:50_000_000)
            for candidate in [current,destination] {
                if let element=candidate.element, let frame=await Task.detached(operation:{ AXInventory.frame(element) }).value,
                   let index=WindowServer.accessibilityItems.firstIndex(where:{$0.id==candidate.id}) { WindowServer.accessibilityItems[index].frame=frame }
                else if candidate.element == nil, let window=WindowServer.rawItems(includeOwn:true).first(where:{$0.id==candidate.actualWindowID}),
                        let index=WindowServer.accessibilityItems.firstIndex(where:{$0.id==candidate.id}) {
                    WindowServer.accessibilityItems[index].frame=window.frame
                    WindowServer.accessibilityItems[index].onScreen=window.onScreen
                }
            }
            if let minimumVisibleX, let moved=WindowServer.item(item.id), moved.frame != current.frame, moved.frame.minX>=minimumVisibleX { return }
            if let a=WindowServer.item(item.id), let b=WindowServer.item(target.id), left ? (a.frame.maxX <= b.frame.minX+2) : (a.frame.minX >= b.frame.maxX-2) { return }
        }
        throw ShelfError.moveFailed
    }
    static func click(_ item: BarItem, right: Bool) async throws {
        guard AXIsProcessTrusted() else { throw ShelfError.permission }
        // The host continues reflowing after the drag's first frame change.
        try await Task.sleep(nanoseconds:250_000_000)
        guard var current=WindowServer.item(item.id) else { throw ShelfError.missingItem }
        if let windowID=current.actualWindowID, let window=WindowServer.rawItems(includeOwn:true).first(where:{$0.id==windowID}) { current.frame=window.frame }
        else if let element=current.element, let frame=await Task.detached(operation:{AXInventory.frame(element)}).value { current.frame=frame }
        let point=CGPoint(x:current.frame.midX,y:current.frame.midY)
        if ProcessInfo.processInfo.arguments.contains("--diagnostics") { NSLog("ShelfClick %@ point=%@ host=%d window=%u",item.appName,NSStringFromPoint(point),current.hostPID ?? item.pid,current.actualWindowID ?? current.id) }
        guard point.x>=0, current.frame.minX != -1 else { throw ShelfError.noSpace }
        let oldPointer=CGEvent(source:nil)?.location
        CGWarpMouseCursorPosition(point)
        defer { if let oldPointer { CGWarpMouseCursorPosition(oldPointer) } }
        try await Task.sleep(nanoseconds:60_000_000)
        // Visible clicks go through WindowServer hit-testing. Explicitly targeting
        // the source PID or a synthetic scene window ID misroutes clicks on macOS 26.
        guard let source=CGEventSource(stateID:.hidSystemState),
              let down=CGEvent(mouseEventSource:source,mouseType:right ? .rightMouseDown : .leftMouseDown,mouseCursorPosition:point,mouseButton:right ? .right : .left),
              let up=CGEvent(mouseEventSource:source,mouseType:right ? .rightMouseUp : .leftMouseUp,mouseCursorPosition:point,mouseButton:right ? .right : .left) else { throw ShelfError.eventFailed }
        let mask:CGEventFilterMask=[.permitLocalMouseEvents,.permitLocalKeyboardEvents,.permitSystemDefinedEvents]
        source.setLocalEventsFilterDuringSuppressionState(mask,state:.eventSuppressionStateRemoteMouseDrag)
        source.setLocalEventsFilterDuringSuppressionState(mask,state:.eventSuppressionStateSuppressionInterval)
        source.localEventsSuppressionInterval=0
        down.flags=[]; up.flags=[]
        down.setIntegerValueField(.mouseEventClickState,value:1); up.setIntegerValueField(.mouseEventClickState,value:1)
        down.post(tap:.cghidEventTap)
        try await Task.sleep(nanoseconds:80_000_000)
        up.post(tap:.cghidEventTap)
        try await Task.sleep(nanoseconds:120_000_000)
        up.post(tap:.cghidEventTap)
        try await Task.sleep(nanoseconds:60_000_000)
    }
}
