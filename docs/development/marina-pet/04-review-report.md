# Codex 审核报告：Harness 桌面宠物插件

## 审核范围

- Marina 孵化运行与图集。
- `@dsharness/pet` 包清单、bundle patch 和客户端 bundle。
- Harness 插件列表、全局 overlay、插件设置页与偏好持久化。
- DsHarness 原生回归检查。
- 贴边停靠、自动吸附、位置持久化、点击穿透与周期探头增量。
- 悬停、点击、拖动动作反馈和 npm 发布预检增量。
- app bundle 内嵌、本机 Applications 安装、profile 重绑与重启验证。

## 问题与修复

| 严重级别 | 问题 | 必要动作 | 状态 |
| --- | --- | --- | --- |
| P1 | 先前方案只实现 macOS 原生宠物，无法出现在 Harness 插件列表 | 已开发真实 DSH bundle/client 插件并安装到 web profile | 已修复 |
| P1 | 原生宠物会覆盖 Harness 输入区或按钮，并与 Web 插件重复 | 原生覆盖层和爪印入口仅在 Chat 页面出现；Harness 插件 overlay 全量 click-through 并自动避开输入区 | 已修复 |
| P2 | Marina 仅完成主造型，尚无动作图集 | 已完成 9 行生成、QA、透明图集与打包 | 已修复 |
| P2 | 插件尚未安装，暂无真实 UI 证据 | 已执行真实 profile 安装、dump-config 与 Harness 实机检查 | 已修复 |
| P2 | 宠物只能固定在右下附近，缺少贴边探头感 | 增加三边停靠、拖动吸附、部分隐藏和周期探头 | 已修复 |
| P2 | 宠物尚未响应悬停、点击和拖动状态 | 使用 waiting、jumping、running 动作行，并保持控件优先 | 已修复 |
| P1 | 当前 profile 链接开发仓库，安装应用后仍有路径依赖 | 插件已嵌入 app Resources，真实 profile 已重绑到应用副本 | 已修复 |
| P1 | 未锁版本的 npx 启动解析到新 rc.2，依赖重建卡住且内存升至约 2.3 GB | 锁定 rc.6；优先直接运行版本匹配的 `_npx` 缓存，缺失时才以 `--prefer-offline` 回退 npx | 已修复 |
| P2 | 左侧停靠沿用了右侧精灵朝向，导致头部被藏在窗口外、尾部露在内容区 | 只镜像左侧 overlay 内的精灵，保留容器向左裁切 | 已修复 |
| P2 | 三边停靠仅做固定比例直线裁切，角色像被切半而不像躲在边框后探头 | 加深缩回位移；左右头部向内倾斜，探出时站直；拖动时复位姿态 | 已修复 |
| P2 | 交互状态表与图集清单错位：悬停播放 failed、拖动播放 waiting，jumping 多循环一个透明空格 | 按 manifest 改为 waiting 6/6、jumping 4/5、running 7/6，并补精确断言 | 已修复 |

## 验收标准检查

| 用户故事 | 结果 | 证据 |
| --- | --- | --- |
| US-601 | 通过 | `web` profile 组合配置包含 `id: pet`；插件列表搜索 `pet` 显示“已挂载 / 已启用” |
| US-602 | 通过 | Marina canonical base 与最终联系表已人工检查，鲸鱼女仆身份一致 |
| US-603 | 通过 | 9 行完成；running-left 独立生成；1536×1872 RGBA WebP，验证无 error/warning |
| US-604 | 通过 | `shell.overlay` 已挂载；宠物位于输入区上方，`pointer-events: none`，按钮命中测试仍落到按钮 |
| US-605 | 通过 | DeepWhale / Marina / 隐藏可即时切换；刷新后 Marina 选择保持 |
| US-606 | 通过 | 本地 link 包已通过官方 profile 命令安装；插件与原生构建检查通过 |
| US-607 | 通过 | 三边纯函数检查通过；真实拖动吸附左侧，刷新后仍为左侧；底边实测约 58 px 藏在视口外 |
| US-608 | 通过 | 真实悬停为 `hovering`、点击为 `clicked`、拖动结束为 `waving`；拖动过程绑定 `dragging` 行；overlay 始终 `pointer-events: none` 且命中下层元素 |
| US-609 | 通过 | `npm pack --dry-run --json` 通过，仅 6 个必要文件，压缩 4,352,020 bytes；README 已说明 npm/GitHub 与官方上游 PR 的区别 |
| US-610 | 通过 | app 内含 6 个发布文件且签名有效；profile link 指向 `/Applications`；重启后 3080 返回 200，启动图含 `@dsharness/pet` |
| US-611 | 通过 | 左侧 selector 只对子级 sprite 应用 `scaleX(-1)`；右/底边无镜像；插件检查、应用构建和 3080 实际脚本核验通过 |
| US-612 | 通过 | 左右静止为 22° 朝内探头、探出减到 6°，底部缩回保留头部；三边真实 Harness 截图、拖动复位和本机部署通过 |
| US-613 | 通过 | manifest 与运行脚本均为 waiting 6/6、jumping 4/5、running 7/6；点击落到悬停、移开回待机、拖动吸附后回落均已实机复核 |

