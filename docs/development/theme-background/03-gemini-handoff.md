# Gemini 代码开发交接：自定义主题背景

事实来源：

- `docs/development/theme-background/00-master-plan.md`
- `docs/development/theme-background/01-stages-and-stories.md`
- `docs/development/theme-background/02-implementation-plan.md`

实现范围：US-301 至 US-304。增加本地图片导入、Application Support 持久化、遮罩强度、WebView 背景更新、侧栏入口和主题设置 sheet。

增量范围：US-305。主题设置“完成”按钮必须直接关闭 `showThemeSettings`，并保留 Esc 快捷键。

增量范围：US-306。Harness 新版存在更深的实体全屏布局层；在主题启用时动态标记并透明化占据大面积的外层布局容器，DOM 变化后重新计算，移除主题时清理标记。主题 payload 在注入桥未就绪时暂存并在就绪后应用。不得批量透明化聊天卡片、输入框和余额详情。

约束：

- 不修改官方 Harness 服务或主题配置。
- 不保存源文件路径，不把图片传给子进程或网络。
- 不重构无关的余额、进程和工作区逻辑。
- 导入副本最长边不超过 2560px；错误时保留旧背景。

预期改动区域：

- `Sources/HarnessDockApp/AppModel.swift`
- `Sources/HarnessDockApp/ContentView.swift`
- `Sources/HarnessDockApp/HarnessDockApp.swift`
- `Sources/HarnessDockApp/HarnessWebView.swift`
- `README.md`

需要运行的验证：

- `./scripts/run_checks.sh`
- `./scripts/build_app.sh`
- `codesign --verify --deep --strict dist/HarnessDock.app`
- 实机选择、调整、重启恢复和移除。

返回内容：变更文件、实现摘要、验证结果、阻塞点和偏离计划之处。
