# 产品官网（berth-website）

Berth 的产品官网是**独立项目**，不在本仓库内，避免和 App 源码混在一起。

## 位置

```
~/Documents/berth-website        # 独立 git 仓库，与本仓库（Berth）平级
```

## 技术栈

- **Next.js**（App Router，`output: "export"` 纯静态导出）
- **Tailwind CSS v4**
- **[coss ui](https://coss.com/ui)**（基于 Base UI 的组件库，shadcn 风格复制式安装，`init @coss/style` 装了全部组件，位于 `components/ui/`）
- 组件 API 注意：coss ui 的 Button 不支持 `asChild`，用 Base UI 的 `render={<a href=… />}` prop

## 常用命令

```bash
cd ~/Documents/berth-website
npm run dev        # 本地开发 http://localhost:3000
npm run build      # 静态导出到 out/（部署产物）
```

注意：构建时需要代理访问 Google Fonts（`npm run build` 直接跑即可）；
而 `npx shadcn` 命令反而要绕过代理：

```bash
env -u HTTPS_PROXY -u HTTP_PROXY -u https_proxy -u http_proxy npx shadcn@latest add <component>
```

## 设计约定

- 高信任、高质感、克制：中性色系统（coss neutral），唯一强调色是青绿色（teal），
  只用于"重启完成更新"按钮——与 App 内更新按钮一致
- 文案只写事实：真实版本号（0.0001）、公证状态、Apache-2.0、下载文件大小
- 支持 light/dark（跟随系统 + 手动切换，localStorage key `berth-theme`）
- 面板配图是手写 HTML/CSS 复刻的 App 面板，不用截图，任意 DPI 都清晰

## 数据与发布联动

- 下载链接指向 Cloudflare R2：
  `https://pub-aa21c73b26d444688ef7db7de0c5f129.r2.dev/Berth-0.0001.dmg`
- **发新版时需要同步更新官网三处**：
  1. `app/page.tsx` 顶部的 `DOWNLOAD_URL`
  2. Hero 区的 Badge 版本号（`v0.0001`）
  3. Changelog 区块和底部 CTA 的版本号/文件名

## 部署（未配置，可选项）

`out/` 是纯静态产物，可直接部署：

```bash
cd ~/Documents/berth-website && npm run build
npx wrangler pages deploy out --project-name berth-website
# 或上传到 R2 桶（和安装包同一个桶也可以）
```

建议后续绑定自定义域名（如 berth.app）后，把 `app/layout.tsx` 里的
`metadataBase` 一并更新。
