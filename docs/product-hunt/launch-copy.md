# HarnessDock — Product Hunt launch draft

Last verified against Product Hunt's official launch guidance: 2026-08-27.

This is a preparation document, not proof that a Product Hunt draft or launch has been created. Items marked **Pending** must be resolved before entering the submission form.

Official references:

- [Preparing for launch](https://www.producthunt.com/launch/preparing-for-launch)
- [How to post a product](https://help.producthunt.com/en/articles/479557-how-to-post-a-product)
- [How to schedule a post](https://help.producthunt.com/en/articles/2724119-how-to-schedule-a-post)

## Verified product facts

- Product: native SwiftUI/WebKit macOS app for the official DeepSeek Harness web interface.
- Version: developer preview `0.1.0`.
- Minimum system: macOS 14 Sonoma.
- Current candidate architecture: arm64 only.
- Local candidate archive: `HarnessDock-0.1.0-macOS-arm64.zip`, 8,450,406 bytes.
- Local candidate SHA-256: `527b29f5f50a7e70b41fb8caf425f8518c67dc24d614d86276424dfe8d5b20b5`.
- Candidate signature: valid ad-hoc signature only; no Developer ID team and no Apple notarization.
- App price: **Pending license decision**. Intended launch choice is Free; DeepSeek API usage is billed separately by DeepSeek.
- Privacy: managed Harness inherits `DEEPSEEK_API_KEY` from the app launch environment or resolves only that exported variable through the user's login shell for Finder launches; a Keychain-only balance credential remains native-only. Values are not injected into webpages or logs.
- Upgrade compatibility: the public product is HarnessDock, while the legacy `app.dsharness.desktop` bundle identifier and related local service names are retained so existing sessions and settings survive the rename.
- Product URL: **Pending usable GitHub Release or landing/download page**.
- Download: **Pending Developer ID signing, Apple notarization, and clean-Mac smoke test**. The checksum above is for a local, non-public candidate and must be regenerated for the exact uploaded artifact.

## English submission copy

### Name

HarnessDock

### Tagline — 39/60 characters

DeepSeek Harness, made native for macOS

### Description — 233/260 characters

HarnessDock is a native SwiftUI workspace for DeepSeek Harness. Open local projects, view API balance and RMB peak/off-peak pricing, switch to DeepSeek Chat, personalize backgrounds, and add task-aware pets. Credentials remain local.

### Launch tags — confirm exact labels in the live form

1. Developer Tools
2. Artificial Intelligence
3. Mac

### Pricing

Free — **pending license decision**. Users bring their own DeepSeek API access; any API charges are paid directly to DeepSeek.

### Maker first comment

Hi Product Hunt! I built HarnessDock because I wanted the official DeepSeek Harness workflow to feel like a real Mac app instead of another browser tab.

The native SwiftUI shell opens local projects, starts the pinned Harness runtime, keeps Harness and DeepSeek Chat in one window, and adds the macOS details I missed: Keychain-backed balance checks, Beijing-time peak/off-peak RMB pricing, custom backgrounds, bilingual controls, and task-aware animated pets.

Privacy was a deliberate boundary. Managed Harness receives `DEEPSEEK_API_KEY` from the app launch environment or, for Finder launches, from a single-variable login-shell lookup. HarnessDock never imports the full shell environment, and a Keychain-only balance credential stays native-only. Credential values are never injected into webpages or logs. The pet observes task status only—not prompts, replies, command arguments, or tool output.

This is an independent, unofficial developer preview for macOS 14+. I would especially value feedback on the native workflow, setup experience, and which desktop features would make Harness more useful day to day.

## 中文审核对照

### 产品名

HarnessDock

### 标语

让 DeepSeek Harness 原生运行在 macOS 上

### 产品描述

HarnessDock 是面向 DeepSeek Harness 的原生 SwiftUI 工作空间。它能打开本地项目、展示 API 余额和人民币高峰/谷时价格、切换 DeepSeek Chat、自定义主题背景，并加入能感知任务状态的动态宠物。凭据始终留在本机。

### 发布标签（以表单现场选项为准）

1. 开发者工具（Developer Tools）
2. 人工智能（Artificial Intelligence）
3. Mac

### 价格

免费——仍需先确定项目许可证。用户自行提供 DeepSeek API，相关 API 费用直接由 DeepSeek 收取。

### Maker 首条评论

大家好！我开发 HarnessDock，是因为我希望官方 DeepSeek Harness 的工作流能真正像一款 Mac 应用，而不是浏览器里的另一个标签页。

原生 SwiftUI 外壳可以打开本地项目、启动锁定版本的 Harness 运行时，把 Harness 与 DeepSeek Chat 放进同一个窗口，并补充更符合 macOS 使用习惯的能力：钥匙串余额查询、北京时间高峰/谷时人民币价格、自定义背景、中英文界面和能感知任务状态的动态宠物。

隐私边界是我重点考虑的部分。HarnessDock 管理的 Harness 会接收应用启动环境中的 `DEEPSEEK_API_KEY`；Finder 启动缺失时，只通过登录 Shell 查询这一项变量，不导入完整环境。仅存于钥匙串的余额凭据仍只供原生查询，凭据内容不会注入网页或日志。宠物只观察任务状态，不读取提示词、回复正文、命令参数或工具输出。

这是面向 macOS 14+ 的独立非官方开发者预览版。我特别希望听到大家对原生工作流、首次配置体验，以及哪些桌面功能能让 Harness 更适合日常使用的反馈。

## Media checklist

- [x] Square thumbnail source: `Resources/AppIcon.icns`.
- [x] Exported and verified `docs/product-hunt/thumbnail.png` at 240×240.
- [ ] Capture a clean overview screenshot with synthetic workspace and balance data.
- [ ] Capture API balance and peak/off-peak pricing.
- [ ] Capture bilingual Settings and theme background.
- [ ] Capture DeepWhale/Marina reacting to a running task.
- [ ] Optionally record a short real-product video; do not simulate unavailable features.

## Submission blockers

- Repository license has not been selected.
- No Developer ID-signed and Apple-notarized downloadable package exists.
- No exact uploaded artifact has passed a clean-Mac installation test.
- No public download checksum is available.
- Final Product URL, makers, live-form tags, and Product Hunt account eligibility are not confirmed.
- Final gallery screenshots still need sanitized demo content.
