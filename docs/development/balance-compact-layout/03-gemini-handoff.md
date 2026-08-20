# Gemini 代码开发交接：余额展示与紧凑布局

事实来源：

- `docs/development/balance-compact-layout/00-master-plan.md`
- `docs/development/balance-compact-layout/01-stages-and-stories.md`
- `docs/development/balance-compact-layout/02-implementation-plan.md`
- DeepSeek 官方接口：`https://api-docs.deepseek.com/zh-cn/api/get-user-balance`

实现范围：AT-101 至 AT-108。

约束：

- 不读取 Harness 内部凭据和数据。
- API Key 只存 macOS Keychain，不写日志/UserDefaults/项目文件。
- 只请求 `GET https://api.deepseek.com/user/balance`。
- 不修改 Harness agent、会话或 Web UI。
- 不重构无关的进程生命周期代码。

验收标准：

- 官方示例余额可正确解析和展示。
- 无凭据、加载、成功、失败状态可区分。
- 默认 64pt 紧凑栏，可展开到 236pt。
- `./scripts/run_checks.sh` 和 `./scripts/build_app.sh` 成功。

预期文件：

- `Sources/DsHarnessCore/DeepSeekBalance.swift`
- `Sources/DsHarnessApp/BalanceKeychain.swift`
- `Sources/DsHarnessApp/AppModel.swift`
- `Sources/DsHarnessApp/ContentView.swift`
- `Sources/DsHarnessCoreChecks/main.swift`
- `README.md`

返回内容：变更文件、实现摘要、验证结果、阻塞点和偏离项。
