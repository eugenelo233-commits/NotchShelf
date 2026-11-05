import AppKit

/// A real local drag destination, so Escape / failed drops never restore an item.
@MainActor final class MenuBarDropView: NSView {
    var accepts: ((String)->Bool)?
    var restore: ((String)->Void)?
    private var hovering=false
    override init(frame:NSRect) {
        super.init(frame:frame)
        registerForDraggedTypes([ItemButton.shelfType])
    }
    required init?(coder:NSCoder) { fatalError("init(coder:) has not been implemented") }
    private func key(_ sender:NSDraggingInfo)->String? {
        guard let source=sender.draggingSource as? ItemButton,
              let key=sender.draggingPasteboard.string(forType:ItemButton.shelfType),
              key==source.itemKey, accepts?(key)==true else { return nil }
        return key
    }
    override func draggingEntered(_ sender:NSDraggingInfo)->NSDragOperation { draggingUpdated(sender) }
    override func draggingUpdated(_ sender:NSDraggingInfo)->NSDragOperation {
        hovering=key(sender) != nil; needsDisplay=true
        return hovering ? .move : []
    }
    override func draggingExited(_ sender:NSDraggingInfo?) { hovering=false; needsDisplay=true }
    override func prepareForDragOperation(_ sender:NSDraggingInfo)->Bool { key(sender) != nil }
    override func performDragOperation(_ sender:NSDraggingInfo)->Bool {
        guard let key=key(sender) else { return false }
        restore?(key); return true
    }
    override func draw(_ dirtyRect:NSRect) {
        NSColor.windowBackgroundColor.withAlphaComponent(0.96).setFill(); bounds.fill()
        NSColor.controlAccentColor.withAlphaComponent(hovering ? 0.25 : 0.10).setFill(); bounds.fill()
        let text=hovering ? "松开以恢复到菜单栏" : "拖到这里，恢复到菜单栏"
        let attrs:[NSAttributedString.Key:Any]=[.font:NSFont.systemFont(ofSize:12,weight:.medium),.foregroundColor:NSColor.labelColor]
        let size=text.size(withAttributes:attrs)
        text.draw(at:NSPoint(x:(bounds.width-size.width)/2,y:(bounds.height-size.height)/2),withAttributes:attrs)
    }
}