## 完成度

| 项目 | 完成度 | 证据 |
| --- | ---: | --- |
| DSH 接口与需求契约 | 100% | 官方本机包类型、README 与修订后的开发文档 |
| Marina 动画包 | 100% | 9 行、联系表、最终图集、package 与验证报告 |
| Harness 插件实现 | 100% | `plugins/dsh-pet` 清单、patch、client、构建与检查脚本 |
| 安装与 UI 验证 | 100% | 真实 web profile、组合配置、插件卡片、设置切换、刷新持久化与命中测试 |
| 贴边探头交互 | 100% | 三边设置、直接/Option 拖动、最近边吸附、刷新持久化和视觉 QA |
| 交互动作与发布就绪 | 100% | hover/click/drag 状态、事件穿透、npm pack 与发布说明 |
| 本机应用部署 | 100% | `/Applications/DsHarness.app`、应用内插件文件、profile link、固定版本直启进程与 3080 启动图均已核验 |
| 左侧朝向与藏身修复 | 100% | 左侧只镜像精灵并保留负向位移，右侧、底部和设置预览不受影响；本地应用已重新部署 |
| 三边藏身姿态 | 100% | 左右探头倾角、底部下沉、探出与拖动复位已通过插件检查和本地应用截图审核 |
| 交互动作协调修复 | 100% | 动作行/帧数精确断言、完整周期计时、真实 hover/click/drag 回落与 3080 运行脚本证据 |

## 增量验证结果

- `npm --prefix plugins/dsh-pet run build`：通过。
- `npm --prefix plugins/dsh-pet run check`：通过，覆盖三边吸附、旧偏好迁移、动作行和点击穿透契约。
- Harness 3081 真实页面：悬停探出、点击跳跃、拖动吸附、刷新持久化和设置页三边选择通过。
- `npm pack ./plugins/dsh-pet --dry-run --json`：通过，6 个文件。
- `./scripts/run_checks.sh` 与 `./scripts/build_app.sh`：通过。
- `/Applications/DsHarness.app`：`codesign --verify --deep --strict` 通过，插件 6 个发布文件齐全。
- `dsh plugin --profile web list`：`@dsharness/pet` 链接到应用 `Contents/Resources/Plugins/dsh-pet`。
- 本地 3080：HTTP 200；`__DSH_BOOT__` 含 `@dsharness/pet`，运行进程直接使用已验证的 rc.6 缓存。
- 左侧回归：`npm --prefix plugins/dsh-pet run check` 通过；运行中的 `/plugins/@dsharness/pet/client.js` 已包含左侧 `scaleX(-1)` 规则。
- 动作协调回归：运行中的插件脚本确认 clicked=`row 4/5 帧/150ms`、hovering=`row 6/6 帧/260ms`、dragging=`row 7/6 帧/140ms`；短反馈按 `frames × interval` 完整周期结束。
- 本地应用实机：底边点击后自然落到 waiting 悬停，移开回 idle 藏身；拖动到右边后完成挥手并回悬停/待机，未出现 failed 串行或透明闪空。

## 视觉生成与修复记录

- 动作行由孵化流程委派生成；`running-left` 与 `running-right` 分别生成，没有镜像派生。
- `running` 初稿出现多余道具，已弃用并重新生成空手版本；最终来源只登记修复后的行。
- 最终联系表已人工检查，无身份漂移、跨槽元素或游离特效。
- 当前环境缺少 `ffmpeg`，因此显式跳过 MP4 预览；逐帧 QA、联系表、透明度和图集结构验证均已完成。
