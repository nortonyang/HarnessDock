# Gemini 代码开发交接：Harness 去外壳化

事实来源：

- `docs/development/full-bleed-harness/00-master-plan.md`
- `docs/development/full-bleed-harness/01-stages-and-stories.md`
- `docs/development/full-bleed-harness/02-implementation-plan.md`

实现范围：US-202 至 US-204。运行态 WebView 全窗显示；余额胶囊嵌入官方左侧栏；原生操作移至 macOS 菜单。

增量范围：US-206、US-207。为余额面板添加显式关闭和动作自动收起；将设置入口明确命名为“配置 API Key”，继续复用原生 Keychain 配置页。

增量范围：US-208。监听官方侧栏开关的可访问名称；展开时余额为完整卡片，折叠时缩为 40×40pt 图标，保持点击详情能力。

增量范围：US-210、US-211。将展开态余额入口改为无框侧栏行；阻止余额专用 `DEEPSEEK_API_KEY` 继承给 Harness 子进程；忽略本地 smoke 缓存和测试 Home。

增量范围：US-212。余额使用与设置齿轮同宽的 18pt `¥` 图标槽；状态点作为右上角徽标，不再参与横向排版。

增量范围：US-213。将欢迎页主按钮文案从“打开本地项目”改为“进入”，并精简欢迎页入口语义。

增量范围：US-214。将欢迎页“进入”改为自动创建并使用 `Application Support/app.dsharness.desktop/Workspace`，不再打开目录选择器；菜单“选择项目…”和 `⌘O` 仍调用 `chooseWorkspace`。

增量范围：US-215。将顶部原生 segmented Picker 替换为紧凑的自定义 SwiftUI 切换器；两个选项必须等宽，继续复用 `selectSurface`，不得重建或销毁已有 WebView。

增量范围：US-216。仅在 `data-sidebar-compact="true"` 时将主题和余额的图标画布统一为 24×24pt，主题 SVG 使用 24pt 画布，余额使用带 `¥` 的 18pt 圆形币种轮廓，并向右校正约 2pt；不得改变展开态文字轴、40×40pt 点击区或现有交互。

增量范围：US-217。按 DeepSeek 官方 2026-08-24 价格页实现 UTC 峰谷判断、北京时间下一切换提示和三款 V4 模型双档价格表；余额摘要标注当前时段，面板高亮当前计价行，并提供官方价格页入口。使用分钟级本地时钟更新，不新增远程价格抓取或凭据访问。

增量范围：US-218。余额浮层在展开侧栏时避让两个 44pt 底部入口，在折叠侧栏时避让两个 40pt 入口；浮层使用独立高层级，保证配置与刷新按钮不会被主题背景入口覆盖或截获点击。

增量范围：US-219。在展开侧栏的余额金额旁和余额面板标题区显示醒目的当前时段标签；默认面板只展示余额、切换时间和操作按钮，将完整三模型峰谷价目表保留在默认收起的原生 `details` 区域中。不得删除价格信息或改变折叠侧栏图标布局。

增量范围：US-220。改用 `https://api-docs.deepseek.com/zh-cn/quick_start/pricing/` 的人民币单价与两款模型范围；中文表标准价作为高峰价，现有谷时五折规则生成谷时价。移除美元符号、汇率与估算文案，来源按钮打开中文价格表。

增量范围：US-221。不新增远程用量请求；从 Harness 当前页面的本地会话统计文本提取“输入/输出 tok”（兼容英文），同步显示在侧栏余额副标题与余额面板。不得依赖压缩类名；没有统计时显示“暂无用量”。

增量范围：US-222。移除余额 API Key 的独立 sheet，新增原生 SwiftUI `Settings` 场景和“API 与余额”设置内容；所有余额配置入口统一请求打开设置窗口。保留 `SecureField`、钥匙串、环境变量优先级、移除与刷新逻辑，保存后不自动关闭。不得将 Key 注入 Harness WebView。

增量范围：US-223。`AppSettingsView` 在 `balanceCredentialSource != .none` 且用户未主动更换时只显示已配置状态、“更换 API Key”和刷新；仅未配置或进入更换模式时渲染空 `SecureField` 与保存动作。钥匙串移除和环境变量回退逻辑保持不变，任何现有 Key 都不得回显。

增量范围：US-224。在现有 `HarnessWebView` user script 中检测官方设置页，为顶部加入“新手引导”入口，并实现首次自动展示一次的只读分步讲解。步骤覆盖通用设置、默认会话预设、权限、外观/语言/繁忙时发送，以及模型、插件和 Agent 预设入口；目标存在时高亮，不存在时仍显示说明。不得调用 Harness 设置 API、改写表单值或依赖压缩类名。

增量范围：US-225。为原生 `AppSettingsView` 增加“API 与余额”和“主题背景”栏目导航，将 `ThemeSettingsView` 的内容迁入主题栏目并删除独立 sheet/完成按钮。`AppModel.requestSettings` 接收目标栏目；Harness 主题入口、应用菜单和 `⇧⌘T` 选择主题栏目，余额入口和 `⇧⌘B` 选择 API 栏目。保留现有图片存储、缩放、遮罩和错误逻辑。

增量范围：US-226（再次返工）。用户要求与 Codex 一致的两步体验：中文输入法组合态输入 `hello` 时，第一次 Enter 只让系统确认英文上屏，不额外换行、不发送；组合结束后第二次无修饰 Enter 放行给 DeepSeek 页面并正常发送一次。Shift/Option/Control/Command+Enter 在多行编辑器中仍只换行，单行输入框不提交；空白多行输入交给 DeepSeek 原生逻辑但不得产生空消息。监听器位于 `window` 捕获阶段，通过 `composedPath`、`isContentEditable` 和 input/textarea 判断可编辑控件。组合态停止传播但不 `preventDefault`；非组合态多行编辑器的无修饰 Enter 不拦截，其余受控路径继续阻止网页发送。回归必须断言首次组合确认发送计数 0、第二次普通 Enter 发送计数 1，修饰键与单行输入发送计数 0，空白输入虽然到达页面但发送计数仍为 0。不得读取、记录或传出用户编辑内容。

增量范围：US-227。为 DS Harness 原生界面增加“跟随系统 / 简体中文 / English”语言偏好，并在应用设置中提供“语言”栏目。偏好写入 UserDefaults，打开中的原生窗口与 macOS 菜单即时更新，重启后保持。覆盖原生主窗口、菜单、设置、余额/主题、欢迎/状态与宠物设置；内嵌 Harness/Chat 网页不重载、不改写语言。使用主 App Bundle 的 `zh-Hans.lproj` 与 `en.lproj` 资源，动态字符串通过统一本地化帮助方法生成。必须运行资源语法检查、完整 checks、release 构建，并实机验证中文、English 与重启持久化。不得改名、修改 Bundle ID 或扩大到第三方网页本地化。

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
- `Sources/DsHarnessApp/DeepSeekChatWebView.swift`
- `Sources/DsHarnessCore/DeepSeekChatEnterBehavior.swift`
- `scripts/check-chat-enter.mjs`

需要运行的验证：

- `./scripts/run_checks.sh`
- `./scripts/build_app.sh`
- 实机打开并截图。

返回内容：变更文件、实现摘要、验证结果、阻塞点和计划偏离。
