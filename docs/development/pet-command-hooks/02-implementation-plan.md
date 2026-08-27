# 具体开发方案：双页面宠物命令钩子

## 开发方案

| 步骤 | 工作内容 | 文件或区域 | 验证方式 | 状态 |
| --- | --- | --- | --- | --- |
| 1 | 定义 `PetCommandActivity` 与动画映射/周期 | `DsHarnessCore/PetPlugin.swift` | Core 单测 | 进行中 |
| 2 | Harness 插件注入 `sessions`，订阅列表和当前 Session | `plugins/dsh-pet/src/client.template.js` | 插件静态与纯函数检查 | 进行中 |
| 3 | 将命令状态以高优先级动画覆盖到 Web 宠物 | Web `PetOverlay` | running/review/failed 边沿测试 | 未开始 |
| 4 | 编写 Chat 页面生成状态脚本与枚举桥 | Core 新脚本、`DeepSeekChatWebView` | Node VM 检查 | 未开始 |
| 5 | AppModel 管理终态完整周期并驱动原生宠物 | `AppModel`、`ContentView` | Core 映射、Swift 构建 | 未开始 |
| 6 | 根回归、部署、签名和实机审核 | checks、dist、Applications | 命令与 UI 证据 | 未开始 |

## 实现约束

- Harness 必须使用 `ctx.sessions` 官方快照，不查询 DOM 文案。
- React 订阅必须使用 `useSyncExternalStore`，首次快照只建立基线；卸载时清理定时器和订阅。
- Chat 脚本只允许向 `dshPetCommand` 发送四个固定字符串。
- `PetCommandActivity` 的成功/失败复位时间来自目标动画 `cycleDurationMilliseconds`，不重复硬编码。
- 命令动画只覆盖视觉状态；不得更改 overlay 的 `pointer-events: none`、拖动捕获或 localStorage 偏好。
- 页面加载错误优先显示 `failed`；页面导航加载不等同于用户命令运行。

## 具体案例

| 案例 | 输入或上下文 | 期望行为 | 验证方式 |
| --- | --- | --- | --- |
| Harness 普通任务 | 当前 summary.running=true→false | running→review 一轮→idle | 纯函数、实机 |
| Harness 后台任务 | job running/stopping | running，完成后 review | 插件检查 |
| Harness 新错误 | error token 改变 | failed 一轮 | 插件检查 |
| Chat 正常回答 | 停止生成按钮出现再消失 | running→succeeded | VM、实机 |
| Chat 回答错误 | 运行后出现错误提示 | running→failed | VM |
| 首次打开旧会话 | 已有错误节点但没有本轮 running | 不误触发 | VM、首次快照检查 |

## 兼容与回滚

- 新的 Core 枚举是应用内状态，不持久化，不需要迁移。
- Web 插件仍只依赖已声明的 runtime 与 slots；删除 `sessions` 注入和命令 Hook 即恢复鼠标动作版。
- Chat 只增加独立 user script/message handler；移除后恢复页面加载状态驱动。

## Codex 审核清单

- 两边是否都响应运行、成功、失败。
- 是否使用官方 Harness 服务而非 DOM 猜测。
- Chat 是否只传枚举且不采集正文。
- 终态是否完整播放一轮且不会覆盖下一次运行。
- 现有点击、拖动、贴边、穿透和页面加载行为是否回归通过。
