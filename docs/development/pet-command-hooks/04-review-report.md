# Codex 审核报告：双页面宠物命令钩子

## 审核范围

- Harness Web 插件的 sessions 订阅与动画边沿。
- Chat WebKit 状态脚本、消息桥和 AppModel 状态复位。
- Core 动画映射、自动检查、本地构建与部署。

## 问题发现

| 严重级别 | 问题 | 必要动作 | 状态 |
| --- | --- | --- | --- |
| P2 | Harness 宠物只响应鼠标，不响应当前会话和后台命令 | 接入官方 sessions 快照 | 已修复 |
| P2 | Chat 宠物只感知网页导航加载，不感知回答生成 | 增加只传枚举的 WebKit Hook | 已修复 |
| P1 | Chat 桥若传 DOM 文本可能泄露内容 | 固定四值枚举并加入检查 | 已修复 |

## 验收标准检查

| 用户故事 | 结果 | 证据 |
| --- | --- | --- |
| US-701 | 通过 | Core 检查覆盖运行/成功/失败映射、终态完整周期和非法枚举拒绝 |
| US-702 | 通过 | 插件检查覆盖官方 sessions 注入、当前会话/后台任务、错误边沿与动画优先级 |
| US-703 | 自动审核通过 | Node VM 覆盖中英文停止控件、正常/失败结束和旧错误基线；重建版 Chat 页面正常加载 |
| US-704 | 自动审核通过 | 根检查、生产构建、Info.plist 与应用签名验证通过；真实 Chat 动态观感待用户手工验证 |

## 验证结果

- `./scripts/run_checks.sh`：通过，包括 Harness 插件、Chat Enter、Chat 宠物命令桥、余额、环境、迁移、本地化和 Core 检查。
- `node scripts/check-chat-pet-command.mjs`：只允许四值状态，且脚本不包含 `textContent`、`innerText` 或 `innerHTML`。
- `./scripts/build_app.sh`：生产构建通过，生成 `dist/HarnessDock.app`。
- 本机界面：重建版 Harness 可读取既有会话，Chat 可复用已登录会话并显示首页；未向 DeepSeek 发送测试消息。
- `git diff --check`、`codesign --verify --deep --strict` 与 Info.plist 校验：通过。

## 完成度更新

| 项目 | 更新前 | 更新后 | 证据 |
| --- | ---: | ---: | --- |
| 双页面命令钩子 | 15% | 95% | 实现、自动检查、生产构建与本机页面加载均已完成；仅真实 Chat 动态观感待手工验证 |

## 剩余工作

- 在用户主动发起下一次 DeepSeek Chat 回答时，观察 `running → review/failed → idle` 的动态观感；该步骤不影响代码交付，也不应由自动审核擅自发送聊天内容。

## 2026-09-08 续作与本地部署

- 修复 Harness 事件顺序问题：错误先到、running 后变为 false 时，保留失败反馈，不再切换成成功动作。失败动画已经结束时直接恢复待机。
- 增加真实 Hook 的确定性渲染与计时回归：旧错误基线、失败后停止、下一次成功、新任务取消旧计时、失败反馈播完后停止、切换会话全部通过。
- `./scripts/run_checks.sh` 通过；沙箱无法绑定 loopback，Core 的 listener lookup 检查按现有规则跳过，其余检查通过。
- `./scripts/build_app.sh`、`git diff --check` 通过；安装到 `/Applications/HarnessDock.app`，严格签名校验通过并启动。
- 实机确认 Harness 页面加载且 Marina 显示，Chat 首页正常加载。Chat 宠物设置当前为关闭、选择为 Marina；保留用户偏好，没有为了验收修改开关。
- 未发起真实模型请求；真实回答期间的动作观感仍待开启 Chat 原生宠物后观察。

## 2026-09-09 菜单栏入口

- 新增 macOS `MenuBarExtra`：菜单栏显示当前宠物的 22pt 图标，展开面板支持切换宠物、开关 Chat 原生宠物、打开主窗口和退出应用。
- `./scripts/build_app.sh`、`git diff --check` 与 `/Applications/HarnessDock.app` 严格签名校验通过。
- 重启后主窗口当前提示 Harness 依赖安装失败：本地 npm 缓存中没有 `@deepseek-ai/dsh@0.1.2-rc.1`；这不影响菜单栏 Swift 入口编译，但阻止 Harness 页面进入运行态。菜单栏场景已出现在应用辅助功能树中。
