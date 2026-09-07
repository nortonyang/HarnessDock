# 总开发阶段文档：DSH 运行时升级

## 目标

将 HarnessDock 的官方 DSH 运行时升级到当前 npm 可安装版本，并验证桌面启动器、Web UI、内置宠物插件和 Node 运行时要求。

## 当前证据

- `Sources/HarnessDockCore/HarnessConfiguration.swift` 当前锁定 `@deepseek-ai/dsh@0.1.0-rc.6`。
- npm `latest` 为 `0.1.2-rc.1`；GitHub 最新 `0.1.3-alpha.1` 尚未发布到 npm。
- `0.1.2-rc.1` 在 Node 22.14 下因缺少 zlib Zstandard 接口启动失败，在 Node 26.7 下启动成功。
- 独立 `DSH_HOME` 中安装的 `@harnessdock/pet` 能随新版 Web UI 加载。

## 风险与兼容策略

| 风险 | 影响 | 缓解方案 |
| --- | --- | --- |
| GitHub alpha 尚未进入 npm | 无法通过当前 npx/cache 安装 | 锁定 npm latest rc，记录 alpha 状态 |
| Node 版本过低 | DSH 启动失败 | 将 Node 26+ 作为推荐，Node 22.19 仅保留历史兼容说明并要求实际验证 |
| 现有本地缓存仍是旧版 | 启动器可能复用旧服务 | 版本锁定后用精确缓存匹配；运行中的服务需重启后才会升级 |

## 验收标准

- 配置、测试断言和双语 README 使用 `0.1.2-rc.1`。
- 独立 DSH_HOME 下新版 Web UI 启动成功。
- 内置宠物插件随新版加载，页面可见宠物入口。
- 构建检查通过，并明确记录 Node 22 与 Node 26 的结果。
