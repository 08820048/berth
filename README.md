<!-- sparkle-sign-warning:
IMPORTANT: This file was signed by Sparkle. Any modifications to this file requires updating signatures in appcasts that reference this file! This will involve re-running generate_appcast or sign_update.
-->
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

启动后 Dock 里不会出现图标，只在菜单栏显示网络标记。点图标打开面板，默认快捷键 `⌥⌘P`。

在设置 → 通用 → 语言中选择「跟随系统」「简体中文」或「English」。切换立即生效并自动保存，无需重启；系统语言不受支持时回退到英文。进程名、命令、路径及系统返回的原始诊断信息保留原文。

## v0.2 范围

- 关注端口被未知进程占用时，菜单栏进入警告态
- Pin 常用项目；按项目一键停止全部开发端口
- 按端口 / 进程 / 路径忽略
- Docker / OrbStack / Colima 显示容器名；停止时优先 `docker stop`
- 运行时长、CPU、内存采样
- 全局快捷键打开面板（默认 ⌥⌘P，可改）
- 使用 Sparkle 自动检查、下载并安装更新

## 开发

```bash
make project   # 生成 Berth.xcodeproj
open Berth.xcodeproj
```

独立分发，默认不启用 App Sandbox，否则读不全其他进程的监听信息。

## 发布更新

Berth 使用 Sparkle 2，通过仓库根目录的 `appcast.xml` 获取更新。发布新版时，
递增 `MARKETING_VERSION` 和 `CURRENT_PROJECT_VERSION`，将签名、公证后的 App 压缩包
上传到 GitHub Release，再使用 Sparkle 的 `generate_appcast` 生成并提交新的 feed：

```bash
generate_appcast \
  --account app.berth.macos \
  --download-url-prefix https://github.com/08820048/berth/releases/download/<tag>/ \
  -o appcast.xml <archives-directory>
```

Sparkle 更新私钥保存在发布机器的登录钥匙串中，不应提交到仓库。

## 许可证

Berth 使用 [Apache License 2.0](LICENSE) 开源。第三方组件的授权信息见
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。

Copyright © 2026 xuyi
