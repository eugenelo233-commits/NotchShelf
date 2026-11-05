## v0.3.0：在收纳栏里按住 ⌘ 拖动排序

展开横条，按住 **Command（⌘）** 拖动图标，放到另一图标左侧或右侧即可调整顺序，松开自动保存。普通点击继续打开软件原生菜单。

- 拖动时显示插入位置；靠近横条边缘自动滚动。
- 按 Escape 或拖出横条取消，不改变原顺序。
- 用户已确认：可以移动，关闭横条并重新打开后顺序保留。
- 24 项逻辑检查、Debug / Release 构建与签名校验通过。边缘滚动、取消手势及进程重启后的顺序恢复仍待单独实测。

### 下载与升级

下载 `NotchShelf-0.3.0-macOS-arm64.zip`，解压。旧用户先从双箭头右键菜单退出折叠栏，再替换“应用程序”里的应用并打开。设置保存在原应用偏好中；若系统再次提示权限，请在“隐私与安全性 → 辅助功能”中检查“折叠栏”。`SHA256SUMS.txt` 提供安装包校验值。源码见下方 Source code，按 GPL-3.0 提供。

这是 **Apple Silicon 公测版**：最低编译目标 macOS 14，实机环境 macOS 26.4；采用 ad-hoc 签名，未进行 Apple Developer ID 签名与公证。首次打开的系统提示请参阅 README。其他系统、全屏和多显示器仍待测试。

---

## v0.3.0: Command-drag to reorder the shelf

Open the shelf, hold **Command**, and drag an icon to the left or right side of another icon. The order is saved on drop. A regular click still opens the app’s original menu.

- Insertion indicators, edge scrolling, and cancellation with Escape or a drop outside the shelf.
- User testing confirmed reordering and order retention after closing and reopening the shelf.
- 24 logic checks, Debug / Release builds and signature verification passed. Edge scrolling, cancellation gestures and retention across a process restart still need separate hands-on testing.

### Download and update

Download `NotchShelf-0.3.0-macOS-arm64.zip`. Quit the old app from the entry’s right-click menu, replace the app in Applications, and reopen it. Preferences use the same app domain. Check Accessibility permission if macOS prompts again. Verify the archive with `SHA256SUMS.txt`; GPL-3.0 source archives are below.

**Apple Silicon public beta**, macOS 14 deployment target, tested on macOS 26.4. Ad-hoc signed, without Apple Developer ID signing or notarization. See README for installation notes and compatibility limits. The app interface remains Simplified Chinese.
