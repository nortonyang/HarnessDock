# Gemini 代码开发交接：Codex 风格 DeepSeek Harness macOS 客户端

你将根据已经批准的敏捷规划文档实现代码。

## 事实来源

- `docs/development/codex-style-macos/00-master-plan.md`
- `docs/development/codex-style-macos/01-stages-and-stories.md`
- `docs/development/codex-style-macos/02-implementation-plan.md`

## 实现范围

- 实现 AT-001 至 AT-008、US-001 至 US-008。
- 用 SwiftUI + WKWebView 创建 macOS 原生客户端。
- 用应用子进程启动 `npx --yes @deepseek-ai/dsh web`。
- 提供工作区选择、状态、日志、重载、浏览器打开和本地 `.app` 构建。

## 约束

- 不修改无关文件，不扩大范围。
- 不重新实现 DeepSeek agent 或官方 Web UI。
- 不保存、输出或代理 API Key。
- 不依赖官方 Web UI 的内部 DOM 或 CSS 类名。
- 只停止由应用自己创建的子进程。
- 不增加第三方 Swift 包依赖。

## 验收标准

- `swift build`、`./scripts/run_checks.sh` 成功；完整 Xcode 环境额外运行 `swift test`。
- `./scripts/build_app.sh` 生成 `dist/DsHarness.app`。
- 有效工作区可启动服务并加载 `http://127.0.0.1:3080`。
- 找不到 npx、服务退出或页面错误时均给出可读状态。
- README 明确依赖和 MVP 限制。

## 预期改动区域

- `Package.swift`
- `Sources/DsHarnessCore/`
- `Sources/DsHarnessApp/`
- `Tests/DsHarnessCoreTests/`
- `scripts/build_app.sh`
- `README.md`
- `docs/development/codex-style-macos/`

## 需要运行的验证

- `./scripts/run_checks.sh`
- `swift build`
- `./scripts/build_app.sh`
- `plutil -lint dist/DsHarness.app/Contents/Info.plist`
- `git diff --check`

## 返回内容

- 变更文件列表。
- 实现摘要。
- 验证命令和结果。
- 阻塞点或偏离计划的地方。
