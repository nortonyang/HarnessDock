# 总开发阶段文档：内嵌 DeepSeek 免费聊天

## 目标

在 DS Harness 中增加 DeepSeek 官方免费聊天页面，并允许用户从 macOS 标题栏在 Harness 与官方 Chat 之间切换；两个页面的当前状态互不丢失。

## 非目标

- 不逆向或包装免费聊天的内部接口。
- 不把 Harness 的 API Key、余额凭据、工作区文件或会话数据自动传给聊天页。
- 不绕过 DeepSeek 的登录、验证码、风控或使用条款。
- 不用 iframe 嵌入官网。

## 当前证据

- `ContentView.swift` 当前在 Harness 运行态直接展示 `HarnessWebView`。
- `HarnessWebView` 只允许 localhost 主导航，不应承担公网聊天页面职责。
- `https://chat.deepseek.com/` 当前响应包含 `Content-Security-Policy: frame-ancestors 'none'`，因此需要独立顶层 `WKWebView`。
- `WKWebsiteDataStore.default()` 可让聊天登录 Cookie 保存在本机 WebKit 数据存储。

## 假设

- “内嵌免费聊天”解释为加载 DeepSeek 官方网页，用户使用自己的官方账户登录。
- 标题栏分段切换比新增外层侧栏更符合现有全窗布局。
- 第一次选择“免费聊天”时才加载公网页面，避免应用启动即产生不必要的网络请求。

## 风险

| 风险 | 影响 | 缓解方案 | 负责人 |
| --- | --- | --- | --- |
| 官网风控拒绝 WebView | 页面无法登录或出现 429 | 提供“在 Safari 中打开”和重载入口 | Codex |
| 切换时重建 WebView | Harness 任务或聊天草稿丢失 | 首次创建后以 ZStack 常驻，仅切换透明度和命中测试 | Codex |
| 公网页面访问非官方域名 | 导航或隐私边界扩大 | DeepSeek 域名留在 WebView，其他主导航交给系统浏览器 | Codex |
| 文件上传暴露本地数据 | 用户误传文件 | 仅在用户点击官网上传控件后显示原生文件选择器 | Codex |
| 官网条款或页面结构变化 | 功能不稳定 | 不注入、不抓取，保持纯浏览器容器并提供外部浏览器回退 | Codex |

## 阶段地图

| 阶段 | 目的 | 子任务 | 进入条件 | 退出条件 | 状态 |
| --- | --- | --- | --- | --- | --- |
| S1 | 定义页面隔离契约 | ST-401 | 当前 WebView 结构已确认 | 安全边界与验收标准明确 | 已完成 |
| S2 | 页面切换与常驻 | ST-402 | S1 完成 | 两个页面可切换且不重建 | 已完成 |
| S3 | 官方 Chat 浏览器能力 | ST-403 | S2 完成 | 登录页、上传和官方域名导航可用 | 已完成 |
| S4 | 错误回退与验证 | ST-404 | S3 完成 | 构建、实机和审核门禁通过 | 已完成 |

## 验证策略

- `./scripts/run_checks.sh`
- `./scripts/build_app.sh`
- `codesign --verify --deep --strict dist/DsHarness.app`
- 实机确认标题栏切换、首次懒加载、返回后 Harness 状态保持、官网登录页和 Safari 回退入口。
