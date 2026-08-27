# 具体开发方案：macOS 桌面宠物插件

## 开发方案

| 步骤 | 工作内容 | 负责人 | 文件或区域 | 验证方式 | 状态 |
| --- | --- | --- | --- | --- | --- |
| 1 | 增加宠物清单、固定图集几何和动画时序模型 | Codex | `Sources/DsHarnessCore/PetPlugin.swift` | 核心检查、XCTest | 已完成 |
| 2 | 增加包发现、图片校验、导入和偏好持久化控制器 | Codex | `Sources/DsHarnessApp/PetPluginController.swift` | 构建、只读样本验证 | 已完成 |
| 3 | 增加图集帧裁切和宠物覆盖层 | Codex | `Sources/DsHarnessApp/PetPluginView.swift` | 构建、实机视觉检查 | 已完成 |
| 4 | 将插件接入主窗口、工具栏、菜单和设置 sheet | Codex | `ContentView.swift`、`DsHarnessApp.swift` | 构建、交互检查 | 已完成 |
| 5 | 更新 README、核心检查和单元测试 | Codex | `README.md`、`Sources/DsHarnessCoreChecks/main.swift`、`Tests` | 仓库验证命令 | 已完成 |
| 6 | 对照用户故事审核并更新完成度 | Codex | 本目录 `04-review-report.md` | diff 审核 | 已完成 |
| 7 | 用 hatch-pet/imagegen 生成并审核 DeepWhale 8×9 动画包 | Codex + 图像生成子代理 | `artifacts/pets/deepwhale-run` | 图集校验、联系表、逐帧检查 | 已完成 |
| 8 | 将 DeepWhale 作为 SwiftPM 与 `.app` 内置资源接入发现逻辑 | Codex | `Package.swift`、`PetPluginController.swift`、`scripts/build_app.sh`、资源目录 | 构建、产物检查、独立 UI QA | 已完成 |
| 9 | 更新入口说明并完成增量审核 | Codex | `README.md`、本目录文档 | 文档检查、实机验证 | 已完成 |
| 10 | 复核并安装 Marina Codex 包，切换 Chat 本机选择 | Codex | `artifacts/pets/marina-run/package`、`~/.codex/pets/marina`、UserDefaults | job status、QA、哈希、重启发现 | 已完成 |

## 完成度

| 项目 | 完成度 | 证据 | 备注 |
| --- | ---: | --- | --- |
| 需求与契约 | 100% | `00-master-plan.md`、`01-stages-and-stories.md` | 已确认原生覆盖层方案 |
| 宠物包运行时 | 100% | `PetPlugin.swift`、`PetPluginController.swift` | 自动发现、校验、导入和持久化已实现 |
| 动画与设置 UI | 100% | `PetPluginView.swift`、独立 QA 窗口验证 | 宠物、工具栏和设置页已实机显示 |
| 验证与审核 | 100% | 核心检查、Release 构建、签名验证、`04-review-report.md` | `swift test` 的仓库既有环境限制已记录 |
| 内置 DeepWhale | 100% | `Sources/DsHarnessApp/Resources/Pets/DeepWhale`、`artifacts/pets/deepwhale-run/qa`、独立 Bundle ID UI QA | 预览视频因本机无 `ffmpeg` 跳过；逐帧、联系表与图集校验通过 |
| Marina Codex 宠物 | 100% | 10 个任务完成、QA 通过、源/安装包哈希一致、Chat 实机显示 Marina | 已安装到 `~/.codex/pets/marina` 并选中 |

## 要修复的问题

| 问题 | 严重级别 | 关联用户故事 | 修复方案 | 状态 |
| --- | --- | --- | --- | --- |
| 当前应用无法加载或显示宠物包 | P2 | US-501 至 US-507 | 新增原生宠物插件运行时与 UI | 已修复 |
| 外部图集可能损坏或尺寸不兼容 | P2 | US-502、US-503 | 加载与导入时校验固定像素尺寸 | 已修复 |
| 全屏 WebView 缺少安全的非侵入覆盖机制 | P2 | US-505 | 根 ZStack 只在宠物边界启用命中 | 已修复 |
| 新安装没有外部宠物时功能不可见 | P2 | US-510 | 内置 DeepWhale 并优先作为无历史选择时的默认宠物 | 已修复 |
| 孵化器新版清单字段无法被旧解码器识别 | P2 | US-501、US-510 | 同时兼容 `name`/`spritesheet` 与 `displayName`/`spritesheetPath` | 已修复 |
| 用户误以为它是 Harness 网页插件 | P3 | US-511 | 在 README 和交付说明中明确原生入口与重启方式 | 已修复 |
| Chat 当前选中内置 DeepWhale，与 Harness 页 Marina 不一致 | P2 | US-512 | 安装 Marina 到 Codex 宠物目录并把 Chat 本机偏好切换到 `codex:marina` | 已修复 |

## 具体案例

| 案例 | 输入或上下文 | 期望行为 | 验证方式 |
| --- | --- | --- | --- |
| 自动发现 | `~/.codex/pets` 存在合法包 | 列表显示包且不复制、不修改源文件 | 实机与日志检查 |
| 最小清单 | 只有 id、name、spritesheet | 使用固定默认几何成功加载 | 单元测试 |
| 孵化清单 | 只有 id、displayName、spritesheetPath | 别名字段成功解码并使用固定默认几何 | 核心检查、单元测试 |
| 错误图集 | 宽高不是 1536×1872 | 包不进入列表并显示错误 | 控制器检查 |
| 启动状态 | Harness 正在 locating/launching | 宠物播放 running | 实机检查 |
| 页面错误 | WebView 有加载错误 | 宠物播放 failed | 状态映射审核 |
| 减少动态 | macOS 开启减少动态效果 | 每个状态固定第一帧 | 实机检查 |
| 全新安装 | 独立 Bundle ID、无外部宠物与无偏好 | 主窗口默认显示 DeepWhale | 独立应用 QA |
| 旧版仍运行 | 已打开旧 DsHarness 进程 | 退出旧进程并重新打开 `dist/DsHarness.app` 后看到新入口 | 实机检查 |
| Chat 与 Harness 角色同步 | Harness 已选择 Marina，Chat 当前为 DeepWhale | 安装 Codex Marina 并只切换 Chat 原生选择；两套运行时保持隔离 | 包哈希、偏好与重启检查 |

## 兼容与回滚策略

- 新功能随应用内置 DeepWhale；用户仍可关闭插件或选择外部宠物。
- 设置存储使用独立 UserDefaults 键，不迁移或覆盖现有工作区、余额、主题设置。
- 删除新增控制器、视图和接入点即可完整回滚；不需要数据迁移。
- 导入目录与源 Codex 宠物目录分离，回滚不会删除用户原有宠物。

## Gemini 开发交接

本任务由用户直接要求当前 Codex 开发，因此当前执行方为 Codex；保留 `03-gemini-handoff.md` 作为可复用的实现交接稿，不声称已委派。

## Codex 5.5 审核清单

- 实现是否严格匹配 US-501 至 US-508。
- 是否没有复制用户私有素材进仓库，内置图集是否有独立生成与 QA 证据。
- 覆盖层是否只在宠物区域捕获事件。
- 清单路径、图集尺寸、导入目标是否经过校验。
- 构建与核心检查是否有真实命令证据。
