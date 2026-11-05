import Foundation
import CoreGraphics

enum Layout {
    static func panelOrigin(anchor: CGRect, size: CGSize, visible: CGRect, top: CGFloat) -> CGPoint {
        CGPoint(x: max(visible.minX + 8, min(anchor.maxX - size.width, visible.maxX - size.width - 8)), y: top - size.height - 8)
    }
    static func isLeft(_ item: CGRect, of divider: CGRect) -> Bool { item.midX < divider.minX }
    static func entryFits(_ item: CGRect, in safeArea: CGRect) -> Bool {
        item.width > 0 && item.height > 0 && safeArea.insetBy(dx:4,dy:0).contains(item)
    }
}

/// Freeze the destination at mouse-down: macOS reflows nearby icons during a drag.
struct ShelfDropGesture {
    let start: CGPoint
    let target: CGRect
    private(set) var moved = false
    mutating func update(_ point: CGPoint) {
        if hypot(point.x-start.x,point.y-start.y)>=6 { moved=true }
    }
    func accepts(_ point: CGPoint, liveTarget: CGRect? = nil) -> Bool {
        moved && (target.insetBy(dx:-4,dy:-4).contains(point) || liveTarget?.insetBy(dx:-4,dy:-4).contains(point) == true)
    }
}

enum ShelfOrder {
    static func moving(_ keys:[String], source:String, target:String, after:Bool)->[String] {
        guard source != target, keys.contains(source), keys.contains(target) else { return keys }
        var result=keys.filter{$0 != source}
        guard let index=result.firstIndex(of:target) else { return keys }
        result.insert(source,at:index+(after ? 1 : 0))
        return result
    }
}
