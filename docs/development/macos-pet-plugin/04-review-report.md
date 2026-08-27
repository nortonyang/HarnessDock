# Codex 5.5 审核报告：macOS 桌面宠物插件

## 审核范围

- 规划与验收：本目录 `00-master-plan.md` 至 `03-gemini-handoff.md`。
- 核心契约：`Sources/HarnessDockCore/PetPlugin.swift`。
- macOS 运行时与 UI：`PetPluginController.swift`、`PetPluginView.swift`、`ContentView.swift`、`HarnessDockApp.swift`。
- 验证与说明：核心检查、单元测试、构建脚本与 README。
- 独立 QA Bundle ID 的实机欢迎页和宠物设置 sheet；未退出或干扰正在运行的正式 HarnessDock 会话。
- DeepWhale 孵化运行、逐帧检查、联系表、最终图集、包清单和应用内置资源。
- Marina 孵化运行、Codex 包安装、Chat 选择同步与重启发现。

## 问题发现

| 严重级别 | 问题 | 证据 | 必要动作 |
| --- | --- | --- | --- |
| 已修复 P2 | 孵化器清单使用 `displayName`/`spritesheetPath`，旧解码器只接受 `name`/`spritesheet`，导致首轮 UI QA 回退到外部 Nova | 独立 QA AX 标签首轮为“桌面宠物 Nova Codex01” | 核心模型兼容新旧两套字段并增加自动检查，第二个全新 Bundle ID 验证 DeepWhale 默认显示 |
| 已修复 P3 | 首版 `running-right` 实际头朝左，左右语义相反 | 人工检查首版联系表 | 只重开该行，强制“头右尾左”后重新生成，并从批准的右向行精确镜像左向行 |
| 无未解决 P1/P2/P3 | 未发现阻断发布的计划内缺陷 | 最终核心检查、Release 构建、签名校验、资源哈希和窗口 QA 均通过 | 无 |
| 环境限制 | `swift test` 在当前 Command Line Tools 环境缺少仓库既有测试使用的 `Testing` 模块 | `DeepSeekBalanceTests.swift:2` 在测试发现阶段报 `no such module 'Testing'` | 安装完整匹配的 Xcode 后补跑；本轮新契约已同步覆盖在 `HarnessDockCoreChecks` |
| 构建兼容 | 默认 macOS 26.5 SDK 与已安装 Swift 编译器补丁版本不一致 | 原始 `swift build` 报 SDK/compiler mismatch | 构建脚本在 Command Line Tools 环境优先使用支持 macOS 14 目标的 MacOSX15 SDK，验证已通过 |
| 预览限制 | 当前机器未安装 `ffmpeg` | 视频渲染步骤报 `FileNotFoundError` | 使用工作流支持的 `--skip-videos` 完成最终化；逐帧 QA、联系表、透明图集与尺寸校验均通过 |
| 已修复 P2 | Chat 先前选中内置 DeepWhale，与 Harness 页选择的 Marina 不同 | 已安装 Marina Codex 包，UserDefaults 为 `codex:marina`，Chat 实机 AX 与截图均显示 Marina | 无 |

## 验收标准检查

| 用户故事 | 结果 | 证据 |
| --- | --- | --- |
| US-501 | 通过 | 清单默认几何、ID、名称、路径逃逸和固定几何均在核心模型中校验；兼容旧字段和孵化器新字段 |
| US-502 | 通过 | 独立 QA 窗口自动发现 `~/.codex/pets`，设置页显示 Codex 来源宠物 |
| US-503 | 通过 | 导入先校验、复制到唯一目录、复制后复验、失败清理；选择与尺寸写入独立 UserDefaults 键 |
| US-504 | 通过 | 9 行逐帧时序集中定义；图集按行列裁切并支持减少动态效果 |
| US-505 | 通过 | 实机 AX 树中宠物为单独的小范围按钮，欢迎页其余控件保持独立可达；点击和右键动作已接入 |
| US-506 | 通过 | 独立 QA 窗口工具栏爪印打开设置页；菜单和 `⇧⌘P` 代码路径完成构建 |
| US-507 | 通过 | Harness 与 Chat 分别映射 loading/error/idle，隐藏页面的旧错误不会污染当前动画状态 |
| US-508 | 通过 | 核心检查、Debug/Release 构建、应用打包、Info.plist 与签名校验通过 |
| US-509 | 通过 | DeepWhale 9 行动画、透明图集、联系表、验证 JSON 和包清单均完成；方向问题经人工 QA 修复 |
| US-510 | 通过 | DeepWhale 随 SwiftPM 和正式 `.app` 内置；全新 Bundle ID 默认 AX 标签为“桌面宠物 DeepWhale” |
| US-511 | 通过 | 爪印入口打开“桌面宠物插件”，设置页显示 DeepWhale 与“HarnessDock 内置”；README 解释网页列表中看不到的原因 |
| US-512 | 通过 | 10 个任务全部完成；QA 无 error/warning；源/目标哈希一致；`~/.codex/pets/marina` 完整；Chat 实机显示“桌面宠物 Marina” |

