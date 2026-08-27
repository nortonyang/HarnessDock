# Gemini 代码开发交接：HarnessDock 全量品牌重命名

你将根据已经批准的敏捷规划文档实现代码。

事实来源：

- `docs/development/harnessdock-rebrand/00-master-plan.md`
- `docs/development/harnessdock-rebrand/01-stages-and-stories.md`
- `docs/development/harnessdock-rebrand/02-implementation-plan.md`

实现范围：

- AT-802 至 AT-805：Swift/App、构建产物、插件命名与迁移、双语发布材料。

约束：

- 不修改 `app.dsharness.desktop`、对应 Application Support 路径和 Keychain 服务。
- 不把官方 DeepSeek Harness / `dsh` 上游名称替换成 HarnessDock。
- 插件从旧 storage key 迁移偏好，不执行破坏性清理。
- 不创建签名、公证或正式发行声明。
- 不修改无关功能，不重写 Git 历史。

验收标准：

- `swift run HarnessDock` 与 `./scripts/build_app.sh` 使用新名称。
- 产物为 `dist/HarnessDock.app`，显示名和可执行文件均为 HarnessDock。
- 插件名为 `@harnessdock/pet`，旧偏好自动迁移。
- 中英文 README、CHANGELOG 和 Product Hunt 文案统一为 HarnessDock。
- 所有检查、构建、发布门禁和残留扫描通过。

预期改动区域：

- `Package.swift`、`Sources/`、`Tests/`、`Resources/`
- `scripts/`、`plugins/dsh-pet/`
- `README.md`、`README.zh-CN.md`、`CHANGELOG.md`、`docs/`

需要运行的验证：

- `./scripts/run_checks.sh`
- `swift build`
- `./scripts/build_app.sh`
- `python3 scripts/release_readme_gate.py --base-ref origin/main --head-ref HEAD --version 0.1.0`
- 旧品牌残留扫描。

返回内容：

- 变更文件列表、实现摘要、验证结果、阻塞点和偏离计划的地方。
