import SwiftUI
import AppKit

struct MaterialView: NSViewRepresentable {
    func makeNSView(context:Context)->NSVisualEffectView {
        let view=NSVisualEffectView(); view.material = .popover; view.blendingMode = .behindWindow; view.state = .active
        return view
    }
    func updateNSView(_ nsView:NSVisualEffectView,context:Context) {}
}

final class ItemButton: NSButton {
    var onClick: ((Bool)->Void)?
    override func rightMouseUp(with event:NSEvent) { onClick?(true) }
    @objc func pressed() { onClick?(false) }
    override func resetCursorRects() { addCursorRect(bounds,cursor:.pointingHand) }
}
struct MenuItemButton: NSViewRepresentable {
    var item:BarItem
    var image:NSImage
    var enabled:Bool
    var click:(Bool)->Void
    func makeNSView(context:Context)->ItemButton {
        let button=ItemButton(); button.isBordered=false; button.imagePosition = .imageOnly
        button.imageScaling = .scaleProportionallyDown; button.target=button; button.action=#selector(ItemButton.pressed)
        button.setButtonType(.momentaryChange); return button
    }
    func updateNSView(_ button:ItemButton,context:Context) {
        button.image=image; button.toolTip=item.name; button.setAccessibilityLabel(item.name)
        button.isEnabled=enabled; button.onClick=click
    }
}
struct ShelfView: View {
    @ObservedObject var model:ShelfModel
    var body:some View {
        HStack(spacing:8) {
            if model.shelfItems.isEmpty {
                VStack(alignment:.leading,spacing:4) {
                    Text("收纳栏还是空的").font(.system(size:13,weight:.medium))
                    Text("按住 ⌘，将顶部图标拖到双箭头上收纳。")
                        .font(.system(size:11)).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true)
                }.padding(.leading,4)
            } else {
                ScrollView(.horizontal,showsIndicators:false) {
                    HStack(spacing:model.spacing) {
                        ForEach(model.shelfItems) { item in
                            MenuItemButton(item:item,image:model.cache.images[item.id] ?? item.fallbackImage,enabled:!model.busy) { right in model.activate(item,right:right) }
                                .frame(width:32,height:30)
                        }
                    }
                }
            }
            Divider().frame(height:24)
            Button { model.showSettings() } label: { Image(systemName:"slider.horizontal.3").frame(width:24,height:28) }
                .buttonStyle(.plain).help("管理图标与外观").accessibilityLabel("管理图标与外观")
        }.padding(12).background(MaterialView()).clipShape(RoundedRectangle(cornerRadius:14))
        .overlay(RoundedRectangle(cornerRadius:14).strokeBorder(.primary.opacity(0.12),lineWidth:0.5))
    }
}

