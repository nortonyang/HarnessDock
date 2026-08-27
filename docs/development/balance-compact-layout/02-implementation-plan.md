# 具体开发方案：余额展示与紧凑布局

## 开发方案

| 步骤 | 工作内容 | 负责人 | 文件或区域 | 验证方式 | 状态 |
| --- | --- | --- | --- | --- | --- |
| 1 | 新增余额响应模型、格式和 API 客户端 | Codex | `Sources/HarnessDockCore/DeepSeekBalance.swift` | 核心检查 | 已完成 |
| 2 | 新增 Keychain 存储和 AppModel 状态 | Codex | `Sources/HarnessDockApp/BalanceKeychain.swift`、`AppModel.swift` | 构建/审核 | 已完成 |
| 3 | 新增余额 pill、详情 popover 和配置 sheet | Codex | `ContentView.swift` | 实机 UI | 已完成 |
| 4 | 用 64/236pt 自定义侧栏替换 NavigationSplitView | Codex | `ContentView.swift` | 实机 UI | 已完成 |
| 5 | 更新检查、README 和打包产物 | Codex | checks/docs/scripts | 命令验证 | 已完成 |

## 完成度

| 项目 | 完成度 | 证据 | 备注 |
| --- | ---: | --- | --- |
| 规划 | 100% | 本目录文档 | 文档门禁完成 |
| 余额能力 | 100% | 核心检查、release 构建 | 四态状态机和安全配置已落地 |
| 紧凑布局 | 100% | `ContentView.swift`、release 构建 | 默认 64pt，可展开至 236pt |
| 验证与截图 | 75% | checks/build/plist/codesign 均成功 | Mac 锁屏，待实机截图 |

## 要修复的问题

| 问题 | 严重级别 | 关联用户故事 | 修复方案 | 状态 |
| --- | --- | --- | --- | --- |
| 原生与 Web 双侧栏占宽过多 | P2 | US-105、US-106 | 默认紧凑栏，可按需展开 | 已修复 |
| 缺少余额可见性 | P2 | US-101 至 US-104 | 官方余额 API + Keychain | 已修复 |

## 具体案例

| 案例 | 输入或上下文 | 期望行为 | 验证方式 |
| --- | --- | --- | --- |
| 未配置 | 没有环境变量或 Keychain key | 显示“配置余额”，不发请求 | UI 检查 |
| CNY 成功 | 官方示例响应 | 显示 `¥110.00`，详情显示赠金/充值 | 核心检查/UI |
| 鉴权失败 | HTTP 401 | 显示“凭据无效”，可重新配置 | 代码审核/UI |
| 窄栏 | Harness 正在运行 | 原生栏 64pt，WebView 保持会话 | 截图/交互 |
| 展开栏 | 点击展开 | 显示项目、余额、服务卡片 | 截图/交互 |

## 兼容与回滚策略

- 余额模块与 Harness 生命周期解耦，请求失败不改变 `HarnessStatus`。
- 删除 Keychain 项即可回到无余额配置状态。
- 自定义侧栏只包裹现有 `WorkspaceView`，不修改 WebKit 内容和会话。
- 回滚本轮文件即可恢复原 `NavigationSplitView` 布局。

## Gemini 开发交接

见 `03-gemini-handoff.md`。用户明确要求 Codex 继续开发，因此本轮由 Codex 直接实现。

## Codex 5.5 审核清单

- API Key 是否只进入 Authorization header 和 Keychain。
- 错误和日志是否完全不包含 API Key。
- 余额 JSON 和金额格式是否有无凭据测试数据覆盖。
- 收起/展开是否不重建 WebView 或丢失会话。
- 是否避免计划外修改 Harness 进程管理代码。
