# 任务说明

本项目是一个轻量级的 GitHub Actions 控制仓库，用来构建 `openwrt/openwrt` 仓库的 `openwrt-25.12` 分支。

要求：
- 仓库尽量保持极简，只保留必要脚本和控制文件。
- OpenWrt 源码必须在 Actions 中拉取，不允许提交到本仓库。
- 构建中间产物尽量使用 Actions 缓存，加快后续构建。
- 所有文档默认中文，只有 `AGENTS.md` 必须使用英文。
