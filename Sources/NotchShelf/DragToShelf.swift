import AppKit
import ApplicationServices
import SwiftUI

/// Passive mouse observation: never consumes or rewrites the system's drag events.
@MainActor final class DragToShelf {
    weak var model: ShelfModel?
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var candidate: BarItem?
    private var gesture: ShelfDropGesture?
    private var hint: NSPanel?
    private var hovered = false
    private var entryWindowID: CGWindowID?
    private var liveTarget: CGRect?
    private var lastTargetPoll = Date.distantPast
    private var pending: Task<Void,Never>?
    var isActive: Bool { candidate != nil || pending != nil }

    init(model: ShelfModel) { self.model=model }
    func start() {
        guard tap == nil, AXIsProcessTrusted() else { return }
        let mask = [CGEventType.leftMouseDown,.leftMouseDragged,.leftMouseUp].reduce(CGEventMask(0)) { $0 | (1 << $1.rawValue) }
        let callback: CGEventTapCallBack = { _,type,event,context in
            guard let context else { return Unmanaged.passUnretained(event) }
            MainActor.assumeIsolated {
                Unmanaged<DragToShelf>.fromOpaque(context).takeUnretainedValue().receive(type,event)
            }
            return Unmanaged.passUnretained(event)
        }
        guard let tap=CGEvent.tapCreate(tap:.cgSessionEventTap,place:.tailAppendEventTap,options:.listenOnly,eventsOfInterest:mask,callback:callback,userInfo:Unmanaged.passUnretained(self).toOpaque()) else {
            model?.message="拖入收纳暂不可用，请检查辅助功能权限；仍可在设置中选择收纳。"; return
        }
        self.tap=tap
        let source=CFMachPortCreateRunLoopSource(kCFAllocatorDefault,tap,0)!
        self.source=source; CFRunLoopAddSource(CFRunLoopGetMain(),source,.commonModes)
        CGEvent.tapEnable(tap:tap,enable:true)
        if ProcessInfo.processInfo.arguments.contains("--diagnostics") { NSLog("ShelfDrag monitor ready") }
    }
    private func receive(_ type: CGEventType, _ event: CGEvent) {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            cancelGesture(); if let tap { CGEvent.tapEnable(tap:tap,enable:true) }; return
        }
        guard let model else { return }
        let point=event.location
        if type == .leftMouseDown {
            cancelGesture()
            if event.flags.contains(.maskCommand), ProcessInfo.processInfo.arguments.contains("--diagnostics") {
                NSLog("ShelfDrag command-down point=%@ candidates=%@",NSStringFromPoint(point),WindowServer.items().filter{$0.frame.insetBy(dx:-6,dy:-6).contains(point)}.map(\.appName).joined(separator:","))
            }
            guard !model.busy, pending == nil, model.temporary == nil, event.flags.contains(.maskCommand),
                  let entry=model.entryItem(),
                  let item=WindowServer.items().first(where:{ !$0.protected && $0.frame.contains(point) && $0.actualWindowID != nil }) else { return }
            candidate=item; gesture=ShelfDropGesture(start:point,target:entry.frame)
            entryWindowID=entry.actualWindowID; liveTarget=entry.frame; lastTargetPoll = .distantPast
            if ProcessInfo.processInfo.arguments.contains("--diagnostics") { NSLog("ShelfDrag begin %@",item.appName) }
        } else if type == .leftMouseDragged, var gesture, let item=candidate {
            gesture.update(point); self.gesture=gesture
            updateTarget()
            let over=gesture.accepts(point,liveTarget:liveTarget)
            if hint == nil || over != hovered { showHint(item,over:over,target:liveTarget ?? gesture.target) }
        } else if type == .leftMouseUp, let gesture, let item=candidate {
            updateTarget(force:true)
            let accept=gesture.accepts(point,liveTarget:liveTarget)
            cancelGesture()
            guard accept else { return }
            // Let macOS finish its native reorder and let the user release ⌘.
            // Moving while a physical modifier is held can corrupt the next drag.
            model.message="松开 ⌘，即可收纳 \(item.appName)。"
            pending=Task { @MainActor [weak self,weak model] in
                guard let self,let model else { return }
                defer { self.pending=nil }
                for _ in 0..<100 {
                    do { try await Task.sleep(nanoseconds:100_000_000) } catch { return }
                    if !CGEventSource.buttonState(.combinedSessionState,button:.left),
                       NSEvent.modifierFlags.intersection([.command,.control,.option,.shift]).isEmpty {
                        await model.acceptDroppedItem(item)
                        return
                    }
                }
                model.message="拖入收纳已取消：请在放下图标后松开 ⌘。"
            }
        }
    }
    private func updateTarget(force: Bool = false) {
        guard force || Date().timeIntervalSince(lastTargetPoll)>0.1 else { return }
        lastTargetPoll=Date()
        if let id=entryWindowID, let window=WindowServer.rawItems(includeOwn:true).first(where:{$0.id==id}) {
            liveTarget=window.frame
        }
    }
    private func showHint(_ item: BarItem, over: Bool, target: CGRect) {
        hovered=over
        if hint == nil {
            let panel=NSPanel(contentRect:.zero,styleMask:[.borderless,.nonactivatingPanel],backing:.buffered,defer:false)
            panel.isOpaque=false; panel.backgroundColor = .clear; panel.hasShadow=true
            panel.level = .statusBar; panel.ignoresMouseEvents=true; panel.hidesOnDeactivate=false
            panel.collectionBehavior=[.canJoinAllSpaces,.fullScreenAuxiliary]; hint=panel
        }
        let top=NSScreen.screens.first?.frame.maxY ?? 0
        let screen=NSScreen.screens.first(where:{$0.frame.minX<=target.midX && $0.frame.maxX>target.midX}) ?? NSScreen.main
        let width:CGFloat=220
        let x=max(screen?.visibleFrame.minX ?? 0,min(target.midX-width/2,(screen?.visibleFrame.maxX ?? target.maxX)-width-8))
        hint?.setFrame(CGRect(x:x,y:top-target.maxY-46,width:width,height:38),display:true)
        hint?.contentView=NSHostingView(rootView:
            HStack(spacing:8) {
                Image(systemName:over ? "checkmark.circle.fill" : "chevron.down.2").foregroundStyle(over ? Color.accentColor : Color.primary)
                Text(over ? "松开以收纳 \(item.appName)" : "拖到双箭头上即可收纳").font(.system(size:12)).lineLimit(1)
            }.padding(10).frame(width:width,height:38).background(MaterialView()).clipShape(RoundedRectangle(cornerRadius:10)))
        hint?.orderFrontRegardless()
        model?.entry.button?.highlight(over)
    }
    private func cancelGesture() {
        candidate=nil; gesture=nil; hint?.orderOut(nil); hint=nil; hovered=false
        entryWindowID=nil; liveTarget=nil
        model?.entry.button?.highlight(false)
    }
    func stop() {
        pending?.cancel(); pending=nil; cancelGesture()
        if let tap { CGEvent.tapEnable(tap:tap,enable:false); CFMachPortInvalidate(tap) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(),source,.commonModes) }
        tap=nil; source=nil
    }
}
