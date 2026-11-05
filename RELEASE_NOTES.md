## v0.4.0 · 更方便地收纳，也更方便地放回

这一版让图标在收纳栏和菜单栏之间的操作更直接，并修复“恢复选项变灰”和“点击原生菜单没有反应”的相关问题。

### 新功能

- **拖回菜单栏**：在横条内按住 ⌘ 拖动图标到顶部提示区，松开鼠标和 ⌘ 后恢复到菜单栏。
- **右键直接恢复**：图标右键菜单新增“恢复到菜单栏”，不用再进入软件设置调整分组；同时提供“打开软件原有右键菜单”。
- **可选直接鼠标拖动**：默认仍需按住 ⌘；在“外观与操作”中关闭“拖拽时需要按住 ⌘”，即可用鼠标直接排序或拖回顶部。顶部原生图标仍遵循 macOS 的 ⌘ 拖动规则。
- **两种图标外观**：默认单色透明并随系统深浅色适配，可切换为彩色应用图标。未开启可选图标采集时，单色图形由应用图标生成。

### 修复

- 系统已关闭菜单栏显示的应用，不再被误列为已收纳图标；图标管理提供说明和系统设置入口。
- 缺少真实菜单栏窗口时，不再误报“刘海右侧空间不足”。
- 补齐原生图标移动的拖动事件，点击前检查可见位置，修复 33 pt 菜单栏窗口的高度误判。
- 改进临时图标归位，避免一次失败阻塞后续操作。

**注意：** 如果某个应用在“系统设置 → 菜单栏 → 允许在菜单栏显示”中被关闭，需要先开启，再用折叠栏收纳。不同软件对原生右键的响应可能是菜单、弹层或主窗口。

### 下载与升级

下载 **`NotchShelf-0.4.0-macOS-arm64.zip`**。先从双箭头右键菜单退出旧版，替换“应用程序”中的 `折叠栏.app`，再打开。沿用同一应用标识，已有偏好和排序保留；如 macOS 重新提示权限，请检查“隐私与安全性 → 辅助功能”中的“折叠栏”。安装包校验见 `SHA256SUMS.txt`；下方 Source code 提供 GPL-3.0 源码。

**验证与范围：** 用户确认本版使用正常；37 项自动检查、Debug / Release 构建和签名校验通过。实测覆盖右键恢复、原生弹层与关闭后重新收纳、直接鼠标排序。边缘滚动、Escape 取消及所有拖出组合未逐项完成验收。

继续作为 **Apple Silicon 公测版** 发布：最低编译目标 macOS 14，实测 macOS 26.4；采用 ad-hoc 签名，未进行 Apple Developer ID 签名与公证。全屏、多显示器完整交互、Intel Mac 及其他系统版本仍需更多验证。安装提示和完整使用说明见 [README](https://github.com/eugenelo233-commits/NotchShelf#readme)。

如果这一版让你的菜单栏更好用了，欢迎 **Star**，也欢迎提交兼容性反馈。

---

## v0.4.0 · Collect icons, bring them back, make the shelf yours

### New

- **Drag back to the menu bar:** Command-drag an icon from the shelf to the top restore zone, then release the mouse and Command.
- **Restore with a right click:** choose **恢复到菜单栏** (Restore to Menu Bar) directly from the shelf. A second option requests the app’s original right-click action.
- **Optional mouse-only dragging:** Command remains the default. Disable **拖拽时需要按住 ⌘** in **外观与操作** to reorder or restore icons without it. Native menu bar icons still require Command.
- **Two appearances:** adaptive transparent monochrome by default, or colorful app icons. Without optional icon capture, monochrome artwork is derived from app icons.

### Fixed

- Apps disabled under macOS Menu Bar settings are no longer mistaken for collected icons. Settings explains the state and links to the system settings.
- A missing status window is no longer reported as insufficient space beside the notch.
- Native icon movement now includes drag events and validates the visible position before clicking, including 33 pt status windows.
- Temporary restoration no longer blocks subsequent operations when a failed reveal left the icon in its original group.

**Before collecting a disabled icon:** enable its app in System Settings → Menu Bar → Allow in the Menu Bar. Native right-click behavior belongs to the original app and may open a menu, popover or main window.

### Download and update

Download **`NotchShelf-0.4.0-macOS-arm64.zip`**. Quit the old app, replace `折叠栏.app` in Applications, and reopen it. Existing preferences and shelf order use the same app identifier. Check Accessibility permission if macOS prompts again. Verify the archive with `SHA256SUMS.txt`; GPL-3.0 source archives are below.

The user confirmed this build works normally. **37 automated checks**, Debug / Release builds and signature verification pass. Hands-on testing covered restoration, a native popover and recollection after dismissal, and mouse-only reordering. Edge scrolling, Escape cancellation and every drag-out combination have not been individually verified.

This remains an **Apple Silicon public beta**: macOS 14 deployment target, tested on macOS 26.4, ad-hoc signed without Developer ID signing or notarization. Full-screen operation, complete multi-display behavior, Intel and other macOS versions need further testing. The app interface remains Simplified Chinese; documentation is available in both languages.

A **Star** helps others discover NotchShelf. Compatibility reports are welcome.
