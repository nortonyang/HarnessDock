# 阶段与原子用户故事：Harness 桌面宠物插件

## 阶段与子任务

| 子任务 | 交付结果 | 用户故事 | 状态 |
| --- | --- | --- | --- |
| ST-601 | 真实 DSH 插件契约 | US-601 | 已完成 |
| ST-602 | 8×9 Marina 宠物包 | US-602、US-603 | 已完成 |
| ST-603 | `@dsharness/pet` bundle/client 插件 | US-604、US-605 | 已完成 |
| ST-604 | 安装、构建与实机审核 | US-606 | 已完成 |
| ST-605 | 贴边、拖动吸附与探头动画 | US-607 | 已完成 |
| ST-606 | 悬停、点击、拖动动作与发布检查 | US-608、US-609 | 已完成 |
| ST-607 | 应用内嵌与本机安装 | US-610 | 已完成 |
| ST-608 | 左侧朝向与藏身修复 | US-611 | 已完成 |

## US-601：插件可被 Harness 识别

作为 Harness 用户，我希望宠物是设置页插件列表中的正式插件，而不是仅由 DsHarness macOS 外壳绘制的功能。

验收标准：

- Given 插件安装到 `web` profile，When 查看组合配置，Then 存在 `id: pet` 且模块名为 `@dsharness/pet`。
- Given Harness 正常启动，When 打开“设置 → 插件 → 插件列表”，Then 可以搜索并看到 `pet`，状态为启用。

## US-602：Marina 保持参考角色身份

作为用户，我希望 Marina 明显对应参考图中的鲸鱼女仆，而不是泛化蓝发角色。

验收标准：

- 主造型和每个动作均保留蓝色长发、蓝眼、鲸鳍耳、鲸尾、白色女仆头饰、深蓝白裙装与蝴蝶结。
- 缩小到单格后轮廓仍清楚，无文字、额外角色、游离特效或跨槽组件。

## US-603：Marina 动作包符合播放器契约

作为插件运行时，我希望 Marina 使用和 DeepWhale 相同的 8×9 图集契约。

验收标准：

- 9 行动作完整，running-left 与 running-right 分别生成且方向正确。
- 最终为 1536×1872 RGBA WebP；已用格非空、未用格透明，QA 无错误。
- 每行来自内置 imagegen 原始输出，并以用户参考图和 canonical base grounding。

## US-604：宠物出现在 Harness 全局界面

作为 Harness 用户，我希望宠物位于应用右下角，并且不阻断下面的聊天与设置操作。

验收标准：

- 插件向 `shell.overlay` 追加独立条目，不替换应用根布局。
- overlay 全部保持 click-through，任何宠物像素都不截获鼠标；宠物自动避开可见输入区和按钮。
- 默认展示 DeepWhale，支持空闲动画和定时挥手反馈。

## US-605：在插件设置里切换宠物

作为 Harness 用户，我希望在“设置 → 插件 → 桌面宠物”中选择 DeepWhale 或 Marina，也可隐藏宠物。

验收标准：

- 选择器列出两只宠物并显示预览。
- 切换或显示开关立即影响 overlay。
- 刷新 Harness 后仍保持最后一次有效选择；损坏偏好回退 DeepWhale。

## US-606：可安装且可回滚

作为维护者，我希望插件通过官方 profile 插件命令安装，不改写 Harness 内置包。

验收标准：

- 本地包可以被 `dsh plugin --profile web add` 安装并加入 profile bundles。
- 删除该依赖即可移除插件层；仓库内插件是唯一源代码，不修改 npm 缓存中的 Harness 文件。
- DsHarness 原生构建检查仍通过，现有用户改动不被覆盖。

## US-607：贴边后探头探脑

作为 Harness 用户，我希望把宠物放到应用边框，让它隐藏部分身体并偶尔探出来，同时不妨碍操作。

验收标准：

- Given 宠物正常显示，When 未按修饰键点击宠物覆盖区域，Then 事件继续命中下方 Harness 控件。
- Given 用户从非交互背景上的宠物区域拖动，或按住 `⌥ Option` 强制拖动，When 松开指针，Then 宠物吸附到左、右、底三条边中最近的一条，并保存沿边位置。
- Given 用户不拖动，When 到达探头周期，Then 宠物从部分隐藏位置平滑探出，随后缩回；减少动态效果时不执行位移动画。
- Given 用户不便拖动，When 在插件设置选择停靠边，Then 宠物立即移动到该边并持久化。

## US-608：指针交互有角色动作

作为用户，我希望宠物会回应光标、点击和拖动，让它更像活着的桌面伙伴。

验收标准：

- Given 光标进入宠物可见区域，When 不进行点击，Then 播放观察动作并保持下层控件可命中。
- Given 用户点击宠物区域，When 下层恰好是按钮，Then 宠物播放跳跃动作且按钮点击不被阻止。
- Given 用户从非交互背景上的宠物区域拖动，When 越过拖动阈值，Then 宠物播放奔跑动作并跟随指针；如果下层是交互控件，则普通拖动优先控件，`⌥` 拖动可显式接管。

## US-609：包可发布并可申请官方收录

作为维护者，我希望插件包内容通过 npm 打包检查，并知道如何申请 DeepSeek 官方收录。

验收标准：

- `npm pack --dry-run` 只包含运行所需清单、bundle、资源索引、patch 和 README。
- 文档明确区分 npm/GitHub 可安装发布与 DeepSeek 官方收录；在没有公开官方插件站投稿入口时，不声称已经上传。
- 官方收录通过 `deepseek-ai/deepseek-harness` 上游提案或 PR，由项目维护者决定是否接受。

## US-610：部署到本地 DsHarness 应用

作为本机用户，我希望宠物插件随安装后的 DsHarness 应用交付，不依赖开发仓库路径。

验收标准：

- Given 执行应用构建，When 检查 app bundle，Then `Contents/Resources/Plugins/dsh-pet` 包含插件运行所需的 6 个发布文件。
- Given 应用复制到 `/Applications/DsHarness.app`，When 安装 Harness profile 插件，Then `@dsharness/pet` 链接目标位于应用 Resources，而不是仓库目录。
- Given 旧 Harness 服务被安全重启，When 打开本地应用，Then 3080 启动图加载 `pet` 且设置页仍可见。

## US-611：左侧停靠露头且朝内

作为把宠物停靠在左边框的用户，我希望宠物面向应用内部，并把身体藏在左边框外，而不是把头藏起来只露出尾部。

验收标准：

- Given 宠物停靠左侧，When 处于缩回状态，Then 精灵相对右侧朝向水平镜像，头部朝右并留在内容区，尾部和身体从左侧窗口外裁切。
- Given 宠物周期探头或响应悬停，When 从左侧探出，Then 保持面向应用内部，定位容器仍从左边框向外/向内移动。
- Given 宠物停靠右侧、底部或显示在设置预览，When 本修复生效，Then 原有朝向和位置不变。
