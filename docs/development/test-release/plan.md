# 总开发阶段文档：Apple Silicon 测试版发布

## 目标

为 HarnessDock 增加 GitHub Actions 测试发布流程，生成仅支持 Apple Silicon 的未签名 `.zip`，并在双语 README 中说明下载、首次打开提示和当前限制。

## 非目标

- 本阶段不做 Developer ID 签名或 Apple notarization。
- 本阶段不构建 Intel 或 Universal 版本。
- 本阶段不保留 Product Hunt 推广文案。

## 当前证据

- `scripts/build_app.sh` 已能生成 arm64 的 `dist/HarnessDock.app`，但没有归档或上传步骤。
- 仓库当前没有 release workflow，GitHub Releases 为空。
- 当前构建为 ad-hoc 签名，首次打开可能触发 Gatekeeper 提示。

## 阶段地图

| 阶段 | 目的 | 退出条件 | 状态 |
| --- | --- | --- | --- |
| S1 | 添加 arm64 测试发布 workflow | tag 触发构建并上传 zip | 进行中 |
| S2 | 更新双语 README | 下载、首次打开和限制说明一致 | 进行中 |
| S3 | 本地验证 | 文档门禁、构建和 workflow 静态检查通过 | 未开始 |

## 验收标准

- `macos-14` runner 构建并确认 `arm64`。
- GitHub Release 上传 `HarnessDock-arm64-unsigned.zip`，并标记为 prerelease。
- README 明确说明 Gatekeeper 首次打开处理方式、Node.js 26+ 要求和未签名限制。
- README 不再包含 Product Hunt 发布计划或下载表述。
