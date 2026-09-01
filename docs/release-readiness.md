# HarnessDock GitHub 公开发布审核

审核日期：2026-08-27

## 结论

当前源码适合继续内部测试，但不建议直接把现有仓库和 `dist/HarnessDock.app` 作为公开正式版发布。代码中未发现硬编码 API Key 或私钥；两个可立即修复的泄露面已经收口，但仍有图标授权、软件签名、公证、上游版本锁定、项目许可证和截图隐私等发布阻塞项。

这是一份工程风险审核，不替代法律意见。

## 已处理

| 风险 | 处理结果 | 证据 |
| --- | --- | --- |
| 本地 npm 缓存和测试 Home 被 `git add .` 收录 | 已修复 | `.gitignore` 忽略 `.smoke-npm-cache/` 与 `.test-dsh-home/` |
| 环境凭据与钥匙串余额凭据边界不清 | 已修复 | 托管 Harness 继承应用启动环境中的 `DEEPSEEK_API_KEY`；Finder 启动缺失时仅从交互式登录 Shell 解析这一项导出变量。Keychain-only 凭据不复制给 Harness，凭据值不进入 WebView 或日志 |
| 明文凭据进入源码 | 当前未发现 | 对可提交文本执行常见 Key、Bearer、私钥头扫描，无命中 |
| 余额凭据持久化 | 已有保护 | Keychain 使用 `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`；Web 消息桥只接受固定动作 |
| Harness 对外监听 | 已有保护 | 启动参数显式使用 `127.0.0.1`，附着前校验 `__DSH_BOOT__` |
| Harness 上游版本漂移 | 已修复 | 默认锁定已验证的 `@deepseek-ai/dsh@0.1.0-rc.6`，并使用 `--prefer-offline` 优先复用本机缓存 |
| 用户无法确认实际应用与运行时环境 | 已修复 | 原生“版本与诊断”页显示应用构建、锁定的 Harness 版本、系统架构、服务状态和 Node/npx/dsh 可用性，并提供脱敏复制摘要 |
| 产品从 DS Harness 改名后丢失本机数据或无法启动 | 已规避 | 公开名称、App 和包名改为 HarnessDock；兼容性 Bundle ID、Application Support、钥匙串服务保持不变，宠物偏好提供旧键迁移；启动前通过官方命令把精确旧 `@dsharness/pet` profile 引用迁移到 `@harnessdock/pet` |

## 发布阻塞项

| 级别 | 风险 | 影响 | 发布前动作 |
| --- | --- | --- | --- |
| P1 | AppIcon 由 SF Symbols `sparkles` 生成 | Apple 明确禁止将 SF Symbols 用于 App 图标、Logo 或商标用途 | 替换为完全自有或已获得明确授权的原创图形，并重新生成 `AppIcon.icns` |
| P1 | 构建仅为 ad-hoc 签名 | GitHub 下载后的 App 会触发 Gatekeeper 警告，用户无法验证发布者和包体完整性 | 使用 Developer ID、Hardened Runtime、Apple 公证并 stapling；再发布 ZIP/DMG |
| P1 | 当前发布包只有 `arm64` | 现成 `.app` 无法在 README 声明支持的 Intel Mac 上运行 | 构建并验证 Universal 2（arm64 + x86_64），或明确只发布 Apple Silicon 版本 |
| P2 | 仓库没有本项目的 `LICENSE` | 公开可见不等于允许他人复制、修改或分发；上游 MIT 不会自动成为本项目许可证 | 由代码权利人选择并添加许可证；若将来捆绑上游代码，保留上游 MIT 声明和第三方 notices |
| P2 | 现有截图包含本机用户名、绝对路径、工作区名或会话内容 | 公开仓库会永久暴露开发环境信息，历史提交删除后仍可能被检索 | 发布前替换为专用演示账户/目录生成的脱敏截图，并清理图片元数据 |
| P2 | 代理可在所选工作区读写文件和执行命令 | 用户可能误选包含私钥、生产配置或私人文档的目录 | 首次启动和 README 明确提示权限边界、审批责任与最小工作区原则 |
| P2 | 当前没有自动更新、漏洞响应或完整固定依赖清单 | 用户可能长期停留在有风险的旧版 | 已显示应用与锁定的 Harness 版本；仍需记录发布包与上游校验值，并建立 `SECURITY.md` 和发布/撤回流程 |

## 品牌与上游授权

- DeepSeek Harness 上游采用 MIT 许可证，并说明其处于 developer preview、可能发生兼容性破坏。
- 上游品牌规范允许在描述中准确使用“DeepSeek Harness”，并建议生态项目用 “DSH” 命名；不得让用户误以为获得官方背书。当前 “HarnessDock” 与“非官方客户端”说明方向正确，公开页面仍应持续醒目标注。
- 应用内显示的 DeepSeek 标志来自官方 Harness Web UI；宣传截图和仓库封面不要把它处理成自己的产品 Logo。

## 建议发布顺序

1. 替换 AppIcon，并用无私人路径、无真实会话的演示环境重做截图。
2. 确认本项目许可证，增加 `LICENSE`、`NOTICE`/第三方说明与 `SECURITY.md`。
3. 已锁定并显示验证过的 `@deepseek-ai/dsh` 版本；发布前仍需在无缓存的干净用户环境完成回退下载和首次启动端到端测试。
4. 生成并验证 Universal 2 包；使用 Developer ID + Hardened Runtime 签名，提交 Apple 公证并 stapling。
5. 对最终 Git 标签和发布包重新做密钥扫描、恶意软件扫描、`spctl`/`codesign` 验证和 SHA-256 校验。
6. 先发布明确标注的 beta，小范围验证 Node 版本、Keychain、代理网络和工作区权限，再扩大分发。

## 官方依据

- [DeepSeek Harness：MIT、Developer Preview 与启动方式](https://github.com/deepseek-ai/deepseek-harness)
- [DeepSeek Harness 品牌素材使用规范](https://github.com/deepseek-ai/deepseek-harness/blob/master/BRAND_GUIDELINES.zh.md)
- [Apple：SF Symbols 使用规范](https://developer.apple.com/design/human-interface-guidelines/sf-symbols)
- [Apple：Developer ID](https://developer.apple.com/support/developer-id/)
- [Apple：公证 macOS 软件](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)
