# Gemini 代码开发交接：双页面宠物命令钩子

用户要求当前 Codex 直接开发；本文仅保留可复用交接稿，不声称已经委派。

事实来源：

- `docs/development/pet-command-hooks/00-master-plan.md`
- `docs/development/pet-command-hooks/01-stages-and-stories.md`
- `docs/development/pet-command-hooks/02-implementation-plan.md`

实现范围：

- Harness Web 宠物通过官方 `sessions` 服务订阅当前会话、后台任务和错误快照。
- Chat 原生宠物通过 WebKit 页面状态脚本接收 `idle/running/succeeded/failed` 固定枚举。
- 两边映射为 running/review/failed，终态完整一轮后恢复。

约束：

- 不读取或传递提示词、回复、命令参数、工具输出。
- 不修改官方 Harness 包或 DeepSeek Chat 页面资源。
- 不改变鼠标交互、贴边、穿透、宠物偏好和已有 Enter 行为。
- 不新增图片；使用现有图集行。

需要验证：插件 check、Chat Hook VM 检查、Core 测试、根检查、生产构建、签名与两页面实机状态。
