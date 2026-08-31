<p align="center">
  <img src="docs/design/berth-icon-modern.png" width="88" alt="Berth icon" />
</p>

<h1 align="center">Berth</h1>

<p align="center">
  <strong>Your dev ports, berthed in the menu bar.</strong><br>
  本地端口泊位看板 —— 看见谁占了口，判断能不能杀，停掉，确认口已经空出来。
</p>

<p align="center">
  <a href="https://berth.fyi">官网 berth.fyi</a> ·
  <a href="#-下载">下载</a> ·
  <a href="#-功能">功能</a> ·
  <a href="#-开发">开发</a> ·
  <a href="THIRD_PARTY_NOTICES.md">第三方声明</a>
</p>

<p align="center">
  <a href="https://github.com/08820048/berth/releases"><img src="https://img.shields.io/badge/version-0.1.0-blue" alt="version" /></a>
  <img src="https://img.shields.io/badge/platform-macOS%2014%2B-black?logo=apple" alt="macOS 14+" />
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-Apache--2.0-green" alt="Apache-2.0" /></a>
  <a href="https://berth.fyi"><img src="https://img.shields.io/badge/web-berth.fyi-orange" alt="berth.fyi" /></a>
</p>

<p align="center">
  <img src="https://berth.fyi/app-hero.png" width="560" alt="Berth 面板截图" />
</p>

## ⬇️ 下载

从官网 [berth.fyi](https://berth.fyi) 下载最新的 `Berth-*.dmg`（已签名并公证）。

已安装的用户无需手动更新：Berth 通过 [Sparkle](https://sparkle-project.org) 自动检查更新、后台下载，你只需在面板右下角点击一次「重启完成更新」。

## ✨ 功能

- **泊位网格** —— 把常用端口钉在面板上，绿点空闲、橙点被占，一眼看清
- **项目视角** —— 端口按项目归组，展示真实进程、PID 与路径，释放前心里有数
- **一键释放** —— 结束进程前有明确确认；强制结束只在明确要求时执行
- **终端式搜索** —— 跳转端口、打开 localhost、输入 `release 3000`，都在搜索框里
- **面板内更新** —— 检查更新、自动下载、青绿色「重启完成更新」一键升级
- **双语 & 双外观** —— 简体中文 / English，浅色 / 深色，跟随系统切换

## 🛠 开发

要求：macOS 14+，Xcode 16+（工程由 [XcodeGen](https://github.com/yonaskolb/XcodeGen) 生成）。

```bash
brew install xcodegen
make project   # 生成 Berth.xcodeproj
make test      # 运行单元测试（ad-hoc 签名，无需开发者证书）
make run       # 构建并启动
```

启动后不出现在 Dock，只在菜单栏显示。点图标打开面板，默认快捷键 `⌥⌘P`（可在设置中修改）。

设置 → 通用 → 语言：「跟随系统」「简体中文」「English」，切换立即生效。进程名、命令、路径及系统原始诊断信息保留原文。

独立分发，默认不启用 App Sandbox，否则读不全其他进程的监听信息。

## 🚀 发布

发布流程由 `scripts/release.sh` 一键完成：Developer ID 签名（含 Sparkle 嵌套组件重签）→ Apple 公证 → 装订票据 → 打包 zip（Sparkle 更新通道）+ DMG（官网下载）→ 生成 EdDSA 签名的 `appcast.xml` → 上传 Cloudflare R2。

```bash
# 1. 递增 project.yml 中的 MARKETING_VERSION（主版本.次版本.修订号）
#    和 CURRENT_PROJECT_VERSION（纯整数递增）
# 2. 发布
./scripts/release.sh
# 3. 提交更新后的 appcast.xml
```

前置条件：

- Developer ID Application 证书在本机钥匙串
- 公证凭证：`xcrun notarytool store-credentials berth-notary`
- Sparkle EdDSA 私钥在本机钥匙串（`generate_keys` 生成）
- [wrangler](https://developers.cloudflare.com/workers/wrangler/) 已登录（R2 上传）

Sparkle 私钥与公证凭证只存放在发布机器的钥匙串中，不应提交到仓库。

## 📄 许可证

[Apache License 2.0](LICENSE) · 第三方组件授权见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)

Copyright © 2026 xuyi
