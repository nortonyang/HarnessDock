# Harness 本机 API Key 继承：紧凑开发方案

## 总开发阶段

### 目标

HarnessDock 启动官方 Harness 时保留启动环境中的 `DEEPSEEK_API_KEY`。官方模型设置页据此使用环境认证：已有环境凭据时不再要求重复输入，缺少凭据时继续显示 API Key 配置。

### 非目标

- 不把 API Key 内容注入 WebView、日志、README 或项目文件。
- 不把仅存于 HarnessDock 钥匙串的“余额凭据”复制给 Harness。
- 不修改官方 Harness 的设置存储、凭据服务或上游前端包。
- 不推断外部已运行 Harness 的进程环境；附着时由官方页面展示其真实凭据状态。

### 当前证据

- `Sources/HarnessDockApp/AppModel.swift` 从 `ProcessInfo.processInfo.environment` 构造子进程环境，却主动删除 `DEEPSEEK_API_KEY`。
- 已缓存的官方 `dsh-client-ui-settings-models` 文档说明：DeepSeek provider 可通过 `apiKeyEnv` 使用受信环境层认证；凭据已配置时显示已配置状态，缺失时显示输入卡片。
- API Key 值当前未写入 HarnessDock 日志；启动日志只记录命令、工作区和运行时路径。

### 风险与缓解

| 风险 | 影响 | 缓解方案 |
| --- | --- | --- |
| 把钥匙串余额 Key 意外传给 Harness | 扩大凭据使用范围 | 只恢复进程启动环境原本已有的变量，不读取或复制 Keychain 值 |
| 在页面中暴露 Key | 凭据泄露 | 不向 WebView 传值；完全依赖 Harness 服务端环境解析与脱敏 descriptor |
| 附着外部服务时错误隐藏输入框 | 用户无法配置 | 不注入自定义隐藏逻辑，让外部 Harness 按自身真实状态渲染 |
| 文档仍宣称环境 Key 不传给 Harness | 隐私说明失真 | 同步中英 README、发布审核和 Product Hunt 文案 |

### 阶段地图

| 阶段 | 子任务 | 退出条件 | 状态 |
| --- | --- | --- | --- |
| S1 证据与边界 | ST-901 确认官方环境认证；ST-902 区分环境与 Keychain | 行为和非目标明确 | 已完成 |
| S2 实现 | ST-903 保留子进程环境 Key；ST-904 增加静态回归检查 | Key 不再被删除且不被日志/Web 注入 | 已完成 |
| S3 文档与验证 | ST-905 更新公开说明；ST-906 构建与审核 | checks、release build、审核报告通过 | 已完成 |

## 原子任务与用户故事

### AT-901：继承本机 DeepSeek 环境凭据

用户故事：作为已在本机启动环境配置 `DEEPSEEK_API_KEY` 的用户，我希望 Harness 自动使用该凭据，以便不在模型页面重复配置。

验收标准：

- Given HarnessDock 启动环境存在非空 `DEEPSEEK_API_KEY`，When 应用启动自己管理的 Harness，Then 子进程继承该变量，官方页面按环境认证显示已配置状态。
- Given 启动环境不存在该变量，When 打开模型设置，Then 官方 Harness 继续显示 API Key 输入配置。
- Given 余额凭据只存在于 macOS Keychain，When 启动 Harness，Then Keychain 值不会被复制进子进程环境。
- Given 任意凭据来源，When 检查日志和 WebView bridge，Then 看不到 API Key 内容。

实现区域：`Sources/HarnessDockApp/AppModel.swift`。

### AT-902：更新隐私与发布说明

用户故事：作为用户或发布审核者，我希望文档准确说明不同凭据来源，以便理解 Harness 能访问什么。

验收标准：中英 README 和发布材料明确区分“启动环境 Key 会被托管 Harness 继承”与“Keychain-only 余额 Key 不会传递”。

## 具体开发方案