struct SettingsView: View {
    @ObservedObject var model:ShelfModel
    @State private var tab=0
    var body:some View {
        VStack(spacing:0) {
            HStack(spacing:14) {
                Image(systemName:"menubar.rectangle").font(.system(size:28,weight:.light)).foregroundStyle(.secondary)
                VStack(alignment:.leading,spacing:3) {
                    Text("把空间，还给菜单栏。").font(.system(size:19,weight:.semibold))
                    Text("轻巧横条 · 点击展开，操作原生菜单").font(.system(size:12)).foregroundStyle(.secondary)
                }
                Spacer()
                Button(model.collapsed ? "展开全部" : "折叠图标") { model.setCollapsed(!model.collapsed) }.disabled(model.busy)
            }.padding(24)
            Picker("设置分类",selection:$tab) { Text("图标管理").tag(0); Text("外观与操作").tag(1); Text("权限与帮助").tag(2) }
                .pickerStyle(.segmented).padding(.horizontal,24).padding(.bottom,16)
            Divider()
            ScrollView {
                VStack(alignment:.leading,spacing:16) {
                    if !model.accessibility { permissionCard }
                    if let error=model.error {
                        HStack(alignment:.top) {
                            Image(systemName:"exclamationmark.triangle").foregroundStyle(.orange)
                            Text(error).font(.system(size:12)).textSelection(.enabled)
                            Spacer(); Button("关闭") { model.error=nil }.buttonStyle(.borderless)
                        }.padding(12).background(.orange.opacity(0.08),in:RoundedRectangle(cornerRadius:10))
                    }
                    if tab == 0 { itemSettings }
                    else if tab == 1 { appearanceSettings }
                    else { helpSettings }
                }.padding(24)
            }
            Divider()
            HStack {
                if model.busy { ProgressView().controlSize(.small) }
                Text(model.message).font(.system(size:11)).foregroundStyle(.secondary).lineLimit(2)
                Spacer(minLength:8)
                Button("打开收纳栏") { model.togglePanel() }.disabled(model.busy)
            }.padding(16)
        }.frame(minWidth:540,minHeight:480)
    }
    var permissionCard:some View {
        HStack(alignment:.top,spacing:12) {
            Image(systemName:"hand.raised").font(.title2).foregroundStyle(.secondary)
            VStack(alignment:.leading,spacing:6) {
                Text("先允许菜单栏操作").font(.headline)
                Text("辅助功能用于移动图标、打开原生菜单。请在系统设置中开启「折叠栏」，然后回来点刷新。")
                    .font(.system(size:12)).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true)
                Button("打开辅助功能设置") { model.requestAccessibility() }
            }
        }.padding(16).frame(maxWidth:.infinity,alignment:.leading).background(.quaternary,in:RoundedRectangle(cornerRadius:12))
    }
    var itemSettings:some View {
        VStack(alignment:.leading,spacing:12) {
            HStack {
                Text("菜单栏图标").font(.headline)
                Spacer()
                Button { Task { await model.refresh() } } label: { Label("刷新",systemImage:"arrow.clockwise") }.disabled(model.busy)
            }
            Text("按住 ⌘，将顶部图标拖到双箭头上，松开鼠标和 ⌘ 即可收纳。也可用下方菜单选择。系统控制图标保留常驻。")
                .font(.system(size:12)).foregroundStyle(.secondary)
            if model.items.isEmpty {
                ContentUnavailableView("尚未读取到菜单栏图标",systemImage:"menubar.rectangle",description:Text("确认顶部菜单栏已显示，然后点击刷新。"))
            }
            ForEach(model.items) { item in
                HStack(spacing:12) {
                    Image(nsImage:model.cache.images[item.id] ?? item.fallbackImage).resizable().scaledToFit().frame(width:24,height:24)
                    VStack(alignment:.leading,spacing:2) {
                        Text(item.appName).font(.system(size:13,weight:.medium))
                        if !item.title.isEmpty && item.title != item.appName { Text(item.title).font(.system(size:11)).foregroundStyle(.secondary).lineLimit(1) }
                    }
                    Spacer()
                    if model.foldedIDs.contains(item.id) {
                        Button { model.reorder(item,delta:-1) } label: { Image(systemName:"chevron.left") }.help("在横条中前移").accessibilityLabel("\(item.appName) 在横条中前移")
                        Button { model.reorder(item,delta:1) } label: { Image(systemName:"chevron.right") }.help("在横条中后移").accessibilityLabel("\(item.appName) 在横条中后移")
                    }
                    if item.frame.minX == -1 {
                        Text("系统已收起").font(.system(size:11)).foregroundStyle(.secondary)
                        Button("打开菜单") { model.activate(item,right:false) }.disabled(model.busy)
                    } else {
                        Picker("\(item.appName) 显示位置",selection:Binding(get:{model.foldedIDs.contains(item.id)},set:{model.changeGroup(item,hidden:$0)})) {
                            Text("菜单栏常驻").tag(false); Text("收纳栏内").tag(true)
                        }.labelsHidden().frame(width:132).disabled(item.protected || !model.accessibility || model.busy)
                    }
                }.padding(.vertical,6)
                Divider()
            }
        }
    }
    var appearanceSettings:some View {
        VStack(alignment:.leading,spacing:22) {
            Text("轻巧横条").font(.headline)
            Text("外观跟随系统深浅模式；图标多时可横向滚动。图标名称在悬停时显示。")
                .font(.system(size:12)).foregroundStyle(.secondary)
            HStack {
                Text("图标间距"); Slider(value:$model.spacing,in:4...16,step:2); Text("\(Int(model.spacing)) pt").monospacedDigit().frame(width:44)
            }
            Toggle("点击外部后收起横条",isOn:$model.closeOutside)
            Toggle("使用 ⌃⌥B 展开 / 收起",isOn:$model.shortcutEnabled)
            Toggle("下次启动时自动折叠",isOn:$model.autoFold)
            Text("关闭横条不会关闭正在操作的软件菜单。菜单结束后，临时显示的图标会尝试返回原位置。")
                .font(.system(size:12)).foregroundStyle(.secondary)
        }.toggleStyle(.switch)
    }
    var helpSettings:some View {
        VStack(alignment:.leading,spacing:18) {
            HStack { Label("辅助功能",systemImage:model.accessibility ? "checkmark.circle.fill" : "circle"); Spacer(); Text(model.accessibility ? "已开启" : "未开启").foregroundStyle(.secondary); Button("系统设置") { model.requestAccessibility() } }
            HStack { Label("菜单栏图标采集",systemImage:model.capture ? "checkmark.circle.fill" : "circle"); Spacer(); Text(model.capture ? "已开启" : "未开启").foregroundStyle(.secondary); Button("允许图标采集") { model.requestCapture() } }
            Text("图标采集需要 macOS 的屏幕录制权限。应用只采集菜单栏图标窗口用于横条显示，不保存录像、不上传；未授权时显示软件自身图标。")
                .font(.system(size:12)).foregroundStyle(.secondary)
            Divider()
            Text("使用方法").font(.headline)
            Text("1. 按住 ⌘，将图标拖到顶部双箭头上。\n2. 看到「松开以收纳」后，松开鼠标和 ⌘。\n3. 图标自动收纳；点击双箭头展开横条。\n4. 也可在图标管理中选择分组；左键打开原生菜单，右键执行原有右键操作。")
                .font(.system(size:12)).lineSpacing(6)
            Text("退出时会移除分隔线并恢复顶部显示。不要与 iBar、Ice、Bartender 等同时管理菜单栏。")
                .font(.system(size:12)).foregroundStyle(.secondary)
            Button("归位临时图标") { Task { await model.restoreTemporary() } }
            Divider()
            Text("折叠栏 0.2.1 · 本地测试版\n菜单栏事件路由参考 Ice，按 GPL-3.0 分发；包含完整源码。")
                .font(.system(size:11)).foregroundStyle(.secondary)
        }
    }
}
