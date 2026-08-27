# 总开发阶段文档：Harness 桌面宠物插件与 Marina

## 目标

在 DsHarness 仓库内开发一个可通过 `dsh plugin --profile web add` 安装的真正 DeepSeek Harness 插件。插件的 Loader 条目 ID 为 `pet`，安装后必须出现在 Harness 的“设置 → 插件 → 插件列表”中；浏览器端通过 `shell.overlay` 显示动画宠物，并在“插件”设置分区提供 DeepWhale / Marina 切换、显示开关与持久化偏好。

Marina 基于用户提供的鲸鱼女仆参考图生成，最终与现有 DeepWhale 一起打包进插件。

增量目标：宠物可停靠在 Harness 左、右或底部边框，部分身体隐藏在窗口外；拖动时跟手移动，松开后吸附最近边框并保存位置。悬停、点击、拖动分别播放观察、跳跃、奔跑动作；下方是按钮等交互控件时仍优先 Harness 控件，按住 `⌥ Option` 才强制拖动。普通状态继续点击穿透，并周期性探出再缩回。

左侧停靠时精灵必须水平镜像，使头部朝向 Harness 内容区；左移隐藏后应露出头部，把尾部和身体藏到窗口外。右侧、底部和设置页预览不受此镜像影响。

边框停靠不能只是把完整精灵沿直线切掉固定比例。左右缩回时头部要向内容区倾斜、身体藏得更深，探出时逐渐站直；底部缩回优先隐藏下半身并保留头部轮廓，形成躲在窗口外探头的姿态。

动作播放必须严格对应 Marina 图集的实际行序和帧数：悬停使用 waiting 第 6 行、点击使用 jumping 第 4 行的 5 帧、拖动使用 running 第 7 行；状态切换不能落入 failed 行或透明空格，也不能因错误帧数产生闪空。

## 非目标

- 不把 macOS 原生悬浮窗当作 Harness 插件列表中的插件。
- 不修改或覆盖 Harness 内置 npm 包。
- 不把原始参考图直接作为宠物图集发布。
- 不引入远程服务、账户或运行时网络依赖。
- 不支持顶部停靠；直立角色从顶部裁切会先隐藏头部，不符合探头语义。

## 当前证据

- 本机 Harness 版本为 `@deepseek-ai/dsh 0.1.0-rc.6`。
- `@deepseek-ai/dsh-client-ui-layout` 声明了列表插槽 `shell.overlay`，适合附加全局宠物层。
- `@deepseek-ai/dsh-client-ui-settings-plugins` 声明了 `settings.plugins.tab`，适合在“插件”页面添加宠物选择界面。
- DSH profile 插件包可通过 `dsh.bundle.patch` 插入 Loader 条目；声明 `dsh.client` 和 `./client` 导出后，浏览器端 bundle 会进入启动图。
- 插件清单页展示 Loader 条目，因此 `id: pet` 安装启用后会显示为插件卡片。
- DeepWhale 与 Marina 均已完成 8×9 图集、QA 与打包；Marina 最终验证无 error 或 warning。
- 本机无 `ffmpeg`；最终流程显式跳过 MP4，但必须完成逐帧检查、联系表和图集验证。

## 假设与决策

- npm 包名采用 `@dsharness/pet`，Loader 条目 ID 为 `pet`，用户可见名称采用“桌面宠物”。
- 浏览器设置使用专属 localStorage 键保存宠物 ID 和显示开关；不伪造 Harness Host settings schema。
- 插件客户端为预构建的单文件 bundle，图集以内嵌 data URL 交付，避免依赖 `/plugins` 路由未承诺的静态资源能力。
- Marina 保留蓝色长发、蓝眼、鲸鳍耳、大鲸尾、白色褶边头饰、胸前蝴蝶结与深蓝白女仆裙；细小刺绣简化。
- Marina 的侧边发饰和尾巴有方向性，左右移动分别生成，不镜像派生。

## 风险

