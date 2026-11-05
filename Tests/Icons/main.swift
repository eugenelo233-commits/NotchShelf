import AppKit

func check(_ value:Bool,_ name:String) { precondition(value,name); print("PASS: \(name)") }
@MainActor func run() {
    func bitmap(background:CGColor?,glyph:CGColor)->NSImage {
        let c=CGContext(data:nil,width:48,height:48,bitsPerComponent:8,bytesPerRow:192,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
        if let background { c.setFillColor(background); c.fill(CGRect(x:0,y:0,width:48,height:48)) }
        c.setFillColor(glyph); c.fill(CGRect(x:18,y:8,width:12,height:32))
        return NSImage(cgImage:c.makeImage()!,size:NSSize(width:24,height:24))
    }
    func alpha(_ image:NSImage,_ x:Int,_ y:Int)->Int {
        let c=CGContext(data:nil,width:48,height:48,bitsPerComponent:8,bytesPerRow:192,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
        c.draw(image.cgImage(forProposedRect:nil,context:nil,hints:nil)!,in:CGRect(x:0,y:0,width:48,height:48))
        return Int(c.data!.assumingMemoryBound(to:UInt8.self)[(y*48+x)*4+3])
    }
    let white=CGColor(gray:1,alpha:1),black=CGColor(gray:0,alpha:1)
    let original=bitmap(background:white,glyph:black)
    let light=ShelfIconRenderer.monochrome(original)
    check(light.isTemplate,"单色图标使用随系统适配的模板渲染")
    check(alpha(light,4,4)==0 && alpha(light,24,24)>200,"去除浅色背景并保留图形")
    check(alpha(original,4,4)==255,"转换不修改原始彩色图标")
    let dark=ShelfIconRenderer.monochrome(bitmap(background:black,glyph:white))
    check(alpha(dark,4,4)==0 && alpha(dark,24,24)>200,"去除深色背景并保留图形")
    let transparent=ShelfIconRenderer.monochrome(bitmap(background:nil,glyph:white))
    check(alpha(transparent,4,4)==0 && alpha(transparent,24,24)>200,"原始透明图形保持透明边缘")
}
MainActor.assumeIsolated { run() }
print("5 icon checks passed")
