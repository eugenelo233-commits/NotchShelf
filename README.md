# 折叠栏 · NotchShelf

**简体中文** · [English](README.en.md)

[下载公测版](https://github.com/eugenelo233-commits/NotchShelf/releases/tag/v0.3.0) · [反馈问题](https://github.com/eugenelo233-commits/NotchShelf/issues) · [更新记录](CHANGELOG.md)

为 MacBook 刘海屏设计的轻巧菜单栏收纳工具。点击双下箭头展开横条，在横条中打开软件原生菜单。

A lightweight native macOS menu bar organizer with a compact horizontal shelf, double-chevron entry, and Command-drag to collect icons.

**当前版本：v0.3.0 公测版。** 面向愿意反馈问题的早期用户，尚未经过 Apple Developer ID 签名与公证。

## 为什么做这个工具

菜单栏图标越来越多，刘海右侧的空间却很有限。折叠栏把不常用的第三方图标收进一条小横栏，需要时点开，继续使用软件原本的菜单。

- **拖进去**：按住 ⌘，将图标拖到双下箭头入口。
- **点开用**：横条集中显示已收纳图标，支持打开原生菜单。
- **拖动排序**：在展开的横条内按住 ⌘ 拖动图标，松开自动保存顺序。
- **自己安排**：选择常驻或收纳，调整横条间距。
- **本机运行**：原生 Swift / AppKit / SwiftUI，无账号、无上传。

![折叠栏实际运行截图](preview.png)

*横条实机截图。未开启可选图标采集时，使用各软件自身的应用图标。*

## 下载与安装

从 [Releases](https://github.com/eugenelo233-commits/NotchShelf/releases) 下载 `NotchShelf-0.3.0-macOS-arm64.zip`，解压后将 `折叠栏.app` 放入“应用程序”并打开。

- 发布的二进制适用于 **Apple Silicon（M 系列）Mac**。
- 最低编译目标为 macOS 14，当前实机验证环境为 macOS 26.4；其他版本仍需测试。
- 应用常驻菜单栏，不显示 Dock 图标。再次打开应用可进入设置。
- 安装包采用本地 ad-hoc 签名，macOS 可能阻止首次打开。请先确认下载来源与 SHA-256，或自行编译。系统提示的解释见 [Apple 官方说明](https://support.apple.com/en-us/102445)。

## 使用

1. 在“系统设置 → 隐私与安全性 → 辅助功能”中开启“折叠栏”。
2. **按住 ⌘，把第三方菜单栏图标拖到双下箭头上。** 出现“松开以收纳”后，松开鼠标和 ⌘。
3. 图标移入收纳区，横条展示结果。后续点击双下箭头即可打开横条。
4. **横条内按住 ⌘ 拖动图标即可排序。** 放到另一图标左侧或右侧，松开自动保存；关闭重开保留顺序。拖到边缘可自动滚动，按 Escape 或拖出横条取消。设置中仍可调整分组、排序与间距。
5. 入口右键菜单提供展开全部、设置、临时图标归位和退出。退出会移除折叠分隔线。

收纳时菜单栏会短暂展开以完成图标移动，再恢复折叠。菜单栏拥挤导致入口不可见时，应用尝试将自己的入口移到刘海右侧。

## 权限与隐私

- **辅助功能（必需）**：识别图标、移动图标和打开原生菜单。拖拽监听只处理鼠标按下、移动和松开，不记录键盘输入内容。
- **屏幕录制（可选）**：仅用于采集原始菜单栏图案。未授权时使用应用自身图标；采集结果只保存在内存中。
- 无账号、无网络服务、无遥测或上传。偏好及非标准图标的窗口身份记录保存在本机。
- `--diagnostics` 开发模式会向标准错误输出应用名称、窗口编号和坐标。反馈问题前请检查日志与截图，移除个人信息。

实测确认：⌘ 拖动排序和关闭重开后保留顺序。边缘自动滚动、Escape 取消及进程重启后恢复仍待单独实测。

## 当前限制

- Wi-Fi、电池、控制中心等系统图标保留常驻。
- 第三方软件的菜单实现不同；自定义弹层、右键菜单和系统自行收起的图标可能不兼容。
- 全屏、多显示器、Intel Mac 和其他系统版本尚未完成实机验证。
- 全局快捷键 ⌃⌥B 已实现，但不同环境下的响应仍需反馈；菜单栏入口和设置窗口可作为替代入口。
- 使用了动态查找的私有 WindowServer 枚举接口，系统升级可能影响兼容性。
- 请勿与 Ice、Bartender、iBar 等同时管理同一菜单栏。

## 从源码构建

需要 macOS、Swift 5.9+ 和 Command Line Tools，无第三方包依赖。

```sh
bash test.sh
bash build.sh ./dist
```

`test.sh` 运行 24 项布局、拖拽边界与排序检查，并构建 Debug 版本。`build.sh` 构建当前主机架构的 Release 应用并进行本地签名。Intel 构建未验证。

核心路径：`Sources/NotchShelf/`。版本号：`Info.plist`。

## 反馈与贡献

欢迎通过 [Issues](https://github.com/eugenelo233-commits/NotchShelf/issues) 提交 macOS 版本、Mac 芯片、图标所属软件、复现步骤及期望行为。请勿提交密码、账户信息、完整桌面截图或未经检查的诊断日志。

如果折叠栏帮你找回了菜单栏空间，欢迎点一个 **Star**，或把下载页分享给需要它的朋友。兼容性报告与代码贡献同样欢迎。

## 许可证与致谢

按 **GPL-3.0** 分发，完整许可见 [LICENSE](LICENSE)。事件路由参考并改编自 [Ice](https://github.com/jordanbaird/Ice)，macOS 26 图标识别参考 [Thaw](https://github.com/thaw-app/Thaw)。来源和修改范围见 [THIRD_PARTY.md](THIRD_PARTY.md)。
