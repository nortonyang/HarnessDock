# Gemini 代码开发交接：Harness 桌面宠物插件

用户要求当前 Codex 直接开发；本文仅保留可复用交接稿，不声称已经交给 Gemini。

事实来源：

- `docs/development/marina-pet/00-master-plan.md`
- `docs/development/marina-pet/01-stages-and-stories.md`
- `docs/development/marina-pet/02-implementation-plan.md`

实现范围：

- 完成 Marina 8×9 动画包和 QA。
- 创建 `plugins/dsh-pet`，包名 `@dsharness/pet`、Loader ID `pet`。
- 通过 `shell.overlay` 绘制宠物，通过 `settings.plugins.tab` 提供 DeepWhale / Marina 切换。
- 用官方 `dsh plugin --profile web add` 安装并验证插件列表可见。
- 增量实现左、右、底三边停靠；按住 `⌥` 拖动后吸附最近边，部分身体藏在窗口外并周期性探头。
- 增量实现坐标式悬停观察、点击跳跃、拖动奔跑；普通点击继续传给下方 Harness 控件，交互控件上的拖动只在按住 `⌥` 时接管。
- 用 `npm pack --dry-run` 检查可发布内容；不虚构不存在的 DeepSeek 官方插件站上传结果。
- 构建时把 6 个运行文件嵌入 app Resources；本机安装后将 web profile 重绑到应用内插件副本并验证重启加载。
- 左侧停靠只对 `.dshpet-sprite` 做水平镜像，使头朝内容区且身体藏到左侧窗口外；禁止镜像 overlay 定位容器，右侧、底部和设置预览不得变化。
- 三边缩回要呈现“身体在窗口外、头部探入”的姿态：左右用更深位移与向内倾斜，探出时减小倾角；底部加深下沉。拖动时移除倾角，禁止修改 `pointer-events` 和文档捕获事件逻辑。
- 修正交互状态表：悬停必须使用 waiting 行 6（6 帧），点击使用 jumping 行 4（5 帧），拖动使用 running 行 7（6 帧）；以 `frames-manifest.json` 为依据，禁止播放 failed 行或透明第 6 格。

约束：

- 不修改 Harness 官方 npm 包，不把原生 macOS 悬浮窗冒充 DSH 插件。
- 不覆盖 DeepWhale；Marina 左右移动分别生成。
- 图像行必须来自内置 imagegen，父任务负责清单、登记、最终化和打包。
- 设置只持久化白名单宠物 ID、显示布尔值、三种允许的停靠边和安全范围内的归一化位置。
- 普通状态必须保持 `pointer-events: none`；只有 `⌥` 指针落在宠物矩形内才接管拖动，不能破坏 Harness 按钮。

需要返回：变更文件、安装命令、dump-config 证据、真实 UI 证据、QA/构建结果与偏离项。
