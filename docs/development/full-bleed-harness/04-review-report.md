# Codex 5.5 审核报告：Harness 去外壳化

## 审核范围

- `ContentView.swift` 运行态条件分支和全窗 WebView。
- `HarnessWebView.swift` 余额 user script、状态更新与受限消息桥。
- `AppModel.swift` 非敏感余额展示模型；`DsHarnessApp.swift` 菜单入口。
- release 构建、真实 Harness 会话、余额胶囊和明细面板。

## 问题发现

| 严重级别 | 问题 | 证据 | 必要动作 |
| --- | --- | --- | --- |
| - | 未发现 P0/P1/P2 缺陷 | 实机只有官方 Harness 一层主界面；余额桥不传输凭据 | 无 |
| P3 | 旧的原生侧栏组件代码仍保留但不再进入运行态 | `ContentView` 根分支不引用 `SidebarView`/`WorkspaceView` | 后续代码整理时删除，不影响当前交付 |

## 验收标准检查

| 用户故事 | 结果 | 证据 |
| --- | --- | --- |
| US-201 | 通过 | 实机截图不再显示外层 DS Harness 侧栏和项目顶栏 |
| US-202 | 通过 | AX tree 仅一个 Harness HTML 内容区；会话保持 |
| US-203 | 通过 | 左侧栏显示真实 `¥7.12`，明细显示赠送/充值/更新时间 |
| US-204 | 通过 | macOS 菜单保留项目、新任务、刷新、余额设置和日志 |
| US-205 | 通过 | checks/build/plist/codesign 与实机截图完成 |
| US-206 | 通过 | AX tree 明确显示 expanded/collapsed 状态和“收起余额明细”按钮 |
| US-207 | 通过 | 明细含“配置 API Key”；原生页包含 SecureField 和“保存并刷新” |
| US-208 | 通过 | 官方按钮显示“打开侧边栏”时，余额实机缩为 40pt `¥` 图标；脚本不重载页面 |
| US-209 | 通过 | 折叠态使用 6pt 左边距，实机截图中余额与官方图标中心线一致；展开态仍为 12pt |

## 验证结果

- `./scripts/run_checks.sh`：通过。
- `./scripts/build_app.sh`：通过。
- `plutil -lint`、`codesign --verify --deep --strict`：通过。
- Computer Use 实机检查：单层 Harness、余额胶囊及详情展开均通过。
- 增量实机检查：关闭按钮收起成功；配置动作打开安全文本栏；未读取或填写用户凭据。
- 侧栏联动检查：折叠态 AX tree 与截图通过；最终展开态截图复查遇到 ScreenCaptureKit `-3811`，但展开状态判断沿用已验证的“收起侧边栏”可访问名称。
- 对齐检查：`balance-sidebar-aligned.png` 显示紧凑余额按钮与官方鲸鱼、新会话、搜索和设置图标共用中心线；仅折叠态覆盖为 6pt，展开态的 12pt 布局未改动。

## 完成度更新

| 项目 | 更新前 | 更新后 | 证据 |
| --- | ---: | ---: | --- |
| 去外壳化 | 0% | 100% | 构建与实机证据 |
| 余额交互收口 | 0% | 100% | AX tree 与安全配置页实机证据 |
| 侧栏折叠联动 | 0% | 100% | 折叠态实机证据与构建检查 |
| 紧凑图标对齐 | 0% | 100% | 实机截图与折叠态 6pt 样式规则 |

## 剩余工作

- 无计划内剩余工作。
