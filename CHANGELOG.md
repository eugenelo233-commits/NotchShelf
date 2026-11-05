# 更新记录

## v0.4.0 · 拖回菜单栏与外观切换 / Restore icons and choose an appearance

2026-11-05

- 横条图标可按住 ⌘ 拖回顶部提示区恢复；右键菜单可直接恢复或请求原有右键操作。
- 新增直接鼠标拖动选项，默认保留 ⌘；单色透明为默认外观，可切换彩色应用图标。
- 不再把系统关闭显示的占位图标误列入收纳栏；新增系统菜单栏设置入口，区分窗口不可用与空间不足。
- 修复原生拖动事件、可见位置和 33 pt 状态窗口校验，改进临时图标归位。
- 37 项自动检查、Debug / Release 构建和签名校验通过；用户确认本版使用正常。完整兼容范围见 README。

Command-drag icons back to the menu bar or restore them from the shelf context menu. Adds optional mouse-only dragging and adaptive monochrome / colorful appearances. Fixes disabled-icon classification, misleading space errors, native drag events, 33 pt status-window validation and temporary restoration. All 37 automated checks pass; the user confirmed normal operation. See README for compatibility limits.

## v0.3.0 · ⌘ 拖动排序 / Command-drag reordering

- 展开横条后，按住 ⌘ 拖动图标到另一图标前后；提供插入位置提示，松开自动保存。
- 拖到横条边缘自动滚动；取消拖动不改动排序。拖动期间暂停列表刷新，避免界面重建打断手势。
- 普通点击继续打开软件原生菜单；设置中的左右排序按钮保留。
- 24 项逻辑检查、Debug / Release 构建、签名校验通过。用户确认拖动排序及关闭重开后保留顺序。边缘滚动与取消手势仍待单独实测。

Hold Command to reorder icons within the shelf. Drop before or after another icon to save the order. Includes insertion feedback, edge scrolling and cancellation handling. User testing confirmed dragging and order retention after reopening; 24 logic checks pass. Edge scrolling and cancellation still need separate hands-on testing.

## v0.2.1 · 首个公开测试版本

- 原生轻巧横条，支持菜单栏图标分组、横条排序与间距调整。
- 双下箭头入口；⌘ 拖拽第三方图标到入口进行收纳。
- 刘海右侧入口位置检测与自动归位。
- 增加 TourBox 等非标准菜单栏图标的识别与隐藏后身份记录。
- 修复已折叠时再次收纳失败：先临时展开，移动后恢复折叠。
- 收紧窗口身份命中条件，减少重复或错误识别。

已完成 Apple Silicon / macOS 26.4 本机试用；16 项布局和拖拽边界检查通过。其他系统、芯片及软件组合仍需测试。
