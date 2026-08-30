# Berth

本地端口泊位看板。macOS 菜单栏应用：看见谁占了口，判断能不能杀，停掉，确认口已经空出来。

## 要求

- macOS 14+
- Xcode 16+（本仓库用 XcodeGen 生成工程）

```bash
brew install xcodegen
make test
make run
```

启动后 Dock 里不会出现图标，只在菜单栏显示锚点。点图标打开面板，默认快捷键 `⌥⌘P`。

## v0.2 范围

- 关注端口被未知进程占用时，菜单栏进入警告态
- Pin 常用项目；按项目一键停止全部开发端口
- 按端口 / 进程 / 路径忽略
- Docker / OrbStack / Colima 显示容器名；停止时优先 `docker stop`
- 运行时长、CPU、内存采样
- 全局快捷键打开面板（默认 ⌥⌘P，可改）

## 开发

```bash
make project   # 生成 Berth.xcodeproj
open Berth.xcodeproj
```

独立分发，默认不启用 App Sandbox，否则读不全其他进程的监听信息。
