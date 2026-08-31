# HarnessDock 宠物插件 Profile 迁移：紧凑开发方案

## 总开发阶段

### 目标

修复 HarnessDock 改名后，已有 `web` profile 仍引用 `@dsharness/pet` 与已不存在的 `/Applications/DsHarness.app`，导致官方 DSH 在加载 profile bundle 时退出的问题。应用启动受管 Harness 前应识别这一精确旧配置，使用官方 `dsh plugin` 流程迁移到当前 App 内嵌的 `@harnessdock/pet`；如果 App 后续移动，还应只校正指向 App 内嵌资源的 link，然后再启动 Harness。

### 非目标

- 不修改用户的其他 DSH profile、插件、patch 或模型配置。
- 不覆盖用户自行从 npm、Git 或其他目录安装的 `@harnessdock/pet`。
- 不在附着外部 Harness 服务时改写其 profile。
- 不直接手工拼写 `pnpm-lock.yaml` 或 `node_modules`。

### 当前证据

- 启动错误明确为无法解析 `@dsharness/pet`。
- `~/.dsh/profiles/web/package.json` 的 dependency 和 bundle 列表仍包含 `@dsharness/pet`，链接目标为已不存在的 `/Applications/DsHarness.app/Contents/Resources/Plugins/dsh-pet`。
- 当前构建内嵌 `@harnessdock/pet`：`dist/HarnessDock.app/Contents/Resources/Plugins/harnessdock-pet`。
- 官方 `dsh plugin --profile web` 是 pnpm 转发器，并在成功后自动协调 dependency 与 bundle 列表。

### 风险

| 风险 | 影响 | 缓解方案 |
| --- | --- | --- |
| 误改用户自定义插件 | 丢失用户配置 | 仅当 manifest 精确包含旧包名时迁移；其他依赖与 bundles 交给官方命令保留 |
| 先删除旧插件、再安装失败 | 宠物消失或 profile 状态更差 | 先添加当前内嵌插件，成功后再删除旧包 |
| Finder PATH 找不到 pnpm | 官方插件命令失败 | 使用现有 `ExecutableLocator` 定位 pnpm，并显式加入迁移子进程 PATH |
| App 移动后 link 失效 | 下次启动再次失败 | 迁移目标使用当前 `Bundle.main` 内嵌插件绝对路径；只校正含 `Contents/Resources/Plugins/harnessdock-pet` 的 App 自有 link |
| 迁移失败阻止 Harness | 用户仍无法工作 | 记录不含敏感信息的明确错误；不启动已知损坏的 profile，避免重复 Node 堆栈 |

### 阶段地图

| 阶段 | 子任务 | 退出条件 | 状态 |
| --- | --- | --- | --- |
| S1 证据与边界 | ST-1001 检查旧 profile；ST-1002 确认官方迁移命令 | 根因与安全范围明确 | 已完成 |
| S2 实现 | ST-1003 精确检测；ST-1004 启动前迁移 | 旧包先 add 新包、再 remove 旧包 | 已完成 |
| S3 验证与发布 | ST-1005 fixtures；ST-1006 本机启动与构建 | Harness 3080 就绪，检查和文档通过 | 已完成 |

## 原子任务与用户故事

### AT-1001：识别旧宠物插件 Profile

用户故事：作为从 DS Harness 升级到 HarnessDock 的用户，我希望应用识别旧宠物插件引用，以便升级后 Harness 不会因失效 bundle 无法启动。

验收标准：

- Given `web/package.json` dependency 或 bundle 精确包含 `@dsharness/pet`，When 检查迁移，Then 返回需要迁移。
- Given profile 不存在、JSON 无效或不包含旧包，When 检查迁移，Then 不改写文件。
- Given 用户已安装其他来源的 `@harnessdock/pet` 且无旧包，When 启动，Then 不覆盖该安装。
- Given `@harnessdock/pet` 指向旧 App 内嵌资源路径，When HarnessDock 从新位置启动，Then 通过官方 add 命令把 link 更新为当前 Bundle 路径。

### AT-1002：通过官方插件命令迁移

用户故事：作为已有宠物用户，我希望应用自动把旧包替换为当前 App 内嵌包，以便保留宠物功能并恢复 Harness 启动。

验收标准：

- Given 检测到旧包且当前 App 内嵌插件完整，When 启动受管 Harness，Then 先运行 `dsh plugin --profile web add <current-bundle>`，成功后运行 `remove @dsharness/pet`。
- Given 新包添加失败，When 迁移结束，Then 不执行旧包删除，并显示可操作错误。
- Given 迁移成功，When 启动 Harness，Then `web` profile bundles 只包含 `@harnessdock/pet`，3080 服务可访问。

