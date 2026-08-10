# 约束

- 文本文件统一使用 UTF-8。
- 源代码文件使用 UTF-8 无 BOM。
- `.ps1` 脚本文件使用 UTF-8 带 BOM。
- 目录保持最小化，不引入不必要的子模块或重复脚本。
- GitHub Actions 中从 `openwrt/openwrt` 的 `openwrt-25.12` 分支拉取源码。
- 缓存优先覆盖 `dl/`、`staging_dir/`、`ccache`。
- GitHub API token 仅允许写入本地 `.ai/token.key`，不得提交到 Git。
