import Foundation
import CoreGraphics

var count=0
func check(_ condition: @autoclosure ()->Bool, _ name:String) {
    guard condition() else { fatalError("FAIL: \(name)") }
    count += 1; print("PASS: \(name)")
}
let right=Layout.panelOrigin(anchor:CGRect(x:1430,y:900,width:28,height:24),size:CGSize(width:640,height:56),visible:CGRect(x:0,y:0,width:1440,height:900),top:900)
check(right.x>=8 && right.x+640<=1432,"横条保持在屏幕右边界以内")
check(right.y+56==892,"横条在菜单栏下方避开刘海")
let left=Layout.panelOrigin(anchor:CGRect(x:-1910,y:1000,width:28,height:24),size:CGSize(width:360,height:56),visible:CGRect(x:-1920,y:0,width:1920,height:1000),top:1000)
check(left.x == -1912,"左侧外接屏负坐标正确")
let divider=CGRect(x:-9000,y:0,width:10000,height:24)
check(Layout.isLeft(CGRect(x:-9040,y:0,width:24,height:24),of:divider),"宽分隔线左侧的隐藏图标被识别")
check(!Layout.isLeft(CGRect(x:1010,y:0,width:24,height:24),of:divider),"右侧常驻图标不误分类")
let safe=CGRect(x:840,y:0,width:672,height:38)
check(!Layout.entryFits(CGRect(x:740,y:4,width:30,height:24),in:safe),"屏幕内但位于刘海区域的入口不算可见")
check(!Layout.entryFits(CGRect(x:830,y:4,width:30,height:24),in:safe),"部分被刘海遮住的入口不算可见")
check(Layout.entryFits(CGRect(x:1330,y:4,width:30,height:24),in:safe),"刘海右侧完整入口算可见")
check(!Layout.entryFits(CGRect(x:-1,y:981,width:30,height:24),in:safe),"系统停放在屏幕外的入口不算可见")
var drop=ShelfDropGesture(start:CGPoint(x:1200,y:16),target:CGRect(x:1284,y:4,width:30,height:24))
check(!drop.accepts(CGPoint(x:1299,y:16)),"未开始拖动时不能触发收纳")
drop.update(CGPoint(x:1299,y:16))
check(drop.accepts(CGPoint(x:1299,y:16)),"拖到入口范围内允许收纳")
check(!drop.accepts(CGPoint(x:1240,y:16)),"拖到其他菜单栏位置不收纳")
check(!drop.accepts(CGPoint(x:1299,y:70)),"拖离菜单栏不收纳")
let shifted=CGRect(x:1240,y:4,width:30,height:24)
check(drop.accepts(CGPoint(x:1255,y:16),liveTarget:shifted),"系统重排后拖到入口的新位置仍可收纳")
check(drop.accepts(CGPoint(x:1299,y:16),liveTarget:shifted),"系统重排后原入口位置仍可完成放下")
var shortDrag=ShelfDropGesture(start:CGPoint(x:1298,y:16),target:CGRect(x:1284,y:4,width:30,height:24))
shortDrag.update(CGPoint(x:1300,y:16))
check(!shortDrag.accepts(CGPoint(x:1300,y:16)),"鼠标轻微抖动不算拖拽")
print("\(count) checks passed")
