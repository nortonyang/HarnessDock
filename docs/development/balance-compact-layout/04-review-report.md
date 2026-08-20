# Codex 5.5 审核报告：余额展示与紧凑布局

> 本方案随后被用户反馈的“去外壳化”方案取代；当前实现与最终审核见 `docs/development/full-bleed-harness/`。

## 审核范围

- `DeepSeekBalance.swift`：官方响应解码、摘要币种选择、接口与错误处理。
- `BalanceKeychain.swift`、`AppModel.swift`：凭据来源、安全存储和余额状态机。
- `ContentView.swift`：64/236pt 侧栏、余额 pill、popover 与设置 sheet。
- 核心检查、release 应用打包、plist 和代码签名。

## 问题发现

| 严重级别 | 问题 | 证据 | 必要动作 |
| --- | --- | --- | --- |
| - | 未发现 P0/P1/P2 缺陷 | API Key 未写日志、未回显，只进入 Authorization header 或 Keychain | 无 |
| P3 | 完整 `swift test` 在当前 Command Line Tools 环境缺少 `Testing` 模块 | `swift test` 返回 `no such module 'Testing'` | 保留完整 Xcode 下的测试；当前以无框架核心检查覆盖 |
| P3 | 自动 UI 截图暂被系统锁屏阻止 | Computer Use 返回 Mac locked | 用户解锁后补充实机截图 |

## 验收标准检查

| 用户故事 | 结果 | 证据 |
| --- | --- | --- |
| US-101 | 通过 | 官方 JSON 解码和 CNY 优先检查通过 |
| US-102 | 通过（代码审核） | Keychain CRUD；环境变量优先；未实填用户凭据 |
| US-103 | 通过 | 未配置/加载/成功/失败四态并与 Harness 状态解耦 |
| US-104 | 通过（构建） | SecureField、详情、刷新和移除入口已编译打包 |
| US-105 | 通过（构建） | 默认 64pt 图标栏、tooltip 和入口完整 |
| US-106 | 通过（结构审核） | 单一 WorkspaceView 外层宽度动画，不条件重建 WebView |
| US-107 | 通过 | checks/build/plist/codesign 成功 |
| US-108 | 进行中 | 等待 Mac 解锁后抓取真实窗口截图 |

## 验证结果

- `./scripts/run_checks.sh`：通过；受限沙箱不允许创建 loopback fixture 时明确跳过该环境项。
- `./scripts/build_app.sh`：通过，生成 `dist/DsHarness.app`。
- `plutil -lint`：通过。
- `codesign --verify --deep --strict`：通过。
- `swift test`：当前 CLT 缺少 `Testing` 模块，未作为失败门禁；等价余额解析由 CoreChecks 覆盖。

## 完成度更新

| 项目 | 更新前 | 更新后 | 证据 |
| --- | ---: | ---: | --- |
| 本轮优化 | 0% | 90% | 功能与构建完成，仅待实机截图 |

## 剩余工作

- 已转入全窗 Harness 方案，不再保留紧凑原生栏作为运行态界面。
- 由用户本人输入真实 API Key 后，再验收真实金额与 Keychain 保存/移除（不使用测试凭据代替）。
