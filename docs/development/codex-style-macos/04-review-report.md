# Codex 5.5 审核报告：Codex 风格 DeepSeek Harness macOS 客户端

## 审核范围

- `Package.swift`、`Sources/`、`Tests/`、`Resources/`、`scripts/`、`README.md`。
- `dist/DsHarness.app` 的 release 构建、Info.plist 和 ad-hoc 签名。
- 欢迎页与连接真实 DeepSeek Harness Web UI 后的 macOS 窗口。

## 问题发现

| 严重级别 | 问题 | 证据 | 必要动作 |
| --- | --- | --- | --- |
| P2 | Finder 环境可能无法发现仅由 NVM 安装的 `npx` | 本机 `npx` 位于 `~/.nvm/versions/node/v26.7.0/bin`，当前定位器覆盖 PATH/Homebrew/Volta/`~/.local/bin` | 下一版扫描 NVM 版本目录；当前先运行官方服务，应用会安全附着 |
| P3 | MVP 没有 Developer ID 签名、公证、DMG 和自动更新 | 构建脚本只执行 ad-hoc `codesign` | 公开分发阶段补齐 |

## 验收标准检查

| 用户故事 | 结果 | 证据 |
| --- | --- | --- |
| US-001 | 通过 | `swift build --product DsHarness` 成功 |
| US-002 | 通过 | `DsHarnessCoreChecks: all checks passed` |
| US-003 | 部分通过 | PATH/Homebrew/Volta/`~/.local/bin` 已覆盖；NVM-only Finder 场景结转 |
| US-004 | 通过 | 实机识别 3080 已有服务并进入不持有进程的附着状态 |
| US-005 | 通过 | 原生目录选择器选择 `SDMMO`，侧边栏恢复并显示路径 |
| US-006 | 通过 | `ui-running.jpeg` 显示真实 Harness 会话、模型与权限 UI |
| US-007 | 通过 | `dist/DsHarness.app` 已生成，plist 和 codesign 均通过 |
| US-008 | 通过 | README、规划、交接和本审核报告齐全 |

## 验证结果

- `./scripts/run_checks.sh`：通过，全部核心检查成功。
- `swift build --product DsHarness`：通过。
- `./scripts/build_app.sh`：通过，生成 release `.app`。
- `plutil -lint dist/DsHarness.app/Contents/Info.plist`：通过。
- `codesign --verify --deep --strict --verbose=2 dist/DsHarness.app`：通过。
- `git diff --check`：通过。
- 完整 Xcode 未安装，Command Line Tools 不包含 XCTest/Testing 框架，因此 `swift test` 未作为本机完成门禁；等价核心检查已由独立 executable 执行。

## 完成度更新

| 项目 | 更新前 | 更新后 | 证据 |
| --- | ---: | ---: | --- |
| MVP | 0% | 95% | 可运行应用、真实 UI 截图、核心检查与打包证据；NVM-only 自动发现结转 |

## 剩余工作

- 自动扫描 NVM 版本目录，使 Finder 直接启动时也能找到 NVM 安装的 `npx`。
- 产品化分发时补 Developer ID 签名、公证、DMG、图标和自动更新。
