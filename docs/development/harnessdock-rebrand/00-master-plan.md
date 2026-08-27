# 总开发阶段文档：HarnessDock 全量品牌重命名

## 目标

把面向用户、开发者和发布渠道的项目名称从 DS Harness / DsHarness 统一为 HarnessDock，并保证应用构建、插件安装、双语文档、GitHub 分支与 Product Hunt 材料使用同一名称。

## 非目标

- 不改变 DeepSeek Harness、`dsh` CLI 和 `@deepseek-ai/dsh` 等上游官方名称。
- 不在本任务中完成 Developer ID 签名、Apple 公证、许可证选择或 Product Hunt 排期。
- 不重写已有 Git 历史，不删除旧远程分支。
- 不更改兼容性 Bundle Identifier `app.dsharness.desktop`、Application Support 目录和余额钥匙串服务名，避免现有 Chat 登录、本地设置和 Key 丢失。

## 当前证据

- `Package.swift` 使用 `DsHarness`、`DsHarnessApp`、`DsHarnessCore`、`DsHarnessCoreChecks` 和 `DsHarnessCoreTests`。
- `scripts/build_app.sh` 产出 `dist/DsHarness.app` 和 `DsHarness` 可执行文件。
- `Resources/Info.plist` 的显示名和可执行文件仍为旧名，Bundle Identifier 为 `app.dsharness.desktop`。
- 插件公开包名和浏览器模块 ID 为 `@dsharness/pet`，偏好键为 `dsharness.pet.preferences.v1`。
- README、CHANGELOG 和 Product Hunt 草稿仍引用 `nortonyang/DsHarness`。
- 当前 GitHub 长期分支为 `main`、`develop`、`release`，本地工作位于 `develop`。

## 假设

- 用户确认“第一个”即产品名 `HarnessDock`，大小写固定。
- GitHub 目标仓库为 `nortonyang/HarnessDock`；仓库改名后更新本地 `origin`。
- 插件改为 `@harnessdock/pet`，并从旧偏好键读取一次以迁移已有宠物设置。
- 本地检出目录可以继续名为 `DsHarness`，不影响远程仓库、构建和发布；当前线程内不移动工作区根目录。

## 风险

| 风险 | 影响 | 缓解方案 | 负责人 |
| --- | --- | --- | --- |
| 更换 Bundle Identifier | Chat Cookie、UserDefaults 和钥匙串被视为新应用数据 | 保留 `app.dsharness.desktop` 并在 README 说明为兼容性标识 | Codex |
| Swift Target 漏改 | 构建或测试失败 | 使用 `git mv` 重命名目录并运行完整检查、release 构建 | Codex |
| 插件包名变化 | 已安装旧插件不会自动升级 | 新包改名并在文档说明移除旧包后安装新包；偏好键自动迁移 | Codex |
| 文档/链接残留旧品牌 | GitHub、Product Hunt 或安装命令失效 | 双语 README、CHANGELOG、发布文案同步更新并运行全文残留扫描 | Codex |
| GitHub 仓库改名失败 | 远程 URL 与文档不一致 | 先提交推送旧仓库，再经登录会话改名并验证新 URL；失败则保留旧 URL 并报告 | Codex |

## 阶段地图

| 阶段 | 目的 | 子任务 | 进入条件 | 退出条件 | 状态 |
| --- | --- | --- | --- | --- | --- |
| S1 | 固化命名与兼容边界 | ST-801 | 用户确认名称 | 规划、用户故事与验证策略完整 | 已完成 |
| S2 | 重命名源码和产物 | ST-802, ST-803 | S1 完成 | Swift 包、App 和插件均使用 HarnessDock 且迁移兼容 | 未开始 |
| S3 | 同步发布材料 | ST-804 | S2 完成 | 中英文事实、链接、产物名和 Product Hunt 文案一致 | 未开始 |
| S4 | 审核与远程改名 | ST-805 | S2/S3 完成 | 测试、构建、审计、提交、推送与 GitHub 新 URL 验证通过 | 未开始 |

## 验证策略

- `./scripts/run_checks.sh`
- `swift build`
- `./scripts/build_app.sh`
- `plutil -lint dist/HarnessDock.app/Contents/Info.plist`
- `file` 与 `codesign --verify` 检查 HarnessDock 产物。
- `python3 scripts/release_readme_gate.py --base-ref origin/main --head-ref HEAD --version 0.1.0`
- 全仓扫描旧品牌；只允许兼容性 ID、历史说明和必要迁移常量保留 `dsharness`。
- 远程仓库改名后验证 `main`、`develop`、`release` 和新 `origin`。
