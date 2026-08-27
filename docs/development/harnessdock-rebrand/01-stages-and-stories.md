# 阶段与用户故事：HarnessDock 全量品牌重命名

## 阶段目的

把重命名拆成可独立验证的原子任务，防止只改界面标题而遗漏构建、插件、持久化或发布链接。

## 依赖

- 用户已确认产品名为 `HarnessDock`。
- `develop` 当前为最新集成分支，`release` 与其同源。
- Bundle Identifier 和旧数据目录必须保留以兼容现有本地状态。

## 子任务

| 子任务 | 交付结果 | 原子任务 | 用户故事 | 状态 |
| --- | --- | --- | --- | --- |
| ST-801 | 命名和兼容边界 | AT-801 | US-801 | 已完成 |
| ST-802 | Swift/App 构建重命名 | AT-802, AT-803 | US-802, US-803 | 未开始 |
| ST-803 | 插件命名与偏好迁移 | AT-804 | US-804 | 未开始 |
| ST-804 | 双语文档与发布渠道同步 | AT-805 | US-805 | 未开始 |
| ST-805 | 构建审核与 GitHub 改名 | AT-806 | US-806 | 未开始 |

## 原子任务与原子用户故事

### AT-801：确认最终命名矩阵

用户故事：作为项目维护者，我希望所有公开名称都有唯一映射，以便后续发布不出现多个品牌。

验收标准：公开产品名、App 名、Swift 包、插件包、GitHub 仓库和 Product Hunt 名称均明确为 HarnessDock；兼容性 ID 单独列出。

### AT-802：重命名 Swift Package 与源码目录

用户故事：作为开发者，我希望 `swift run HarnessDock` 和相关测试 Target 使用新名称，以便源码与产品品牌一致。

验收标准：`Package.swift`、Imports、Sources、Tests 和核心检查均使用 HarnessDock 命名；`swift build` 与核心检查通过。

### AT-803：重命名 macOS App 产物

用户故事：作为用户，我希望 Finder、菜单栏和构建产物只显示 HarnessDock，以便明确自己打开的是新品牌应用。

验收标准：构建输出为 `dist/HarnessDock.app`，可执行文件为 `HarnessDock`，Info.plist 显示名为 HarnessDock；Bundle Identifier 仍为兼容性值。

### AT-804：迁移 Harness 宠物插件

用户故事：作为已有宠物用户，我希望插件改名为 `@harnessdock/pet` 后仍保留偏好，以便重命名不重置宠物设置。

验收标准：插件清单、ModuleLoader ID、样式标识和检查器使用新命名空间；首次读取新键为空时迁移旧 `dsharness.pet.preferences.v1`。

### AT-805：同步双语发布事实

用户故事：作为 GitHub 或 Product Hunt 访客，我希望安装命令、下载名、项目链接和产品文案都指向 HarnessDock，以便不会进入旧地址或使用旧命令。

验收标准：README 中英文、CHANGELOG、发布审核、插件 README 和 Product Hunt 草稿事实一致；发布文档门禁通过。

### AT-806：验证并执行 GitHub 仓库改名

用户故事：作为维护者，我希望 `main/develop/release` 在 `nortonyang/HarnessDock` 下完整保留，以便不丢失发布治理结构。

验收标准：代码提交并推送；远程仓库改名成功；本地 `origin` 指向新 URL；三条长期分支可只读验证。

## 阶段验收标准

- 所有运行时、构建和文档验收命令通过。
- 旧名只存在于兼容性常量、迁移逻辑、重命名历史说明或旧提交中。
- 不产生未经验证的签名、公证或正式发行声明。

## 完成定义

- 审核报告记录变更、残留项、构建证据、GitHub 外部变更和 Product Hunt 未完成阻塞。
