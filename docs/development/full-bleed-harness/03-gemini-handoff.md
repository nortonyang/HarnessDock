# Gemini 代码开发交接：Harness 去外壳化

事实来源：

- `docs/development/full-bleed-harness/00-master-plan.md`
- `docs/development/full-bleed-harness/01-stages-and-stories.md`
- `docs/development/full-bleed-harness/02-implementation-plan.md`

实现范围：US-202 至 US-204。运行态 WebView 全窗显示；余额胶囊嵌入官方左侧栏；原生操作移至 macOS 菜单。

增量范围：US-206、US-207。为余额面板添加显式关闭和动作自动收起；将设置入口明确命名为“配置 API Key”，继续复用原生 Keychain 配置页。

增量范围：US-208。监听官方侧栏开关的可访问名称；展开时余额为完整卡片，折叠时缩为 40×40pt 图标，保持点击详情能力。

增量范围：US-210、US-211。将展开态余额入口改为无框侧栏行；阻止余额专用 `DEEPSEEK_API_KEY` 继承给 Harness 子进程；忽略本地 smoke 缓存和测试 Home。

约束：

- 除移除余额专用环境变量外，不修改进程启动、端口、工作区恢复和 Keychain 逻辑。
- 不依赖 Harness 的压缩类名或 React 内部结构。
- JavaScript 消息只允许固定动作，不传输凭据。
- 不重建 WKWebView。

预期改动区域：

- `Sources/DsHarnessApp/ContentView.swift`
- `Sources/DsHarnessApp/HarnessWebView.swift`
- `Sources/DsHarnessApp/AppModel.swift`
- `Sources/DsHarnessApp/DsHarnessApp.swift`

需要运行的验证：

- `./scripts/run_checks.sh`
- `./scripts/build_app.sh`
- 实机打开并截图。

返回内容：变更文件、实现摘要、验证结果、阻塞点和计划偏离。
