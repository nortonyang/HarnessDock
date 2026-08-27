# Codex 5.5 审核报告：HarnessDock 全量品牌重命名

## 审核范围

- Swift Package/Targets、原生 App、构建脚本与候选包。
- Harness 宠物插件包名、客户端样式命名、旧偏好迁移和内嵌文件。
- 中英 README、CHANGELOG、Product Hunt 文案、隐私清理和远程发布状态。

## 问题发现

| 严重级别 | 问题 | 证据 | 必要动作 |
| --- | --- | --- | --- |
| P2 | 公开图库尚未补拍 | 旧品牌及真实工作区截图已从当前树移除；macOS 锁屏阻止本轮自动补拍 | 解锁后使用脱敏演示工作区重拍 |
| P2 | 完整 `swift test` 未运行 | Command Line Tools 环境缺少 `Testing` 模块 | 安装完整匹配 Xcode 后补跑；核心契约由 `HarnessDockCoreChecks` 覆盖 |

## 验收标准检查

| 用户故事 | 结果 | 证据 |
| --- | --- | --- |
| US-801 | 通过 | 用户确认 HarnessDock；命名矩阵已固化 |
| US-802 | 通过 | Swift targets/imports、App/可执行文件、脚本和文档均为 HarnessDock |
| US-803 | 通过 | `app.dsharness.desktop`、Application Support 与 Keychain 服务保持不变 |
| US-804 | 通过 | 插件检查验证旧 `dsharness.pet.preferences.v1` 迁移至新键 |
| US-805 | 部分通过 | README/CHANGELOG/Product Hunt 已同步；旧截图已移除，新图库待补 |
| US-806 | 通过 | 仓库已改名为 `nortonyang/HarnessDock`；origin 已更新；main/develop/release 均验证存在；PR #1 推进 develop → release |

## 验证结果

- `./scripts/run_checks.sh`：通过；插件、Chat Enter、本地化资源与 `HarnessDockCoreChecks` 全部通过。
- `./scripts/build_app.sh`：通过，生成 `dist/HarnessDock.app`。
- Info.plist：Display Name、Bundle Name、Executable 均为 HarnessDock；兼容 Bundle ID 保持 `app.dsharness.desktop`。
- `file`：主程序为 arm64 Mach-O；`codesign --verify --deep --strict` 通过，签名仍为 ad-hoc。
- 插件：`@harnessdock/pet` 检查及 npm pack dry-run 通过，App 内嵌 6 个发布文件。
- 候选 ZIP：8,435,845 bytes；SHA-256 `10369350380f3a9e01de649e18cbd7940e6821b3992c9fea912d4dd31ad72850`；压缩包完整性通过。
- `swift test`：受本机 Command Line Tools 缺少 `Testing` 模块限制，未通过测试发现；不是本次重命名编译错误。

## 完成度更新

| 项目 | 更新前 | 更新后 | 证据 |
| --- | ---: | ---: | --- |
| 规划与命名矩阵 | 0% | 100% | 00/01/02/03 文档 |
| 全量重命名 | 0% | 100% | 本地代码、App、插件、文档、候选包、GitHub 仓库和 origin 均完成 |

## 剩余工作

- 审核并合并 GitHub PR #1，将 `develop` 的重命名提升到 `release`；正式版本仍不得绕过 release → main 审核。
- 解锁 Mac 后补拍脱敏界面图库；正式发布仍需许可证、原创图标、Developer ID、公证和干净 Mac 验证。
