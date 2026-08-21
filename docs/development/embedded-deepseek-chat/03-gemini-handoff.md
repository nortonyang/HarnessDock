# Gemini 代码开发交接：内嵌 DeepSeek 免费聊天

事实来源：

- `docs/development/embedded-deepseek-chat/00-master-plan.md`
- `docs/development/embedded-deepseek-chat/01-stages-and-stories.md`
- `docs/development/embedded-deepseek-chat/02-implementation-plan.md`

实现范围：US-401 至 US-404。增加独立 DeepSeek Chat WebView、懒加载、常驻切换、标题栏和菜单入口、官方域名导航、文件选择及错误回退。

约束：

- 不复用 Harness 注入脚本，不读取聊天内容、Cookie 或内部接口。
- 不传递 API Key、余额、工作区路径或 Harness 会话数据。
- 不绕过登录、验证码或风控。
- 不重构无关进程与主题逻辑。

预期改动区域：

- `Sources/DsHarnessApp/AppModel.swift`
- `Sources/DsHarnessApp/ContentView.swift`
- `Sources/DsHarnessApp/DeepSeekChatWebView.swift`
- `Sources/DsHarnessApp/DsHarnessApp.swift`
- `README.md`

需要运行的验证：

- `./scripts/run_checks.sh`
- `./scripts/build_app.sh`
- `codesign --verify --deep --strict dist/DsHarness.app`
- 实机完成标题栏切换、官网加载、返回保持和 Safari 回退检查。

返回内容：变更文件、实现摘要、验证结果、阻塞点和偏离计划之处。

