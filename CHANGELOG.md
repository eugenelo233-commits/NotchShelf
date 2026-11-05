# 更新记录

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
