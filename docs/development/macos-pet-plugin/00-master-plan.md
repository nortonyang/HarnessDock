# 总开发阶段文档：macOS 桌面宠物插件

## 目标

为 DsHarness macOS 客户端增加原生桌面宠物插件：读取 Codex 兼容宠物包，在 Harness 与 Chat 页面上方显示透明动画宠物，根据应用运行状态切换动画，并提供启用、宠物选择、导入与尺寸设置。内置一只 DeepSeek 风格蓝色小鲸 `DeepWhale`，确保全新安装无需外部宠物包也能直接看到功能。

## 非目标

- 不把用户现有的私有宠物素材提交到仓库；内置 `DeepWhale` 由本阶段独立生成并完成来源记录。
- 不修改官方 DeepSeek Harness 页面、任务协议或模型调用。
- 不实现第三方可执行代码插件、脚本加载、网络宠物商店或云同步。
- 不让宠物在窗口外成为独立桌面悬浮窗口。

## 当前证据

- `Sources/DsHarnessApp/ContentView.swift` 以 SwiftUI `ZStack` 承载 Harness 与 Chat WebView，适合增加原生透明覆盖层。
- `Sources/DsHarnessApp/DsHarnessApp.swift` 统一创建应用模型、菜单命令和设置 sheet。
- `Sources/DsHarnessApp/AppModel.swift` 已暴露 Harness 状态、页面加载状态和错误，可映射为宠物动画状态。
- 当前 Swift Package 没有插件目标或资源目标，需要新增最小的宠物清单模型、运行时控制器和 SwiftUI 视图。
- 本机 `~/.codex/pets` 中已有 `pet.json` 与 `1536×1872` WebP 图集，可作为只读兼容性验证样本；仓库不会复制这些文件。
- Codex 宠物图集固定为 8 列 × 9 行，每格 192×208，并定义 idle、running、failed、waiting、review 等状态行。
- 用户反馈当前版本看不到插件；根因之一是插件没有内置宠物，另一个常见原因是仍在运行旧构建。插件是 macOS 原生能力，不会出现在 Harness 网页插件列表。

## 假设

- “宠物插件”解释为 DsHarness 内的可开关原生 UI 插件，不执行宠物包中的代码。
- 宠物包至少包含 `pet.json` 和清单指定的 `spritesheet.webp`；清单未声明尺寸时使用 Codex 固定尺寸。
- 应用可以只读扫描 `~/.codex/pets`，导入的包复制到 `Application Support/app.dsharness.desktop/Pets`。
- 内置宠物包随应用发布；没有用户宠物时默认选择 `DeepWhale`，已有有效选择时不覆盖用户偏好。

## 风险

| 风险 | 影响 | 缓解方案 | 负责人 |
| --- | --- | --- | --- |
| WebP 或图集尺寸无效 | 宠物裁切错误或不显示 | 加载时校验 1536×1872 像素和清单文件存在性 | Codex |
| 覆盖层抢占 WebView 交互 | Harness 点击受阻 | 仅宠物自身的小范围可命中，其余覆盖层不拦截事件 | Codex |
| 动画持续刷新增加耗电 | 空闲时资源占用上升 | 以帧持续时间驱动且尊重“减少动态效果” | Codex |
| 用户导入同名包覆盖 | 丢失现有本地包 | 使用稳定 ID 目录；导入前校验并以原子替换策略落盘 | Codex |
| 私有素材进入 Git | 隐私或版权风险 | 只读取用户目录，测试使用合成 JSON，不提交图集 | Codex |
| 鲸鱼各动画行身份漂移 | 内置宠物动作不连贯 | 基础图作为所有行的强制参考，逐行视觉 QA，失败只修复对应行 | Codex + 图像生成子代理 |
| SwiftPM 资源未进入 `.app` | 源码运行可见但正式包缺失 | SwiftPM 声明资源，同时在打包脚本复制内置 Pets 目录并检查产物 | Codex |

## 阶段地图

| 阶段 | 目的 | 子任务 | 进入条件 | 退出条件 | 状态 |
| --- | --- | --- | --- | --- | --- |
| S1 | 定义宠物包与动画契约 | ST-501 | 现有架构已确认 | 清单、图集和状态映射可测试 | 已完成 |
| S2 | 实现发现、导入与持久化 | ST-502 | S1 完成 | 有效宠物可列出、选择和恢复 | 已完成 |
| S3 | 实现原生动画覆盖层 | ST-503 | S2 完成 | 宠物可显示、切帧且不遮挡页面 | 已完成 |
| S4 | 增加设置入口与状态联动 | ST-504 | S3 完成 | 菜单/工具栏可配置，状态变化可观察 | 已完成 |
| S5 | 构建、测试与审核 | ST-505 | S2-S4 完成 | 自动检查、构建和审核通过 | 已完成 |
| S6 | 生成 DeepWhale 宠物包 | ST-506 | 8×9 契约已完成 | 图集、清单、联系表和预览全部通过 QA | 已完成 |
| S7 | 内置资源接入与可见性验证 | ST-507 | S6 完成 | 全新偏好环境可默认显示 DeepWhale | 已完成 |

## 验证策略

- `./scripts/run_checks.sh`
- `swift build`
- `./scripts/build_app.sh`
- `plutil -lint dist/DsHarness.app/Contents/Info.plist`
- 使用本机只读 `~/.codex/pets` 样本验证发现、选择、透明裁切和动画行。
- 人工检查宠物覆盖层只在宠物区域捕获点击，并验证“减少动态效果”。
- 检查 DeepWhale `final/validation.json`、`qa/review.json`、联系表和逐行动画预览。
- 用独立 Bundle ID 启动正式 `.app`，确认即使存在外部宠物也优先默认显示内置鲸鱼，并验证设置入口与来源标签。
