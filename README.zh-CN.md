# HarnessDock for macOS

[English](README.md) · [简体中文](README.zh-CN.md)

![Platform](https://img.shields.io/badge/platform-macOS%2014%2B-black?logo=apple)
![Swift](https://img.shields.io/badge/Swift-6.0-F05138?logo=swift&logoColor=white)
![Version](https://img.shields.io/badge/version-0.1.0-6D5DFC)
![Status](https://img.shields.io/badge/status-developer%20preview-7C3AED)

**面向 DeepSeek Harness 的原生 macOS 工作空间：支持本地项目启动、API 余额与高峰/谷时价格、内嵌 DeepSeek Chat、自定义主题背景和动态宠物。**

HarnessDock 使用 SwiftUI 与 WebKit，将官方 [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness) Web UI 包装为桌面体验。选择本地项目后，应用会启动锁定版本的 Harness 运行时，无需手动管理终端命令或浏览器标签页。

> [!WARNING]
> HarnessDock 是独立的非官方项目，与 DeepSeek 没有隶属或背书关系。DeepSeek Harness 仍处于开发者预览阶段，上游更新可能需要兼容性调整。

## 界面截图（Screenshots）

![已隐藏私人工作区信息的 HarnessDock 主界面预览](docs/screenshots/sanitized/harnessdock-overview-redacted.png)

该预览已遮盖工作区、模式、模型、输入内容和余额信息。正式发布到 Product Hunt 前会继续补充一组经过脱敏的产品截图。

## 产品概览（Overview）

HarnessDock 面向希望在 macOS 上自然使用官方 Harness 工作流的开发者。原生外壳负责项目选择、运行时启动、错误恢复、日志、快捷键、本地设置和界面呈现；会话、工具、审批与插件仍由官方 Harness UI 提供。

## 本次预览更新

最新开发版让动态宠物在两个工作页面中都能感知任务状态：

- 在 **Harness** 中，插件跟随官方当前会话和后台任务状态。
- 在 **Chat** 中，原生宠物会响应 DeepSeek 开始生成、成功结束或出现新错误。
- 成功和失败反馈都会从第 1 帧开始，完整播放一轮后再回到待机。
- Chat 桥只向原生 Swift 代码发送 `idle`、`running`、`succeeded`、`failed`，不会读取或转发提示词、回复与网页正文。

这些状态切换由 Harness 插件检查、Core 检查，以及 `scripts/check-chat-pet-command.mjs` 中面向隐私的 WebKit 桥模拟共同覆盖。

## 功能（Features）

- **原生 macOS 外壳**：基于 SwiftUI 与 WebKit，不是 Electron。
- **一键进入本地工作区**：所选项目目录会作为 Harness 的工作目录。
- **锁定官方运行时**：使用已验证的 `@deepseek-ai/dsh@0.1.0-rc.6`，存在完全匹配的 npm 缓存时优先复用。
- **Harness / Chat 双入口**：两个页面独立保留页面状态和登录会话。
- **DeepSeek API 余额**：凭据存入 macOS 钥匙串，支持刷新、紧凑态和侧栏折叠态。
- **高峰 / 谷时与人民币价格**：突出当前时段、对应模型单价，以及本地可读取的输入/输出 token 用量。
- **自定义主题背景**：导入本地图片并调整内容遮罩，文件只保存在当前 Mac。
- **中英文原生界面**：支持跟随系统、简体中文和 English。
- **版本与诊断**：显示应用版本、锁定的 Harness 运行时、macOS 架构、服务状态和本机 Node/npx/dsh 可用性，并可复制隐私安全的诊断摘要。
- **设置新手引导**：讲解预设、权限、外观、发送行为、模型和插件。
- **双页面任务感知宠物**：`@harnessdock/pet` 插件跟随 Harness 会话与后台任务，Chat 原生宠物也会响应回答生成、成功和失败。
- **可靠的进程管理**：安全复用经过校验的已有 Harness 服务，并清理由本应用启动的进程。

## HarnessDock 不会做什么

- 不替代或重新实现 DeepSeek Harness。
- 不绕过 DeepSeek Chat 登录；Chat 页打开的是官方网页，使用正常的账号会话。
- 不会把仅存于钥匙串的余额凭据复制给 Harness，也不会把凭据内容注入网页。
- 目前不提供已签名、已公证并支持自动更新的公众安装包。

## 系统要求（Requirements）

| 依赖 | 要求 |
| --- | --- |
| macOS | 14 Sonoma 或更高版本 |
| Mac | 源码构建支持 Apple Silicon 或 Intel；当前本机构建产物为 arm64 |
| Node.js | 推荐 24+；Node 22 至少需要 22.19 |
| Swift | 源码构建需要 6.0+ |
| 网络 | 本地没有锁定版本的 Harness 缓存时，首次运行需要联网 |

先确认 Node.js 与 `npx` 可用：

```bash
node --version
npx --version
```

## 安装（Installation）

当前仓库提供源码构建，尚未发布经过 Developer ID 签名与 Apple 公证的安装包。

```bash
git clone https://github.com/nortonyang/HarnessDock.git
cd HarnessDock
./scripts/build_app.sh
open dist/HarnessDock.app
```

构建脚本会生成 `dist/HarnessDock.app`，嵌入宠物插件的 6 个发布文件，并为本地测试执行 ad-hoc 签名。不要把这个本机构建产物当成受信任的公众安装包分发。

## 使用方法（Usage）

1. 打开 HarnessDock。存在上次使用的工作区时，点击 **进入** 即可恢复；否则选择一个本地项目目录。
2. 等待状态变为 **本地**，Harness 默认启动在 `127.0.0.1:3080`。
3. HarnessDock 会先使用自身启动环境中的 `DEEPSEEK_API_KEY`；如果从 Finder 或 Dock 启动导致变量缺失，则只从用户的交互式登录 Shell 读取这一项导出变量。由它管理的 Harness 随后使用官方环境认证；两个来源都没有配置时，才需要在 **Harness → 设置 → 模型** 中填写凭据。
4. 同一个环境凭据也可以用于原生余额显示。如果没有自动识别，打开 **HarnessDock → 设置 → API 与余额**，把单独的 DeepSeek API Key 存入钥匙串。
5. 在官方 Harness 界面中开始任务，或切换到 **Chat** 使用 DeepSeek 官方网页聊天。
6. 如需在 Chat 显示原生宠物，点击右上角工具栏的爪印按钮，开启 **在 Chat 页面显示原生宠物**。Harness 宠物仍在 **Harness → 设置 → 插件 → 桌面宠物** 中管理。

首次进入 Harness 设置页时会显示 6 步引导，只解释各项设置，不会替你修改配置。以后可点击设置页顶部的 **新手引导** 再次查看。

### Harness 与 Chat

Harness 提供项目感知的智能体工作流、工具、审批、会话和插件。Chat 内嵌 `chat.deepseek.com`，因为它是官方免费聊天服务而不是 API Key 聊天客户端，所以仍需正常登录 DeepSeek 账号。登录 Cookie 由本机 WebKit 保存。

Chat 中，中文输入法确认不会发送草稿；带修饰键的 Enter 会在支持多行的输入区换行；空白草稿不会产生消息。只有用户主动选择文件后才会上传，并直接交给 DeepSeek 官方服务处理。

## 数据与隐私（Privacy）

- HarnessDock 启动环境中的 `DEEPSEEK_API_KEY`，或父环境缺失时从用户交互式登录 Shell 解析的同名导出变量，会由其管理的 Harness 子进程继承，用于官方环境认证，也可用于原生余额查询。
- HarnessDock 不会导入 Shell 的完整环境；回退解析出的值只保留在内存中，不会因此落盘。
- 只保存在 macOS 钥匙串中的余额凭据仍仅供原生余额查询，不会复制给 Harness。
- 凭据内容不会写入项目、配置文件、Harness 日志或 WebView 脚本。
- 查询余额时只向 `https://api.deepseek.com/user/balance` 发起只读请求。
- 环境凭据和钥匙串凭据都不会被注入 Harness 或 Chat 网页。
- 背景图片副本只保存在当前 Mac 的 Application Support 目录。
- 导入的宠物包仅作为 JSON 和图片资源读取，不执行其中的代码。
- Chat 宠物桥只接受 `idle`、`running`、`succeeded`、`failed` 四种状态，不读取或传输提示词、回复或网页正文。
- 当前预览版不包含数据分析或崩溃上报。
- 复制的诊断摘要不包含 API Key、Cookie、聊天内容、完整日志和完整工作区路径；用户目录下的工具路径会缩写为 `~`。

模型价格以人民币/百万 tokens 显示，并以 DeepSeek [中文官方价格页](https://api-docs.deepseek.com/zh-cn/quick_start/pricing/) 为参考。价格可能调整，最终以官方页面与账户账单为准。Token 统计来自 Harness 本地可读取的会话数据，不代表完整的账号累计用量。

## 外观与语言

打开 **设置 → 主题背景** 或按 `⇧⌘T`，可以导入、更换、移除背景图片并调整内容遮罩。原生应用语言可设为 **跟随系统**、**简体中文** 或 **English**。Harness 与 Chat 网页继续使用各自的语言设置，切换原生语言时不会重载网页或退出登录。

## 桌面宠物

Harness 插件位于 `plugins/harnessdock-pet`，本地包名为 `@harnessdock/pet`，入口 ID 为 `pet`。

```bash
npm --prefix plugins/harnessdock-pet run build
npm --prefix plugins/harnessdock-pet run check
dsh plugin --profile web add ./plugins/harnessdock-pet
```

安装后重启 Harness，在 **设置 → 插件 → 桌面宠物** 中选择 DeepWhale 或 Marina、隐藏宠物或更改停靠位置。

从旧 DS Harness 升级时，HarnessDock 会在启动受管 Harness 前精确检测旧 `@dsharness/pet` 条目，并通过官方 `dsh plugin` 流程先添加内嵌的 `@harnessdock/pet`，再移除失效的旧链接。以后移动 App 时，只会把指向 App 内嵌插件的自有 link 更新到当前位置；其他 profile 和自定义插件来源不会被修改。

Harness 宠物会跟随官方会话状态：当前任务或后台任务运行时持续执行动作，结束后播放一次成功或失败动画，再回到待机状态。它只观察状态，不读取、保存或传输提示词、回复正文、命令参数与工具输出。悬停和点击会触发角色动作；可从非控件区域直接拖动，若起点位于 Harness 控件上则按住 `⌥ Option` 拖动。松手后宠物会吸附到最近的左侧、右侧或底部边缘并保存位置。

可选的原生宠物层只在 Chat 显示，从 `~/.codex/pets` 读取兼容宠物包，与 Harness 插件保持分离。它只通过停止/错误控件的语义属性判断回答状态，并向 Swift 发送固定的本地状态枚举；消息正文不会经过这条桥。

| 任务状态 | Harness 宠物 | Chat 宠物 |
| --- | --- | --- |
| 待机 | 回到所选待机或交互动画 | 回到所选待机或交互动画 |
| 运行中 | 跟随当前会话或仍在运行的后台任务 | 跟随页面中可见的回答生成控件 |
| 成功 | 完整播放一轮 `review` 动画 | 完整播放一轮 `review` 动画 |
| 失败 | 在本轮任务出现新错误时完整播放一轮 `failed` | 页面出现新的语义错误状态时完整播放一轮 `failed` |

任务状态会暂时获得高于悬停和点击动作的视觉优先级，但不会改变拖动、贴边、保存位置、宠物包选择或用户保存的启用/关闭偏好。

## 常用快捷键

| 操作 | 快捷键 |
| --- | --- |
| 选择项目 | `⌘O` |
| 新任务 | `⌘N` |
| 重新加载 Harness | `⌘R` |
| 切换到 Harness | `⌘1` |
| 切换到 Chat | `⌘2` |
| API 与余额设置 | `⇧⌘B` |
| 主题背景 | `⇧⌘T` |
| 桌面宠物 | `⇧⌘P` |
| Harness 日志 | `⇧⌘L` |

## 开发

直接从源码运行：

```bash
swift run HarnessDock
```

开发时指定工作区与端口：

```bash
swift run HarnessDock --workspace /absolute/path/to/project --port 3095
```

验证本地构建：

```bash
./scripts/run_checks.sh
swift build
./scripts/build_app.sh
plutil -lint dist/HarnessDock.app/Contents/Info.plist
```

安装完整 Xcode 后还可以运行 `swift test`。仅安装 Command Line Tools 的系统可能缺少 XCTest/Testing 框架，因此 `run_checks.sh` 提供不依赖测试框架的核心检查。

## 项目结构

```text
HarnessDock/
├── Sources/                  # SwiftUI 外壳、WebKit 集成、应用状态与核心服务
├── Tests/                    # XCTest 单元测试
├── Resources/                # Info.plist 与应用图标资源
├── plugins/harnessdock-pet/          # 使用官方插槽的 Harness 桌面宠物插件
├── scripts/                  # 构建和验证脚本
└── docs/                     # 截图、规划、审核与发布文档
```

## 更新与卸载

更新源码构建时，先退出 HarnessDock，再拉取最新代码、重新构建并打开 `dist/HarnessDock.app`。正在运行的旧版本不会被自动替换。

从 DS Harness 升级时，已有 Chat Cookie、本地设置、主题背景、已导入宠物和余额凭据仍会保留。HarnessDock 有意继续使用兼容性 Bundle Identifier `app.dsharness.desktop`，并沿用现有本地目录与钥匙串服务名；这些内部标识不代表公开产品名称。

卸载时退出应用并删除本地构建的 App。偏好设置、导入背景、WebKit Cookie 和钥匙串余额凭据等可选用户数据会保留，需单独删除。当前预览版不提供自动卸载器。

## 常见问题

- **Harness 无法启动：**确认 `node` 与 `npx` 满足版本要求，再按 `⇧⌘L` 查看 Harness 日志。
- **需要确认本机环境：**打开 **设置 → 版本与诊断**，刷新检查后复制隐私安全的诊断摘要。
- **3080 端口被占用：**只有页面包含官方 Harness 的 `__DSH_BOOT__` 标记时才会附着，否则会提示端口冲突。
- **Chat 要求登录：**这是正常行为。该页加载官方 DeepSeek Chat，不能把 Harness API Key 当作网页登录凭据。
- **Chat 宠物没有显示：**先切换到 Chat，点击右上角爪印按钮，开启原生宠物并确认已选择有效宠物包。启用状态会保存在本机。
- **余额不可用：**在设置中配置余额 Key、检查网络并刷新。这个 Key 与 Harness 模型配置相互独立。
- **macOS 阻止打开：**当前源码构建只做 ad-hoc 签名，没有 Apple 公证。请自行在本机编译测试；公开发布仍需 Developer ID 签名与 Apple 公证。

## 当前发布状态

版本 `0.1.0` 是开发者预览版。在 Product Hunt 上把公众下载描述为正式可用前，项目仍需完成：

- 选择仓库许可证；
- 准备清晰的版本变更记录；
- 生成 Developer ID 签名并通过 Apple 公证的安装包；
- 提供 Universal 2，或明确区分不同架构的安装包；
- 在干净的 Mac 上完成安装和冒烟测试；
- 提供校验和以及清晰的更新、卸载路径。

完整清单见 [GitHub 公开发布审核](docs/release-readiness.md)。

## 支持与反馈（Support）

发现问题或有功能建议？请提交 [GitHub Issue](https://github.com/nortonyang/HarnessDock/issues)，并附上复制的 **版本与诊断** 摘要、复现步骤和必要的 Harness 日志片段。请勿提交 API Key、登录 Cookie、私有代码或其他秘密信息。

## 许可证（License）

项目目前尚未选择许可证。源码可见并不自动授予复制、修改或再分发权限。在把 HarnessDock 宣传为开源项目或允许外部分发前，需要先选择并添加许可证。

## 致谢

- [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness)：提供官方智能体运行时与 Web 界面。
- [DeepSeek API 文档](https://api-docs.deepseek.com/)：提供余额与价格参考。
- Apple SwiftUI、WebKit 与 Keychain：构成原生 macOS 外壳的基础。
