import AppKit

@MainActor enum ShelfIconRenderer {
    /// Remove the dominant background from bitmap artwork, preserving glyph
    /// contrast in alpha. A template then follows the system's light/dark tint.
    static func monochrome(_ source:NSImage)->NSImage {
        let size=48
        guard let context=CGContext(data:nil,width:size,height:size,bitsPerComponent:8,bytesPerRow:size*4,
                                    space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue),
              let cg=source.cgImage(forProposedRect:nil,context:nil,hints:nil) else { return source }
        context.interpolationQuality = .high
        let factor=min(CGFloat(size)/CGFloat(cg.width),CGFloat(size)/CGFloat(cg.height))
        let w=CGFloat(cg.width)*factor, h=CGFloat(cg.height)*factor
        context.draw(cg,in:CGRect(x:(CGFloat(size)-w)/2,y:(CGFloat(size)-h)/2,width:w,height:h))
        guard let pixels=context.data else { return source }
        var bytes=Array(UnsafeBufferPointer(start:pixels.assumingMemoryBound(to:UInt8.self),count:size*size*4))
        var bins:[Int:Int]=[:]
        for i in stride(from:0,to:bytes.count,by:4) where bytes[i+3]>180 {
            let a=Double(bytes[i+3])/255
            let r=min(7,Int(Double(bytes[i])/a)/32), g=min(7,Int(Double(bytes[i+1])/a)/32), b=min(7,Int(Double(bytes[i+2])/a)/32)
            bins[(r<<6)|(g<<3)|b,default:0]+=1
        }
        let dominant=bins.max{$0.value<$1.value}?.key ?? 0
        let bg=[Double((dominant>>6)&7)*32+16,Double((dominant>>3)&7)*32+16,Double(dominant&7)*32+16]
        let opaque=bytes.enumerated().filter{$0.offset%4==3 && $0.element>180}.count
        // Sparse transparent artwork is already a useful glyph silhouette.
        let silhouette=opaque < size*size/3
        var alphaTotal=0
        let original=bytes
        for i in stride(from:0,to:bytes.count,by:4) {
            let a=Double(original[i+3])/255
            let distance=(0..<3).map{abs(Double(original[i+$0])/max(a,0.001)-bg[$0])}.max() ?? 0
            let mask=silhouette ? a : a*max(0,min(1,(distance-24)/90))
            bytes[i]=0;bytes[i+1]=0;bytes[i+2]=0;bytes[i+3]=UInt8(mask*255);alphaTotal+=Int(bytes[i+3])
        }
        // Uniform artwork must still have a visible, recognizable outline.
        if alphaTotal<6000 {
            for y in 1..<(size-1) { for x in 1..<(size-1) {
                let i=(y*size+x)*4
                let neighbors=[i-4,i+4,i-size*4,i+size*4]
                bytes[i+3]=UInt8(neighbors.map{abs(Int(original[i+3])-Int(original[$0+3]))}.max() ?? 0)
            } }
        }
        if stride(from:3,to:bytes.count,by:4).allSatisfy({bytes[$0]==0}) {
            let image=NSImage(systemSymbolName:"app.dashed",accessibilityDescription:"应用图标")!
            image.isTemplate=true; return image
        }
        guard let provider=CGDataProvider(data:Data(bytes) as CFData),
              let result=CGImage(width:size,height:size,bitsPerComponent:8,bitsPerPixel:32,bytesPerRow:size*4,
                                 space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGBitmapInfo(rawValue:CGImageAlphaInfo.premultipliedLast.rawValue),
                                 provider:provider,decode:nil,shouldInterpolate:true,intent:.defaultIntent) else { return source }
        let image=NSImage(cgImage:result,size:NSSize(width:24,height:24));image.isTemplate=true
        return image
    }
}