## 具体开发方案

| 步骤 | 工作内容 | 文件或区域 | 验证方式 | 状态 |
| --- | --- | --- | --- | --- |
| 1 | 新增 profile manifest 旧包检测器 | `HarnessDockCore` | Core fixture | 已完成 |
| 2 | 新增官方 dsh plugin 命令迁移流程 | `AppModel.launchOrAttach` | 隔离 profile、静态契约 | 已完成 |
| 3 | 修复本机旧 profile 并验证启动 | `~/.dsh/profiles/web` | profile 引用、3080 HTTP | 已完成 |
| 4 | 更新中英文说明、构建与审核 | README、CHANGELOG、本文件 | checks、release build、diff review | 已完成 |

## Gemini 开发交接

按本文件 AT-1001/AT-1002 实施最小改动。不得改写其他 profile 或直接编辑 lockfile；只使用官方 `dsh plugin` 命令协调依赖。当前环境未提供 Gemini 执行通道，用户已要求 Codex 继续修复，因此由 Codex 按同一边界直接实现并审核。

## Codex 5.5 审核报告

### 审核范围

- `HarnessPetProfileMigration` 的精确包名检测与 `DSH_HOME` 路径解析。
- `AppModel.launchOrAttach` 的迁移时机、官方命令顺序、失败处理与最终状态验证。
- Finder 下 `pnpm` 定位、Core checks、静态契约、本机 profile 和隔离 profile 实测。

### 问题发现

| 严重级别 | 问题 | 结果 |
| --- | --- | --- |
| P1 | 旧 `@dsharness/pet` bundle 链接到已不存在的 DS Harness.app，DSH 启动阶段退出 | 已修复 |
| P2 | Finder 最小 PATH 无法找到用户安装在 `~/.npm-global/bin` 的 pnpm | 已修复 |
| P2 | 项目改名审核只迁移了浏览器偏好键，没有迁移 DSH profile 依赖 | 已由本方案补齐 |

### 验收标准检查

| 用户故事 | 结果 | 证据 |
| --- | --- | --- |
| AT-1001 精确识别旧 profile | 通过 | legacy/current JSON fixtures 与 Core checks 通过；无旧包时不运行迁移 |
| AT-1002 官方命令迁移 | 通过 | 静态检查确认 add 在 remove 之前且 AppModel 不直接写 profile；隔离 `DSH_HOME` 实测成功 |
| AT-1002 恢复真实启动 | 通过 | 真实 profile 旧引用消失、新引用存在，`http://127.0.0.1:3080` 返回 200 |
| AT-1002 App 移动后修复内嵌 link | 通过 | 隔离 profile 的旧 App 路径被更新为当前 Bundle 路径，临时 3095 服务返回 HTTP 200 |

### 验证结果

- `./scripts/run_checks.sh`：通过，包含插件、Chat Enter、环境凭据、profile 迁移、本地化和 Core checks。
- `./scripts/build_app.sh`：通过，生成并 ad-hoc 签名 `dist/HarnessDock.app`。
- `swift test`：本机 Command Line Tools 的 macOS 15 SDK 不含现有测试套件依赖的 `Testing` 模块，未进入测试执行；本次新增场景已同时纳入可运行的 `HarnessDockCoreChecks` 并通过。
- 真实 profile：官方 `dsh plugin add` 后 `remove @dsharness/pet` 成功；package 与 lockfile 只剩 `@harnessdock/pet`。
- 隔离自动迁移：临时 `DSH_HOME` 仅含旧包；新版 App 在 3095 自动迁移并返回 HTTP 200，临时进程和目录已删除。
- 隔离路径漂移：临时 `DSH_HOME` 使用指向旧 App 的 `@harnessdock/pet` link；新版 App 自动重连到当前 Bundle，3095 返回 HTTP 200，临时进程和目录已删除。
- 源码契约：迁移只由精确旧状态或 App 自有 link 路径漂移触发，使用官方命令，旧包迁移时先 add 后 remove，完成后验证 current dependency/bundle 与当前 Bundle 路径。

### 完成度更新

| 项目 | 更新前 | 更新后 | 证据 |
| --- | ---: | ---: | --- |
| 旧 profile 检测 | 0% | 100% | Core 类型、fixtures、checks |
| 自动迁移 | 0% | 100% | AppModel、隔离 DSH_HOME 实测 |
| 本机恢复 | 0% | 100% | 3080 HTTP 200、新旧引用检查 |

### 剩余工作

- 无计划内剩余工作。若用户附着的是外部已运行 Harness，应用仍不会改写该外部进程的 profile，这是既定边界。
