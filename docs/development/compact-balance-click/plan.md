# 折叠侧栏余额按钮点击修复：紧凑开发方案

## 目标

修复 Harness 侧栏折叠时点击“¥”余额入口没有可见响应的问题，使已配置余额时能稳定展开余额面板，未配置时仍进入“API 与余额”设置。

## 非目标

- 不改变余额查询、API Key、价格与 token 统计逻辑。
- 不调整侧栏图标布局或主题背景入口。
- 不修改上游 Harness 页面代码。

## 当前证据与根因

- 当前应用中可稳定复现：主题背景按钮能打开设置，折叠侧栏余额按钮点击后无可见变化。
- 注入脚本的余额按钮先执行 `setExpanded(true)`，同一次 document click 又排队执行 `updateSidebarMode()`。
- `updateSidebarMode()` 在每次检测到 compact 时都调用 `setExpanded(false)`，因此刚展开的面板会立即收回。

## 风险

| 风险 | 影响 | 缓解方案 |
| --- | --- | --- |
| 侧栏真正折叠时面板未关闭 | 面板悬浮位置不匹配 | 仅在 `false → true` 的 compact 状态转换时关闭 |
| 普通页面变化误关面板 | 点击仍像无响应 | compact 状态未变化时保留展开状态 |
| 影响未配置跳转设置 | API Key 入口失效 | 不改余额按钮原有 `notConfigured` 分支和消息桥 |

## 阶段、子任务与完成条件

| 阶段 | 子任务 | 退出条件 | 状态 |
| --- | --- | --- | --- |
| S1 定位 | ST-1001 界面复现；ST-1002 审核点击事件顺序 | 根因可由代码和实测共同解释 | 已完成 |
| S2 修复 | ST-1003 只在进入 compact 时关闭面板 | 普通 compact 点击不被重复关闭 | 已完成 |
| S3 验证 | ST-1004 静态契约；ST-1005 构建；ST-1006 界面回归 | 点击后 AX 状态变为 expanded 且面板可见 | 已完成 |

## 原子任务与用户故事

### AT-1001：保留折叠侧栏中的余额展开状态

用户故事：作为使用折叠侧栏的用户，我希望点击余额图标后看到余额面板，以便查看余额、当前价格时段和 token 用量。

验收标准：

- Given 侧栏已经处于 compact，When 点击余额按钮，Then 面板保持展开，不被随后触发的侧栏检测关闭。
- Given 侧栏从 expanded 切换到 compact，When 状态检测完成，Then 已打开的余额面板关闭。
- Given 余额尚未配置，When 点击余额按钮，Then 仍打开“API 与余额”设置。

## 具体开发方案

| 步骤 | 工作内容 | 文件或区域 | 验证方式 | 状态 |
| --- | --- | --- | --- | --- |
| 1 | 保存检测前 compact 状态，只在进入 compact 时关闭 | `HarnessWebView.balanceBridgeScript` | 静态检查与界面点击 | 已完成 |
| 2 | 增加回归契约 | `scripts/check-balance-interaction.mjs`、`run_checks.sh` | `./scripts/run_checks.sh` | 已完成 |
| 3 | 构建并在真实 App 中验证 | `dist/HarnessDock.app` | 点击后面板可见 | 已完成 |

## Gemini 开发交接

事实来源为本文件。只修改余额注入脚本的 compact 状态转换判断，并补充最小静态回归检查；不得重构余额面板或改动消息桥。当前环境没有 Gemini 执行通道，用户已要求继续修复，因此由 Codex 按同一范围直接实现并审核。

## Codex 5.5 审核报告

### 审核范围

- `HarnessWebView.balanceBridgeScript` 的按钮点击、document click 与侧栏同步事件顺序。
- 新增静态契约、全量检查、生产构建与真实 HarnessDock 点击行为。

### 问题发现

| 严重级别 | 问题 | 结果 |
| --- | --- | --- |
| P1 | 已处于 compact 时，每次 click 后的状态同步仍调用 `setExpanded(false)` | 已修复为只在 `false → true` 的 compact 转换时关闭 |

### 验收标准检查

| 用户故事 | 结果 | 证据 |
| --- | --- | --- |
| AT-1001 compact 点击展开余额 | 通过 | 真实 App 中按钮由 AX `collapsed` 变为 `expanded`，面板内容可读 |
| AT-1001 进入 compact 时关闭 | 通过 | 状态转换判断与静态契约覆盖 |
| AT-1001 未配置时进入设置 | 通过 | 原 `notConfigured → send('settings')` 分支未改动 |

### 验证结果

- `node scripts/check-balance-interaction.mjs`：通过。
- `./scripts/run_checks.sh`：通过。
- `./scripts/build_app.sh`：通过并完成 ad-hoc 签名。
- Computer Use 真实回归：修复前点击无 AX 变化；修复后余额按钮为 `expanded`，余额、价格时段与 token 用量面板可见。

### 完成度更新

| 项目 | 更新前 | 更新后 | 证据 |
| --- | ---: | ---: | --- |
| 折叠侧栏余额点击 | 0% | 100% | 静态契约、构建、真实界面回归 |

### 剩余工作

- 无计划内剩余工作。
