# 阶段与原子用户故事：双页面宠物命令钩子

## 阶段与子任务

| 子任务 | 交付结果 | 用户故事 | 状态 |
| --- | --- | --- | --- |
| ST-701 | 统一命令活动模型 | US-701 | 已完成 |
| ST-702 | Harness 会话/任务钩子 | US-702 | 已完成 |
| ST-703 | Chat WebKit 生成钩子 | US-703 | 已完成 |
| ST-704 | 回归、部署和实机审核 | US-704 | 自动审核完成，实聊观感待用户验证 |

## US-701：两边使用一致的动作语义

作为同时使用 Harness 与 Chat 的用户，我希望两只宠物对任务状态的反应一致。

验收标准：

- Given 命令或回答正在执行，When 状态为 running，Then 宠物持续播放 `running`。
- Given 一次执行成功结束，When running 从 true 变为 false 且无新错误，Then 播放一次 `review` 后回待机。
- Given 一次执行出现新错误，When 错误边沿到达，Then 播放一次 `failed` 后回待机。

## US-702：Harness 宠物订阅官方命令状态

作为 Harness 用户，我希望宠物跟随当前会话和后台命令工作，而不是依靠页面文字猜测。

验收标准：

- Given 当前会话或其后台任务处于 running/stopping，When 快照更新，Then Web 插件宠物播放 `running` 并探出。
- Given 当前会话结束，When running 出现 true→false 边沿，Then 播放一轮 `review`。
- Given `promptError`、`lastAgentError` 或新失败后台任务出现，When 错误 token 变化，Then 播放一轮 `failed`；首次挂载已有旧错误不触发。
- Given 用户同时悬停、点击或拖动，When 命令状态结束，Then 原有鼠标交互、贴边偏好和点击穿透仍工作。

## US-703：Chat 宠物感知回答生成

作为 Chat 用户，我希望原生鲸鱼女仆在 DeepSeek 正在回答时工作，结束后给出反馈。

验收标准：

- Given Chat 页面出现可见的停止生成控件，When DOM 状态更新，Then 本地桥只发送 `running`。
- Given 停止生成控件在一次运行后消失，When 未发现错误提示，Then 桥发送 `succeeded`；若发现新错误提示，Then 发送 `failed`。
- Given 原生收到终态，When 对应动画完成一个周期，Then 自动回到 idle；网页导航加载和加载错误仍保留原优先级。
- Given 页面包含用户文本，When 桥发消息，Then消息体只能是固定状态枚举，不能包含正文。

## US-704：可验证、可回滚

作为维护者，我希望钩子可以独立检查并随本地应用部署。

验收标准：

- 插件、Core 与 Chat 脚本检查全部通过。
- `./scripts/build_app.sh` 通过，`dist/HarnessDock.app` 的本地签名有效。
- 删除 Harness 订阅 Hook 与 Chat 脚本消息处理即可回滚，不涉及用户数据迁移。