| 风险 | 影响 | 缓解方案 |
| --- | --- | --- |
| 插件只被 npm 安装但未进入 profile bundle | 插件列表看不到 | 包清单声明 `dsh.bundle.patch`，安装后检查 profile bundles 与 `--dump-config` |
| 客户端依赖或插槽加载顺序错误 | Loader 条目存在但 UI 不显示 | `dsh.client.inject` 声明 runtime、layout、settings 与 settings-plugins 依赖，注册使用 `ctx.slots.inject` |
| 图集静态资源无法由插件路由提供 | 宠物透明或 404 | 构建时将 WebP 编码为 data URL 写入单文件 client bundle |
| 设置刷新后丢失 | 用户需反复切换 | 使用插件专属 localStorage 键并处理非法旧值 |
| 高细节人形在小格内不可读 | Marina 身份丢失 | 锁定 Q 版主造型，逐行动作以参考图和 canonical base 共同 grounding |
| 左右移动镜像破坏侧向特征 | 发饰、尾巴方向错误 | `running-right` 与 `running-left` 分别生成并人工 QA |
| 播放器状态表与图集行序不一致 | 悬停像失败、拖动像等待、点击闪空 | 以 `frames-manifest.json` 为唯一动作行与帧数依据，并加入精确静态断言 |

## 阶段地图

| 阶段 | 目的 | 退出条件 | 状态 |
| --- | --- | --- | --- |
| S1 | 固化真实 Harness 插件契约 | 包名、Loader ID、插槽、设置和安装方式明确 | 已完成 |
| S2 | 生成 Marina 动画包 | 9 行动画、透明图集与 QA 全部通过 | 已完成 |
| S3 | 实现 DSH 插件 | `pet` 条目、overlay 与插件设置页工作 | 已完成 |
| S4 | 安装与实机审核 | web profile 可见、可切换、刷新保持选择 | 已完成 |
| S5 | 贴边探头交互 | 三边停靠、自动吸附、位置持久化、点击穿透与探头动画通过 | 已完成 |
| S6 | 交互动作与发布就绪 | 悬停/点击/拖动动作通过，npm 包内容可检查，上游官方收录路径明确 | 已完成 |
| S7 | 本机应用部署 | 插件嵌入 app bundle、真实 profile 指向应用副本、重启后插件可见 | 已完成 |
| S8 | 修复左侧朝向与藏身部位 | 左侧精灵朝内且露头藏身，其他停靠边行为不变 | 已完成 |
| S9 | 优化三边藏身探头姿态 | 左右呈倾斜探头而非直线腰斩，底部优先露头，拖动与穿透不回归 | 已完成 |
| S10 | 修复交互动作语义与节奏 | hover/click/drag 使用正确动作行与帧数，连续触发不闪空、不串动作 | 已完成 |

## 验证策略

- `pet_job_status.py` 确认 Marina 全部视觉任务完成且来源可追溯。
- `qa/review.json` 无 error/warning，`final/validation.json` 确认 RGBA WebP 为 1536×1872。
- 人工检查 Marina 联系表的身份一致、方向、透明空槽和无游离特效。
- 对插件清单、patch、client bundle 与两个内嵌图集执行静态检查。
- 使用 `dsh plugin --profile web add ./plugins/dsh-pet` 安装，并通过 `dsh --profile web --dump-config` 看到 `id: pet`、`name: '@dsharness/pet'`。
- 在真实 Harness UI 检查插件列表卡片、桌面宠物设置标签、即时切换和刷新后持久化。
- 对左、右、底三边的吸附计算做自动检查；验证普通点击仍命中宠物下方控件，`⌥` 拖动才接管定位。
- 检查应用内插件文件、代码签名、profile link 目标和重启后的 3080 启动图，确保部署不依赖开发仓库。
- 检查左侧 overlay 只镜像精灵、不反转定位容器；左侧缩回时隐藏尾部/身体，右侧和底部 CSS 不回归。
- 检查左右缩回/探出两态的位移与倾角、底部露头比例及拖动复位；在真实 Harness 页面截图审核“藏身”读感。
- 对照 Marina `frames-manifest.json` 检查 waiting/jumping/running 的行号、帧数和周期；实机逐项触发悬停、点击、拖动，确认状态转换自然且无透明帧。
