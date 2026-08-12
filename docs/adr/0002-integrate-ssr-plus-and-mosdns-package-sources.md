# ADR 0002：集成 SSR-Plus 与 MosDNS 第三方软件包源

## 状态

已接受

## 背景

本项目需要在 OpenWrt `openwrt-25.12` x86_64 固件中预装 SSR-Plus 和 MosDNS 能力，同时继续保持构建控制仓库轻量，不提交 OpenWrt 源码、第三方源码或构建产物。`fw876/helloworld` 提供 SSR-Plus 及常用代理后端，`sbwml/luci-app-mosdns` 提供独立 MosDNS LuCI 应用与运行时包，`sbwml/v2ray-geodata` 提供 MosDNS 和代理后端共用的地理数据包。

## 决策

本项目在 CI 构建临时 OpenWrt 源码树中接入 `fw876/helloworld`、`sbwml/luci-app-mosdns` 和 `sbwml/v2ray-geodata`，不把这些仓库提交到本项目。由于 `fw876/helloworld` 和 `sbwml/luci-app-mosdns` 都可能提供 `mosdns` 包，构建流程显式优先使用 `sbwml/luci-app-mosdns` 的 MosDNS 插件栈，并屏蔽 helloworld 中的同名包；同时移除官方 feeds 中的 `v2ray-geodata`，改用 sbwml 版本以匹配 MosDNS 的推荐构建方式。

## 后果

正面影响：

- SSR-Plus 和 MosDNS 可以随固件预装，并通过 manifest 校验确认进入产物。
- 第三方源的实际 commit SHA 会纳入缓存 key，减少源变化后复用旧缓存的风险。
- 仓库仍只保存小型构建输入，符合轻量控制仓库定位。

负面影响：

- 构建结果依赖三个第三方仓库的分支状态，后续上游变更可能导致配置项或包名变化。
- 由于选择“尽量全带上”的 SSR-Plus 后端，固件体积和编译时间都会明显增加。
- 当前 `helloworld/dev` 不提供 Kcptun 包，因此不选择 `INCLUDE_Kcptun`；后续只有在上游恢复该包或接入兼容来源后才重新启用。
- MosDNS 包来源被显式覆盖，未来若要改回其他来源，需要同步调整冲突处理和 manifest 校验。

## 备选方案

备选方案一：只接入 `fw876/helloworld`。

该方案 feed 数量更少，但不能提供独立的 `luci-app-mosdns` 和 `luci-i18n-mosdns-zh-cn`。

备选方案二：寻找单一聚合仓库覆盖全部包。

该方案看似更简单，但会引入更大的上游不透明性，也更难判断 SSR-Plus 和 MosDNS 具体来自哪里。

备选方案三：把第三方包复制进本仓库。

该方案能固定源码状态，但会违反本项目不提交上游源码、保持仓库轻量的约束。
