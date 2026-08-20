# 总开发阶段文档：Codex 风格 DeepSeek Harness macOS 客户端

## 目标

交付一个可在 macOS 上直接构建和启动的原生桌面应用。应用使用 SwiftUI 提供接近 Codex 的三栏式桌面外壳，负责选择工作区、启动官方 `@deepseek-ai/dsh web` 服务、展示运行状态和日志，并在内置 WebKit 视图中使用官方 DeepSeek Harness 的完整功能。

## 非目标

- 不重新实现 DeepSeek Harness 的 agent、插件、会话、审批或模型配置协议。
- MVP 不捆绑 Node.js、npm 包缓存、代码签名、公证、自动更新或 DMG 安装器。
- 不依赖官方 Web UI 的内部 DOM 类名做主题注入，避免开发者预览阶段的上游变更直接破坏客户端。
- 不提交、读取或迁移用户的 DeepSeek API Key；密钥仍由官方 Harness 设置页面管理。

## 当前证据

- 本仓库开始时除空的 `logs/`、`scripts/` 目录外没有代码，也没有历史提交。
- 官方仓库说明 `npx @deepseek-ai/dsh web` 默认在 `http://127.0.0.1:3080` 启动 Web UI。
- 官方用户指南说明：`dsh` 进程的启动目录是默认文件系统位置，首次使用仍需在 Web UI 中确认工作区。
- 官方项目处于 developer preview，明确提示会有兼容性破坏性变更。
- 本机为 Apple Silicon，macOS 26.5.2，Swift 6.3.2；只有 Command Line Tools、没有完整 Xcode。
- 本机 Node.js 26.7.0 满足官方 `^22.19 || >=24` 的要求，`npx` 11.19.0 可用。

## 假设

- “和 Codex 类似风格”优先指原生 macOS 窗口、项目入口、侧边状态区、简洁工具栏和内嵌任务工作区，而不是逐像素复制 OpenAI 商标或界面。
- MVP 可以依赖用户本机安装 Node.js；通过实际构建和进程定位测试验证。
- 官方 Web UI 是功能事实来源，macOS 客户端只管理生命周期与桌面交互；通过启动 smoke test 验证。
- 默认端口保持官方的 `3080`，减少对尚未稳定的 CLI 参数依赖。

## 风险

| 风险 | 影响 | 缓解方案 | 负责人 |
| --- | --- | --- | --- |
| 官方 developer preview 出现破坏性变更 | 启动命令或页面加载失败 | 将命令和端口集中配置；不依赖内部 DOM | Codex |
| GUI 应用继承的 PATH 找不到 `npx` | 无法启动服务 | 扫描 PATH、Homebrew 常用目录，并提供明确诊断 | Codex |
| 3080 端口已被占用 | 可能连接到错误服务 | 启动前探测端口；只停止应用自己创建的进程；界面显示附着状态 | Codex |
| 首次运行需下载 npm 包 | 启动耗时或受网络影响 | 展示实时日志和启动状态；README 明确说明 | Codex |
| 未签名应用分发受 Gatekeeper 限制 | 其他 Mac 上不能无提示安装 | MVP 先交付本机构建脚本，签名/公证列入后续阶段 | 用户/Codex |

## 阶段地图

| 阶段 | 目的 | 子任务 | 进入条件 | 退出条件 | 状态 |
| --- | --- | --- | --- | --- | --- |
| S1 | 建立可验证的项目骨架 | ST-001、ST-002 | 规划完成 | Swift Package 与核心测试可构建 | 已完成 |
| S2 | 实现 Harness 生命周期 | ST-003、ST-004 | S1 完成 | 能定位 npx、启动服务、报告状态并安全停止 | MVP 已完成；NVM-only 发现结转 |
| S3 | 实现 Codex 风格桌面体验 | ST-005、ST-006 | S2 可用 | 可选工作区并在原生窗口加载 Harness | 已完成 |
| S4 | 打包与审核 | ST-007、ST-008 | S3 完成 | `.app` 可生成，测试和审核报告通过 | 已完成 |

## 验证策略

- `./scripts/run_checks.sh` 验证核心配置、端口和可执行文件定位逻辑；完整 Xcode 环境额外运行 `swift test`。
- `swift build` 验证 SwiftUI、WebKit 和进程管理代码可编译。
- `./scripts/build_app.sh` 验证可生成标准 `.app` 包结构。
- 启动应用并检查进程、窗口和本地 URL 加载；没有 API Key 时不执行真实模型调用。
- 最终用 `git diff --check` 和 Codex 审核报告核对范围、验收标准和剩余风险。
