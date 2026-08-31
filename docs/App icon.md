# Berth app icon

2026-08-31：重做应用图标，采用深石墨底、象牙白泊位环、蓝色状态节点的克制几何符号，已集成应用资源。

设计：抽象“泊位环 + 停靠柱 + 状态节点”，以极少的材质高光和柔和边缘保留质感，在 16px 下仍保持清晰。使用内置 imagegen 生成并按 macOS 图标槽位缩放。

原图：`docs/design/berth-icon-modern.png`（1024×1024，方形画布、四角不透明）。

应用资源：`Berth/Assets.xcassets/AppIcon.appiconset`，含 16、32、64、128、256、512、1024 像素 PNG，覆盖 macOS 的全部 1× / 2× 图标槽位。菜单栏状态符号保持不变。

## 生成提示词

Use case: logo-brand. Asset type: macOS application icon, square 1024×1024. Primary request: a restrained premium modern Berth app icon for a developer utility that manages local network ports and services. One centered abstract docking/berth symbol: a thick smooth circular ring opening into a short vertical pier, with one small circular status node inside. Geometric, vector-inspired, instantly legible at 16 px. Deep graphite full-bleed square background reaching all four corners, warm ivory symbol, tiny periwinkle-blue node accent, subtle enamel depth and edge highlight only. No pre-rounded tile, no transparency, no text, letters, boat, bowl, toilet, vessel, container, blob, mockup, watermark, or external shadow.
