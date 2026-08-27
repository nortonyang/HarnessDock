# Gemini 代码开发交接：macOS 桌面宠物插件

你将根据已经批准的敏捷规划文档实现代码。

事实来源：

- `docs/development/macos-pet-plugin/00-master-plan.md`
- `docs/development/macos-pet-plugin/01-stages-and-stories.md`
- `docs/development/macos-pet-plugin/02-implementation-plan.md`

实现范围：

- US-501 至 US-508。
- 增加 Codex 兼容宠物清单和 8×9 动画契约。
- 增加 `~/.codex/pets` 与 DsHarness Application Support 宠物的发现、校验、选择、导入和偏好持久化。
- 增加 SwiftUI 宠物动画覆盖层、运行状态映射、减少动态效果支持。
- 增加菜单、快捷键、工具栏和设置 sheet。
- 更新核心检查、单元测试和 README。

约束：

- 不修改无关文件，不重构 Harness 进程管理或 WebView 注入代码。
- 不提交本机 `~/.codex/pets` 的宠物素材。
- 不加载宠物包中的可执行代码；只读取 JSON 和图集。
- 清单中的图集路径必须限制在包目录内。
- 图集必须是 1536×1872；默认单格 192×208、8 列、9 行。
- 覆盖层不得阻塞宠物范围以外的 WebView 交互。

验收标准：

- 合法最小清单可解码，路径逃逸和错误几何被拒绝。
- 合法包自动发现并可选择；合法外部包可导入并在重启后恢复。
- idle、running、failed 等状态使用正确行和帧时序。
- 减少动态效果时固定第一帧。
- 菜单、`⇧⌘P`、工具栏均可进入设置。
- 核心检查和 Swift 构建通过。

预期改动区域：

- `Sources/DsHarnessCore/PetPlugin.swift`
- `Sources/DsHarnessApp/PetPluginController.swift`
- `Sources/DsHarnessApp/PetPluginView.swift`
- `Sources/DsHarnessApp/ContentView.swift`
- `Sources/DsHarnessApp/DsHarnessApp.swift`
- `Sources/DsHarnessCoreChecks/main.swift`
- `Tests/DsHarnessCoreTests/PetPluginTests.swift`
- `README.md`

需要运行的验证：

- `./scripts/run_checks.sh`
- `swift build`
- `./scripts/build_app.sh`
- `plutil -lint dist/DsHarness.app/Contents/Info.plist`

返回内容：

- 变更文件列表。
- 实现摘要。
- 验证命令和结果。
- 阻塞点或偏离计划的地方。

## DeepWhale 增量交接

新增事实来源：同目录 `00-master-plan.md` 至 `02-implementation-plan.md` 中的 S6、S7、US-509 至 US-511。

增量范围：

- 不自行绘制宠物资产；使用 hatch-pet 规范产出的 `pet.json` 与 `spritesheet.webp`。
- 增加内置宠物来源，扫描应用资源中的 Pets 目录。
- SwiftPM 源码运行和 `scripts/build_app.sh` 生成的 `.app` 都必须携带相同资源。
- 无有效历史选择时默认 DeepWhale，已有用户选择时保持不变。
- README 说明插件名“桌面宠物插件”、爪印入口、`⇧⌘P` 和退出旧进程后打开新构建的方法。

增量验证：

- 宠物图集与 QA JSON 验证。
- `./scripts/run_checks.sh`、`./scripts/build_app.sh`、签名与 Info.plist 检查。
- 独立 Bundle ID、空偏好 UI QA。

## Marina Codex 宠物增量交接

- 复用 `artifacts/pets/marina-run/package`，不得重新绘制、镜像、编辑或伪造已完成的图像任务。
- 安装时必须同时复制 `pet.json` 与 `spritesheet.webp`，并验证源/目标 SHA-256 一致。
- DsHarness Chat 选择设为 `codex:marina`；不得修改 Harness Web 插件的 localStorage 选择或内置 DeepWhale 资源。
- 重启后验证 Codex 包可发现、Chat 宠物启用和本机偏好持久化。