## 验证结果

- `./scripts/run_checks.sh`：通过；监听器检查因当前沙箱禁止 loopback fixture 而按既有逻辑跳过。
- `env SDKROOT=.../MacOSX15.4.sdk ... swift build --disable-sandbox`：通过。
- `./scripts/build_app.sh`：通过，生成 `dist/HarnessDock.app`。
- `codesign --verify --deep --strict dist/HarnessDock.app`：通过。
- `plutil -lint dist/HarnessDock.app/Contents/Info.plist`：通过。
- `git diff --check`：通过。
- DeepWhale 生成工作：主参考由父任务生成；`idle`、`running-right`、`waving`、`jumping`、`failed`、`waiting`、`running`、`review` 行由图像生成子任务产出并由父任务逐张审核、登记；`running-left` 在确认无文字、手持物或非对称标记后由已批准右向行精确镜像。
- DeepWhale QA：`qa/review.json` 无 errors/warnings；`final/validation.json` 确认 RGBA WebP 为 1536×1872；人工复核最终 `qa/contact-sheet.png` 通过。
- 内置资源：源图集与 `dist/HarnessDock.app/Contents/Resources/Pets/DeepWhale/spritesheet.webp` SHA-256 均为 `ebc6e64d252a957cd4bfe1573baa6fbc61310f5142c3e9b1269141049735151e`。
- 独立 Bundle ID UI QA：第二次全新偏好启动时 AX 标签为“桌面宠物 DeepWhale”；工具栏爪印打开“桌面宠物插件”，选择值为 DeepWhale、来源为“HarnessDock 内置”、启用值为 1。
- 生成记录兼容：当前内置 imagegen 原始文件名为 `exec-*.png`，运行目录中的工具副本仅扩展来源文件名前缀校验（仍要求文件位于 `$CODEX_HOME/generated_images` 并校验 SHA-256），未伪造来源或改写生成图。
- `swift test --disable-sandbox`：未通过，原因是仓库原有 `DeepSeekBalanceTests.swift` 依赖当前环境不存在的 `Testing` 模块，不是本轮代码编译失败。
- Marina Codex QA：`pet_job_status.py` 显示 10/10 complete；人工复核联系表通过；图集为 1536×1872，验证与 review 均无 error/warning。
- Marina 安装：`pet.json` SHA-256 为 `ca10b27cb0eb19c81f7e15372fabf892c26386250dc2fe974e23d37fb86a6b16`，图集 SHA-256 为 `3f74cea48fa8f855db1c663551d369aabddb81e21610ca4c4bffd3ccb8962ce4`，源包与 `~/.codex/pets/marina` 一致。
- Chat 实机：偏好为 `codex:marina` 且启用值为 `1`；重启 HarnessDock 后 AX 标签为“桌面宠物 Marina”，截图确认右下角显示鲸鱼女仆。

## 完成度更新

| 项目 | 更新前 | 更新后 | 证据 |
| --- | ---: | ---: | --- |
| 宠物包契约 | 0% | 100% | 核心模型与检查通过 |
| 包发现、导入与持久化 | 0% | 100% | 控制器实现、Release 构建与实机发现通过 |
| 动画覆盖层与设置 | 0% | 100% | 独立 QA 窗口视觉与 AX 验证通过 |
| 文档与验证 | 0% | 100% | README、规划、构建和本审核报告 |
| 内置 DeepWhale | 0% | 100% | 孵化 QA、应用资源、包内哈希与独立 UI QA |
| Marina Codex 宠物与 Chat 同步 | 0% | 100% | 孵化 QA、Codex 安装目录、哈希、偏好与 Chat 实机截图 |

## 剩余工作

- 没有未完成的计划内开发项；仅预览 MP4 因本机无 `ffmpeg` 未生成，不影响运行时宠物包。
- 可选后续：在安装完整匹配 Xcode 的环境补跑全部 `swift test`；如需跨应用的真正“桌面悬浮宠物”，应作为独立阶段设计 `NSPanel`、多屏与权限边界。
