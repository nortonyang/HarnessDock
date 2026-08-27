# @harnessdock/pet

DeepSeek Harness Web 桌面宠物插件。安装后 Loader 条目 `pet` 会出现在“设置 → 插件 → 插件列表”；“插件 → 桌面宠物”可切换 DeepWhale / Marina、隐藏宠物或选择左侧、右侧、底部停靠。

宠物默认隐藏部分身体并周期性探出。悬停、点击、拖动分别触发观察、跳跃、奔跑动作；可从非控件背景直接拖动，若宠物盖在按钮上则按住 `⌥ Option` 强制拖动。松手后会自动吸附最近边框并保存沿边位置；普通点击仍会传给下方 Harness 控件。

## 构建

从 HarnessDock 仓库根目录运行：

```bash
npm --prefix plugins/harnessdock-pet run build
npm --prefix plugins/harnessdock-pet run check
```

构建脚本将两张已通过 QA 的 8×9 WebP 图集以内嵌 data URL 写入单文件 `lib/client.js`，运行时不需要额外静态资源路由。

## 安装到 Harness web profile

```bash
dsh plugin --profile web add ./plugins/harnessdock-pet
```

安装或更新插件集合后重启 Harness Web，使启动图重新扫描客户端包。

## 发布与官方收录

当前 DeepSeek Harness 官方 CLI 支持从 npm、GitHub 和本地路径安装插件，但公开资料中没有官方插件网站的上传入口。此包可先发布到 GitHub；发布到 npm 前必须确认发布者拥有 `@harnessdock` scope，否则应改为自己拥有的 scope。希望成为官方包时，应向 [`deepseek-ai/deepseek-harness`](https://github.com/deepseek-ai/deepseek-harness) 提交提案或 PR，由上游维护者审核收录。

发布前预检：

```bash
npm pack ./plugins/harnessdock-pet --dry-run
```

不要把第三方社区插件市场标注为 DeepSeek 官方市场。
