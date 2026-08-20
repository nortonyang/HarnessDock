# 具体开发方案：Codex 风格 DeepSeek Harness macOS 客户端

## 开发方案

| 步骤 | 工作内容 | 负责人 | 文件或区域 | 验证方式 | 状态 |
| --- | --- | --- | --- | --- | --- |
| 1 | 建立 Swift Package、核心配置和测试 | Codex | `Package.swift`、`Sources/DsHarnessCore/`、`Tests/` | `./scripts/run_checks.sh`；完整 Xcode 环境运行 `swift test` | 已完成 |
| 2 | 实现 npx 定位和 Harness 子进程控制 | Codex | `Sources/DsHarnessApp/AppModel.swift` | `swift build`、smoke test | 已完成 |
| 3 | 实现 SwiftUI 侧边栏、状态页和设置 | Codex | `Sources/DsHarnessApp/ContentView.swift` | UI 检查 | 已完成 |
| 4 | 实现 WKWebView 容器与导航动作 | Codex | `Sources/DsHarnessApp/HarnessWebView.swift` | UI 检查 | 已完成 |
| 5 | 生成 `.app` 和使用文档 | Codex | `scripts/build_app.sh`、`README.md` | 打包与 plist 校验 | 已完成 |
| 6 | 对照验收标准审核 | Codex | `04-review-report.md` | 测试、diff、审核 | 已完成 |

## 完成度

| 项目 | 完成度 | 证据 | 备注 |
| --- | ---: | --- | --- |
| 规划与架构 | 100% | `00-master-plan.md`、`01-stages-and-stories.md` | 已完成文档门禁 |
| Swift 核心与服务 | 90% | 核心检查通过；服务附着 smoke test 通过 | NVM-only Finder 自动发现结转 |
| macOS UI | 100% | `ui-preview.jpeg`、`ui-running.jpeg` | 欢迎页和真实 Harness 均已验证 |
| 打包与交付 | 100% | `dist/DsHarness.app`、codesign/plutil 校验 | 本机 ad-hoc 包 |

## 要修复的问题

| 问题 | 严重级别 | 关联用户故事 | 修复方案 | 状态 |
| --- | --- | --- | --- | --- |
| 空仓库没有可运行产品 | P1 | US-001 至 US-008 | 按本方案实现 MVP | 已修复 |
| 官方 CLI 尚在 developer preview | P2 | US-002、US-004 | 集中配置并保持最小启动参数 | 已缓解 |
| 缺少完整 Xcode | P2 | US-007 | 用 SwiftPM 和脚本生成 `.app` | 已缓解 |
| Finder 环境无法自动发现仅由 NVM 安装的 npx | P2 | US-003、US-004 | 当前可先运行官方服务后附着；下一版扫描 NVM 版本目录 | 结转 |

## 具体案例

| 案例 | 输入或上下文 | 期望行为 | 验证方式 |
| --- | --- | --- | --- |
| 首次启动 | 没有保存的项目 | 显示项目选择引导，不启动无目录任务 | UI 检查 |
| 正常启动 | 有效目录、Node 26 和可用网络/缓存 | 服务进入运行中，主视图加载 127.0.0.1:3080 | smoke test |
| Node 缺失 | PATH 中没有 npx | 显示安装 Node.js 的明确错误 | 单元测试/UI 检查 |
| 端口已有服务 | 3080 返回 HTTP | 附着现有服务，退出时不终止它 | smoke test |
| 切换项目 | 应用拥有当前 dsh 子进程 | 停止旧进程，以新 cwd 重启 | UI/进程检查 |
| 页面临时失败 | 服务启动中或页面错误 | 保持状态页和重载入口，不崩溃 | UI 检查 |

## 兼容与回滚策略

- 客户端不修改用户仓库和官方 Harness 数据；删除本应用即可回滚。
- 最近工作区只存放在 UserDefaults，不存储 API Key。
- 官方命令和 URL 位于 `HarnessConfiguration`，上游变动时集中修改。
- 若嵌入页兼容性异常，用户可用“在浏览器打开”继续使用官方 Web UI。

## Gemini 开发交接

见 `03-gemini-handoff.md`。当前用户直接要求 Codex 开发，因此由 Codex 执行；交接稿保留用于后续并行或移交。

## Codex 5.5 审核清单

- 实现是否匹配 US-001 至 US-008。
- 是否只依赖官方公开启动方式，没有复制不稳定的内部实现。
- 是否只停止应用拥有的进程。
- 是否未记录或处理 API Key。
- 是否覆盖 npx 找到/找不到和默认 URL 配置测试。
- `.app` 是否能生成，Info.plist 是否有效。
- 是否存在计划外功能或无关文件。