| 步骤 | 工作内容 | 文件或区域 | 验证方式 | 状态 |
| --- | --- | --- | --- | --- |
| 1 | 移除对子进程 `DEEPSEEK_API_KEY` 的删除 | `AppModel.swift` | 静态回归检查、core checks | 已完成 |
| 2 | 增加不包含实际 Key 的源码契约检查 | `scripts/`、`run_checks.sh` | Node 检查脚本 | 已完成 |
| 3 | 更新中英隐私、变更与发布说明 | README、CHANGELOG、release/Product Hunt docs | 文档残留检查 | 已完成 |
| 4 | 构建 HarnessDock.app 并完成审核 | build/checks、本文件 | build、plist、codesign | 已完成 |

### 具体案例

| 场景 | 输入 | 预期 |
| --- | --- | --- |
| 环境已配置 | App 启动环境包含 Key | 官方 Harness 使用环境认证，不要求重复填写 |
| 环境未配置 | App 启动环境无 Key | 模型设置保留 API Key 输入框 |
| 仅余额钥匙串 | Keychain 有值、环境无 Key | 原生余额可用；Harness 仍提示配置模型凭据 |
| 外部 Harness | 3080 已有官方服务 | 不改写其页面判断，由外部服务自身状态决定 |

## Gemini 开发交接

按本文件 AT-901/AT-902 实现最小变更。不得读取、记录或向 WebView 发送 API Key；不得把 Keychain 值注入 Harness；不得修改官方缓存包。需要返回变更文件、验证结果和偏离项。本次用户已要求 Codex 直接继续开发，因此由 Codex 按相同边界实施。

## Codex 5.5 审核报告

### 审核范围

- `AppModel.launchOrAttach` 的子进程环境构造。
- 新增静态回归检查及完整仓库 checks。
- 中英 README、CHANGELOG、发布审核和 Product Hunt 凭据说明。

### 问题发现

| 严重级别 | 问题 | 结果 |
| --- | --- | --- |
| P1 | App 主动删除本机 `DEEPSEEK_API_KEY`，导致官方 Harness 判定缺少凭据并重复显示输入卡片 | 已修复 |
| P2 | 公开文档宣称环境 Key 不传给 Harness，与新需求冲突 | 已修复 |

### 验收标准检查

| 用户故事 | 结果 | 证据 |
| --- | --- | --- |
| AT-901 环境凭据自动使用 | 通过 | 子进程完整继承启动环境；当前验证进程确认环境变量已配置；官方 Harness 文档确认环境认证会解析该变量 |
| AT-901 无环境凭据保留输入 | 通过 | 未增加默认值或 Web 隐藏逻辑；变量不存在时官方 missing credential 流程保持不变 |
| AT-901 Keychain 不外传 | 通过 | `launchOrAttach` 不调用 `balanceKeychain`/`balanceAPIKey`，回归检查锁定该边界 |
| AT-902 文档准确 | 通过 | README 中英版、CHANGELOG、release readiness 和 Product Hunt 文案已同步 |

### 验证结果

- `node scripts/check-harness-environment.mjs`：通过。
- `./scripts/run_checks.sh`：通过；插件、Chat Enter、本地化和核心检查全部通过。
- `./scripts/build_app.sh`：通过，生成新版 `dist/HarnessDock.app`。
- `plutil -lint` 与 `codesign --verify --deep --strict`：通过。
- 源码残留检查：`DEEPSEEK_API_KEY` 未被移除、未进入 WebView bridge 或日志拼接。

### 完成度更新

| 项目 | 更新前 | 更新后 | 证据 |
| --- | ---: | ---: | --- |
| Harness 环境凭据继承 | 0% | 100% | AppModel diff、回归检查、release build |
| 隐私边界文档 | 0% | 100% | 中英 README 与发布材料 |

### 剩余工作

- 用户需要完全退出旧 HarnessDock/Harness 服务后再打开新版，旧进程不会在运行中获得新增环境变量。
- 附着到外部已运行 Harness 时，其凭据状态仍由该外部进程自身决定，这是有意保留的安全边界。
