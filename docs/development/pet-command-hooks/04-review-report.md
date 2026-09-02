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
