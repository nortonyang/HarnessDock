# 总开发阶段文档：余额展示与紧凑布局

## 目标

在 HarnessDock macOS 客户端中持续展示 DeepSeek API 账户余额，并把当前重复的双侧栏布局改造成默认 64pt 的可折叠原生工具栏，给官方 Harness Web UI 留出更多可用宽度。

## 非目标

- 不读取或修改官方 Harness 的凭据、设置文件、数据库或 Web UI DOM。
- 不提供充值、退款、账单导出或消费预测。
- 不代理模型请求，不记录 API Key，不把余额数据发送给 DeepSeek 之外的服务。
- 不重写官方 Harness 自带的会话侧栏。

## 当前证据

- 用户截图显示原生侧栏约 211pt、Harness 侧栏约 234pt，合计占窗口可用宽度近一半。
- `ContentView.swift` 当前使用 `NavigationSplitView`，原生侧栏最小宽度 220pt。
- DeepSeek 官方文档提供 `GET https://api.deepseek.com/user/balance`，Bearer 鉴权，响应包含 `is_available` 以及 CNY/USD 的总余额、赠金和充值余额。
- 现有应用不读取或保存 Harness API Key，因此余额功能需要独立且明确的凭据来源。

## 假设

- “余额”指 DeepSeek 开放平台 API 账户余额，而不是 token 上下文余量或 Harness 会话配额。
- 用户接受首次使用余额功能时单独输入 DeepSeek API Key；应用保存到 macOS Keychain，也支持 `DEEPSEEK_API_KEY` 环境变量且不落盘。
- 紧凑工具栏默认收起，用户可展开查看完整项目和服务信息。

## 风险

| 风险 | 影响 | 缓解方案 | 负责人 |
| --- | --- | --- | --- |
| API Key 属于敏感凭据 | 泄露将导致账户被调用 | 只存 Keychain；日志、UserDefaults 和 UI 均不回显 | Codex |
| DeepSeek API 暂时不可用或返回鉴权失败 | 余额无法展示 | 显示最后状态与可重试入口，不影响 Harness 主功能 | Codex |
| 币种可能有多条记录 | 单一金额造成误导 | 顶部优先显示 CNY，否则第一项；详情弹窗展示全部币种 | Codex |
| 自定义布局替换 NavigationSplitView | 可能破坏窗口适配 | 保持 64/236pt 两个固定状态并实机检查最小窗口 | Codex |

## 阶段地图

| 阶段 | 目的 | 子任务 | 进入条件 | 退出条件 | 状态 |
| --- | --- | --- | --- | --- | --- |
| S1 | 建立余额数据与安全存储 | ST-101、ST-102 | 本文档批准 | 示例响应可解析，Keychain 可存取 | 未开始 |
| S2 | 接入余额状态与交互 | ST-103、ST-104 | S1 完成 | 未配置、加载、成功、失败均可观察 | 未开始 |
| S3 | 优化桌面布局 | ST-105、ST-106 | S2 可用 | 默认窄栏，展开/收起和主要入口可用 | 未开始 |
| S4 | 打包和审核 | ST-107、ST-108 | S3 完成 | 构建、检查和实机截图通过 | 未开始 |

## 验证策略

- 扩展 `HarnessDockCoreChecks`，验证官方余额 JSON 解码、币种选择和金额格式。
- 构建 release `.app`，校验 Info.plist 与 ad-hoc 签名。
- 不使用真实 API Key 做自动化测试；通过未配置状态和可控示例数据验证 UI。
- 实机打开已有 Harness 服务，检查窄栏、展开栏、余额入口和 Web UI 可用面积。
