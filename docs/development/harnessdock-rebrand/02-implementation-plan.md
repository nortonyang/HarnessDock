# 具体开发方案：HarnessDock 全量品牌重命名

## 开发方案

| 步骤 | 工作内容 | 负责人 | 文件或区域 | 验证方式 | 状态 |
| --- | --- | --- | --- | --- | --- |
| 1 | 建立命名矩阵与兼容边界 | Codex | 本目录规划文档 | 文档审核 | 已完成 |
| 2 | `git mv` Swift Sources/Tests 并更新 Package/Imports | Codex | `Package.swift`、`Sources/`、`Tests/` | release build、core checks | 已完成 |
| 3 | 重命名 App 类型、Info.plist、构建产物和脚本 | Codex | App、Resources、scripts | release 构建、plist、file、codesign | 已完成 |
| 4 | 改名插件并迁移旧偏好键 | Codex | `plugins/harnessdock-pet` | `npm ... run check`、pack dry-run | 已完成 |
| 5 | 同步本地化、README、CHANGELOG 和 Product Hunt | Codex | Resources、README、docs | 双语审核、残留/隐私扫描 | 已完成 |
| 6 | 审核、提交、推送并改名 GitHub 仓库 | Codex | Git/GitHub | 远程 refs 与 URL 验证 | 进行中 |

## 完成度

| 项目 | 完成度 | 证据 | 备注 |
| --- | ---: | --- | --- |
| 规划与命名矩阵 | 100% | 00/01/02 文档 | 保留兼容性 Bundle ID |
| Swift/App 重命名 | 100% | `HarnessDock.app`、plist、codesign、core checks | 保留兼容 Bundle ID |
| 插件迁移 | 100% | `@harnessdock/pet checks passed`、6 文件内嵌、npm pack dry-run | 旧偏好键迁移通过 |
| 发布材料同步 | 100% | 双语 README、CHANGELOG、Product Hunt 文案与候选校验和 | 脱敏图库仍属发布阻塞项 |
| GitHub 远程改名 | 0% | 暂无 | 待外部变更 |

## 要修复的问题

| 问题 | 严重级别 | 关联用户故事 | 修复方案 | 状态 |
| --- | --- | --- | --- | --- |
| 产品与源码仍使用旧品牌 | P1 | US-801, US-802 | 全量命名矩阵替换并构建验证 | 已修复 |
| 更换 Bundle ID 会丢失登录和设置 | P1 | US-803 | 保留兼容性 Identifier、目录和 Keychain 服务 | 方案已确定 |
| 插件改名可能丢失偏好 | P2 | US-804 | 新键优先、旧键读取迁移 | 已修复并测试 |
| README 截图仍显示旧品牌 | P2 | US-805 | 移除旧截图并在发布前补脱敏图库 | 当前树已修复；新图库待补 |
| GitHub CLI 登录状态可能不可用 | P2 | US-806 | 优先使用已登录浏览器；失败则报告，不索取 Token | 外部改名待执行 |

## 具体案例

| 案例 | 输入或上下文 | 期望行为 | 验证方式 |
| --- | --- | --- | --- |
| 本地源码运行 | `swift run HarnessDock` | 启动 HarnessDock | 构建/启动检查 |
| 本地 App 构建 | `./scripts/build_app.sh` | 生成 `dist/HarnessDock.app` | 文件与 plist 检查 |
| 已有 Chat 登录 | 旧 Bundle ID 数据存在 | 改名后仍使用同一 WebKit 数据容器 | 保留 ID 的静态审核与实机检查 |
| 已有插件偏好 | 仅旧 storage key 有值 | 新插件加载后迁移并沿用偏好 | Node 插件检查 |
| GitHub 访问 | 打开新仓库 URL | 三条长期分支可见 | 远程只读验证 |

## Gemini 开发交接

见 `03-gemini-handoff.md`。当前用户已直接要求 Codex 完成重命名，因此由 Codex 按同一边界实施，不调用额外开发代理。

## Codex 5.5 审核清单

- 新名称是否覆盖应用、源码、插件、文档和远程仓库。
- 兼容性 Bundle ID、Application Support 与 Keychain 是否未被误改。
- 插件旧偏好是否有一次性迁移和测试。
- 双语 README 是否事实一致并通过门禁。
- 构建产物、架构、版本和签名状态是否重新验证。
- GitHub 外部变更是否与事先展示的目标一致。
