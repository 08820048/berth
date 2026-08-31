# Berth menu bar icon

Berth 的菜单栏图标从产品图标中的白瓷泊位提炼而来：一段上扬的开放港湾包围一个停靠点。菜单栏版本使用 16pt 单色矢量剪影，不直接缩小带材质的应用图标，因此可以跟随 macOS 菜单栏的浅色、深色和选中状态。

状态由中心标记表达：

- 实心圆点：正常
- 感叹号：关注端口冲突
- 空心圆点：正在停止进程

实现位于 `Berth/Views/BerthMenuBarIcon.swift`，预览位于 `docs/design/berth-menubar-icon.png`。运行时由 AppKit 绘制成 18×18 的原生模板 `NSImage`，再交给 `MenuBarExtra`，避免自定义 SwiftUI `Shape` 在系统状态栏标签中不显示。
