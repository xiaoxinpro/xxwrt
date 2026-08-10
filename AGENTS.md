# AGENTS.md

## Repository Purpose
This repository is a lightweight control plane for GitHub Actions builds of OpenWrt.
It must not vendor the OpenWrt source tree.

## Writing Rules
- All documents other than this file must be written in Chinese.
- All text files must be UTF-8 encoded.
- Source files must use UTF-8 without BOM.
- PowerShell scripts (`.ps1`) must use UTF-8 with BOM.
- Use Chinese for comments when comments are necessary.

## Directory Layout
- `.github/workflows/`: GitHub Actions workflows.
- `.ai/`: task notes, constraints, and loop state.
- `scripts/`: small PowerShell helpers only.

Keep the repository minimal. Do not add generated artifacts, large local build outputs, or a committed OpenWrt checkout.
Do not introduce a git submodule as the default source delivery mechanism.
Never commit `.ai/token.key` or other local credentials.

## OpenWrt Build Policy
- GitHub Actions must fetch `https://github.com/openwrt/openwrt` at branch `openwrt-25.12`.
- Build inputs should stay external and small.
- Prefer workflow inputs or a tiny config file over repository bloat.
- Cache `dl/`, `staging_dir/`, and `ccache` whenever practical.
- Include the OpenWrt ref and the config hash in cache keys when available.

## Change Discipline
- Keep edits scoped to the smallest useful set of files.
- Avoid unnecessary abstractions and duplicate scripts.
