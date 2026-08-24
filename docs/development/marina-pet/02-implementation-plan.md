# 具体开发方案：Harness 桌面宠物插件

## 开发方案

| 步骤 | 工作内容 | 文件或区域 | 验证方式 | 状态 |
| --- | --- | --- | --- | --- |
| 1 | 对齐本机 DSH 0.1.0-rc.6 的 bundle、client、slot 契约 | 本机官方包与本文档 | 接口证据与 Loader 配置 | 已完成 |
| 2 | 完成 Marina 9 行动作与 QA | `artifacts/pets/marina-run` | job status、review、validation、联系表 | 已完成 |
| 3 | 创建正式插件包 | `plugins/dsh-pet` | manifest/patch 静态检查 | 已完成 |
| 4 | 构建单文件 client bundle，内嵌 DeepWhale / Marina 图集 | `plugins/dsh-pet/lib/client.js` | data URL、哈希、bundle wrapper 检查 | 已完成 |
| 5 | 注册 `shell.overlay` 与 `settings.plugins.tab` | 插件客户端 | 真实页面交互检查 | 已完成 |
| 6 | 安装到 `web` profile 并审核 | `~/.dsh/profiles/web`（命令管理） | dump-config、插件列表、切换与刷新 | 已完成 |
| 7 | 回归 DsHarness 原生构建与更新说明 | README、checks、dist | checks/build | 已完成 |
| 8 | 扩展偏好模型，保存 `edge` 与沿边 `offset` | `plugins/dsh-pet/src/client.template.js` | 非法旧值迁移与纯函数检查 | 已完成 |
| 9 | 实现拖动、最近边吸附和三边设置 | 插件 overlay / 设置页 | 左、右、底吸附案例 | 已完成 |
| 10 | 实现部分隐藏和周期探头，保持点击穿透 | 插件 CSS / overlay | CSS 契约与 Harness 命中检查 | 已完成 |
| 11 | 重建插件并回归 macOS 应用 | plugin check、root checks、dist | 构建与签名验证 | 已完成 |
| 12 | 增加坐标式悬停、点击反馈与拖动状态动画 | 插件 overlay 事件层 | 三种动作行与事件穿透检查 | 已完成 |
| 13 | 执行 npm 打包预检并记录官方收录路径 | package、README | `npm pack --dry-run` 与文档审核 | 已完成 |
| 14 | 构建时复制插件发布文件到 app Resources | `scripts/build_app.sh` | app bundle 文件清单与签名 | 已完成 |
| 15 | 安装 app、重绑 profile 并重启 Harness | `/Applications/DsHarness.app`、web profile | link 目标、3080 启动图、真实 UI | 已完成 |
| 16 | 锁定已验证的 Harness 版本并优先直接运行匹配缓存，缺失时再回退 npx | `HarnessConfiguration`、`ExecutableLocator` 与检查 | 缓存版本校验、3080 启动图与进程命令 | 已完成 |
| 17 | 左侧停靠时仅镜像精灵，保持容器向左裁切 | 插件 CSS 与静态检查 | 左侧镜像契约、右/底边不变、插件构建 | 已完成 |

## 实现约束

- 包名 `@dsharness/pet`，Loader ID `pet`。
- `cordis.patch.yml` 只插入自身条目，不覆盖 Harness 内置条目。
- Host `apply()` 无副作用；浏览器端通过 `dsh.client` 进入启动图。
- client bundle 使用 Harness 模块包装协议 `window.__ModuleLoader__.load`，运行时只依赖 React 与通过注入获得的 `slots`。
- 用 `ctx.slots.inject` 跟随插槽声明与 teardown；所有注册 disposer 由 Cordis 生命周期管理。
- 设置使用 `dsharness.pet.preferences.v1` localStorage 键；仅接受白名单宠物 ID和布尔值。
- 图集按 8 列、9 行、192×208 单格播放；空闲为第 0 行，并定时播放挥手行。
- overlay 保持 `pointer-events: none`；文档捕获阶段用坐标识别悬停与点击但不阻止事件。非交互背景可直接拖动；交互控件上只允许 `⌥` 强制拖动。
- 停靠边只允许 `left`、`right`、`bottom`，沿边位置归一化并限制在安全区间；旧偏好自动补默认值。

## 兼容与回滚

- 插件是单独 profile bundle，可通过官方插件管理命令移除；不修改官方 npm 包。
- DeepWhale 保持默认值，Marina 只作为新增选择项。
- 现有 macOS 原生宠物资源与控制器仅在 Chat 页面显示；Harness 页面由正式插件独占，防止重复宠物或原生覆盖层遮挡按钮。
- 应用内只复制 npm `files` 对应的运行文件；profile 使用应用内绝对路径，本机删除或移动开发仓库不影响已安装插件。
- 如果 Harness 插槽契约升级，插件在包级隔离，可更新 bundle 而不迁移 DsHarness 主应用数据。
- 左侧朝向通过 overlay 子级精灵镜像实现，不对定位容器做缩放，避免 `translate` 方向和拖动命中矩形被反转。

## Codex 审核清单

- 安装后插件列表是否出现 `pet`，而不是只看到 macOS 原生 UI。
- overlay 是否为附加列表项且保持 click-through。
- 设置页是否位于“插件”分区，能切换两只宠物并持久化。
- Marina 每行是否由参考图与 canonical base grounding，左右方向是否分别生成。
- 是否未覆盖 Harness 官方包、DeepWhale 或工作树中的无关用户改动。
- 普通点击是否继续穿透；非交互背景拖动或 `⌥` 强制拖动才接管事件，并在松手后吸附最近边。
- 悬停是否使用 waiting 行、点击是否使用 jumping 行、拖动是否使用 running 行，且拖动阈值不会把普通点击误判为拖动。
