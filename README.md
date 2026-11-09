在Zyx0rx大佬基础上维护，问题反馈：  
  
[![Telegram](https://img.shields.io/badge/Telegram-@vless__vaio-26A5E4?logo=telegram&logoColor=white)](https://t.me/vless_vaio)  

vless脚本使用方法：

```bash
wget -O vless-server.sh https://raw.githubusercontent.com/mikuuu3981/surge/main/vless-server.sh && chmod +x vless-server.sh && bash vless-server.sh
```
快捷命令
```bash
vless
```

查看完整配置：进入“协议服务管理 → 查看运行配置文件”，选择 Xray、Sing-box 或 Mihomo。脚本按服务进程的启动参数查找配置，完整输出磁盘文件；服务停止时明确标注默认配置。显示内容包含原始凭据，磁盘文件也可能与进程已经载入的配置不同。

调整已启用规则的顺序：进入 **分流管理 → 配置分流规则 → 5（调整规则顺序）**，选择 Xray 或 Sing-box。列表按该内核的实际分流顺序显示，选择规则后直接回车可置顶，也可输入目标位置；从上到下匹配，首条命中生效。同一条共享规则在两个内核中的顺序独立保存，只重载所选内核，更新失败恢复原顺序和配置，已停止的服务保持停止。

未手动排序时保留默认顺序；手动排序后，新建或覆盖的规则排在已排序规则之后，可再次调整位置。GeoSite/GeoIP 等由同一规则生成的匹配项整体移动。“所有流量”也可以前移，会覆盖其后符合相同 IP 版本的分流规则。此处排序作用于分流规则之间，系统保护、Sing-box 嗅探和用户专属路由保留原有优先级。Mihomo 当前仅支持一条 AI 分流规则，无需排序。

## 脚本更新渠道

在主菜单选择“检查脚本更新”后，可选择：

- 稳定版：跟随 `main` 分支，按发布版本升级（默认）。
- 测试版：跟随 `dev` 分支；即使版本号相同，只要脚本内容有变化也可以升级。

仓库发布 `dev` 分支后，已安装用户可直接检查并升级测试版：

```bash
vless --update-dev
```

首次直接使用测试版：

```bash
wget -O vless-server.sh https://raw.githubusercontent.com/mikuuu3981/surge/dev/vless-server.sh && chmod +x vless-server.sh && bash vless-server.sh
```

如果远端尚未发布 `dev` 分支，测试版升级会安全失败，不会替换当前脚本。测试版可能包含尚未稳定的功能。升级前会校验 GitHub Blob SHA 和 Bash 语法，并在原脚本旁保留 `.bak` 备份；更新渠道不会被永久记住，下次仍默认稳定版。

![image](https://tc.mozisen.com/i/29701fc8-b1bb-44a1-996f-afb172199829.png)

![image](https://tc.mozisen.com/i/db7cd00e-62ab-40a8-ab37-06b9dbf8084b.png)

nft脚本使用方法：
```bash
curl -L https://raw.githubusercontent.com/mikuuu3981/surge/main/nft.sh -o nft.sh
chmod +x nft.sh  
./nft.sh  
```

快捷命令：    
```bash  
nftm
```

## VLESS+Vision+REALITY 核心选择

安装 VLESS+Vision+REALITY 时可选择 Xray（默认）或 Sing-box。Sing-box 版使用独立协议键 `vless-singbox`，与 Xray 版可在不同端口同时运行；支持多端口、用户管理、分享链接和通用/Clash 订阅。

Sing-box 版与其他 Sing-box 协议共用 `vless-singbox` 服务及 `/etc/vless-reality/singbox.json`，配置或核心变更会影响同一服务的所有入站。REALITY 默认向伪装域名的 443 端口握手；域名匹配脚本托管的真实证书时，使用本地 `127.0.0.1:8443`。Vision 使用 `xtls-rprx-vision`。

卸载 Sing-box 版 VLESS 时，先校验剩余协议的配置，再重启原本正在运行的共享服务；配置生成、重启或监听检查失败会恢复原数据库、配置和服务状态。仍有 Snell 等协议时保留共享服务、原运行及自启状态和现有订阅，只有最后一个 Sing-box 协议删除后才清理共享服务。

**REALITY 防偷流量限速仅适用于 Xray。** Sing-box 版不写入 `reality_fallback_limits` 或 Xray 的 `limitFallbackUpload` / `limitFallbackDownload` 字段。

## Mieru 与 Mihomo

安装协议菜单选择 **16 → Mieru**，设置端口、用户名、密码及 TCP/UDP 传输。脚本安装 Mihomo 官方稳定版，并先检查其是否支持 Mieru 服务端；测试使用的版本为 **v1.19.33**。Mieru 不需要证书、SNI 或 REALITY 密钥。服务端与客户端的 `transport` 必须一致；TCP 和 UDP 两种传输都支持代理 TCP/UDP 流量。请在系统及云防火墙放行所选端口对应的传输协议。

- Mieru 使用独立的 `vless-mihomo` 服务、`/usr/local/bin/vless-mihomo` 和 `/etc/vless-reality/mihomo.yaml`，数据库键为 `.mihomo.mieru`。配置采用 JSON 语法（合法 YAML），凭据始终保存为字符串。
- 支持多个端口、按端口覆盖或卸载，每个端口独立设置账号密码和传输。首版每端口使用一个账号，暂不接入用户管理、配额和用户流量统计。
- “查看配置”按字段显示地址、端口、传输协议、用户名和密码，并提供可直接加入 `proxies` 的多行 Clash/Mihomo YAML 节点及已启用的订阅地址；“所有分享链接”按端口列出 IPv4/IPv6 YAML 节点。Clash/Mihomo 订阅也以多行 YAML 包含全部 Mieru 端口，保留数字账号和密码的字符串类型。通用 Base64、Surge 订阅不包含 Mieru，请使用支持 Mieru 的 Mihomo 客户端。
- 在 **分流管理 → 添加分流规则 → m（Sukka-AI-Mieru专属）** 中选择 AI 出口。使用 Sukka 的 [AI 域名规则](https://ruleset.skk.moe/Clash/non_ip/ai.txt) 和 [AI IP 规则](https://ruleset.skk.moe/Clash/ip/ai.txt)，包含 AI 语音服务的地址段；两份规则共用出口，其余流量直连。服务端开启 HTTP/TLS/QUIC 域名嗅探，保持原始目标地址。
- 仅应用 `mihomo-ai` 规则；Xray、Sing-box 的 AI 规则及其他全局规则不会进入 Mieru。支持 ALL、仅 IPv4、仅 IPv6，IP 版本条件与 AI 规则相交。添加或删除此规则只更新 Mihomo。
- AI 出口支持直连、拦截、WARP（WGCF/官方 SOCKS5）以及已有的 SOCKS5、HTTP、Shadowsocks、Trojan、Hysteria2、VLESS TCP/WS/REALITY 节点。官方 WARP SOCKS5 的 UDP 保持直连。不支持的出口参数、`via_warp` 和负载均衡组会明确报错并保留原配置。
- 规则缓存位于 `/etc/vless-reality/ruleset/mihomo-skk-ai-*.txt`，配置重建时刷新超过 24 小时的文件；下载或校验失败使用有效旧缓存，无有效缓存则拒绝更新。完整保留 IP 集中的 `IP-ASN` 规则，首次使用时 Mihomo 还需从 GitHub 下载 ASN 数据库到配置目录。Mihomo 核心下载必须通过官方 Release SHA-256 校验；“核心版本管理 → 5”可更新最新稳定版或指定正式版本。
- 节点变更、分流更新及核心更新先校验候选配置，重启或监听检查失败时恢复原配置及运行状态。Mieru 与 Sing-box Snell 独立管理，卸载一方保留另一方的记录、配置和服务。

Mieru 安装及更新会写入 `/etc/vless-reality`、`/usr/local/bin` 和 systemd/OpenRC 服务目录，重启会短暂影响所有 Mieru 入站。Mieru 与其他核心可在不同端口并存。

参考：[Mihomo Mieru 入站文档](https://wiki.metacubex.one/config/inbound/listeners/mieru/) · [Mieru 出站文档](https://wiki.metacubex.one/config/proxies/mieru/)

安全验证（仅临时目录、模拟服务；真实流量仅监听回环地址，不安装服务或修改防火墙）：

```bash
bash tests/test-mieru.sh
# 可选：真实核心配置校验及 TCP/UDP 传输、UDP 转发、AI 域名/IP/嗅探分流测试
VLESS_TEST_MIHOMO_BIN=/path/to/mihomo bash tests/test-mieru.sh
```

## Snell 与 Sing-box

- Snell v4/v5/v6 统一由 Sing-box v1.14.0+ 提供，与 HY2/TUIC/AnyTLS 共用 `vless-singbox` 服务。每个端口可独立使用不同的 PSK 和协议版本。
- Snell v4/v5 的服务端配置统一使用 `version: 5`，分享链接和 Surge 订阅仍保留所选的 `version=4/5`。这是 Sing-box 的协议兼容方式；不支持 Snell v5 的 QUIC 代理模式。
- Snell+ShadowTLS 使用 Sing-box 内置 ShadowTLS v3 接入 Snell；安装 Snell v6 时仍可选择 **Sing-box（默认）** 或 **Surge 官方**。已有官方安装不会自动迁移，两种实现可使用不同端口同时运行。
- Sing-box 版使用 `/etc/vless-reality/singbox.json`。支持多个端口，重复安装可添加或覆盖指定端口，卸载也按端口处理。v6 支持 `default` / `unshaped` / `unsafe-raw` 模式，PSK 沿用脚本的 16–255 位字母数字限制；v4/v5 配置保留对包含标点的 PSK 的支持。暂不提供 Snell 多用户、用户限额和用户流量统计。
- Sing-box 版直接复用“分流管理”的现有共享规则，包括预设 GeoSite/GeoIP、自定义域名/IP、广告及访问限制、IPv4/IPv6 匹配、直连、WARP、链式代理及现有负载均衡，不另写 Snell 专属 DNS。新核心配置使用 `domain_resolver`，无需依赖旧 `domain_strategy` 弃用开关。
- 官方版继续使用独立的 `vless-snell-v6` 服务和 `/etc/vless-reality/snell-v6.conf`，保留原有 DNS 选择。默认使用官方 `v6.0.0` 正式版下载链接（[官方发布说明](https://kb.nssurge.com/surge-knowledge-base/release-notes/snell)），已核对 amd64/aarch64 安装包与 RC2 的 SHA-256 一致；GitHub 镜像未同步时也会使用正式版。
- Surge 订阅中的 Snell v6 节点名称包含实现和端口，客户端 `mode` 与服务端一致；TFO 选择只控制客户端参数。Sing-box 节点变更先校验候选配置，重启/监听检查失败则回滚数据库、配置及服务状态；分流更新失败保留原运行配置。存在 Snell 入站时，核心更新拒绝降级至 v1.14.0 以下。
- Snell v4/v5 仅管理 `.singbox` 中的记录，ShadowTLS 的 Snell 后端仅绑定回环地址。旧 Mihomo／独立版 v4/v5 的安装、管理和自动迁移支持已移除；仍使用这些部署时，请先用保留迁移能力的旧版脚本完成迁移，再升级。本次代码清理不会自动删除服务器上的旧文件、服务或数据库记录。
- WARP 支持 WGCF 与官方 SOCKS5 模式；官方模式的 UDP 保持直连。Sing-box 的 GeoSite/GeoIP 首次使用或缓存缺失时从 GitHub 下载并编译，之后复用本地缓存。下载会显示当前规则源，连接超时 10 秒、单次传输最多 30 秒，每项规则集的全部源下载合计最多 120 秒；超时、下载或编译失败保留已有缓存及原 Sing-box 运行配置。按 Ctrl+C 取消会清理临时文件，不再显示 Python traceback。
- Instagram/INS 分流使用 `singbox-instagram`，沿用 [Yuu-rules 域名列表](https://github.com/Yuu518/Yuu-rules/blob/rule-set/mihomo/geosite/instagram.list)，仅匹配 Snell v4/v5（含 ShadowTLS）入站。规则列表缓存 24 小时，更新失败时使用已有缓存；不会扩大到 HY2/TUIC/AnyTLS 或 Snell v6。旧 `mihomo-instagram` 规则键已停止支持，升级前请删除旧规则并重新添加 `singbox-instagram`，即使节点已经迁到 Sing-box 也需要处理。
- AI 分流分为 `GeoSite-AI-Xray专属`（原 `ai-intl`，仅 Xray）与 `Sukka-AI-Sing-Box专属`（`singbox-ai`，仅 Sing-box，有 Sing-box 协议时显示 `s` 选项）。Sukka 分别使用 [non_ip](https://ruleset.skk.moe/sing-box/non_ip/ai.json) 和 [ip](https://ruleset.skk.moe/sing-box/ip/ai.json) 两份完整规则集，共用所选出口；IPv4/IPv6 限制与规则集匹配条件相交。源文件缓存到 `/etc/vless-reality/ruleset-src/`，独立编译到 `ruleset/`，配置重建时刷新超过 24 小时的缓存；更新失败使用有效旧缓存，无有效缓存则配置生成失败。添加或删除 AI 规则仅重载对应核心。
- Sing-box 服务端在 `route.rules` 首位统一添加 `{"action":"sniff"}`，从 HTTP Host、TLS SNI 或 QUIC 嗅探域名后执行分流，覆盖所有共享入站；客户端无需修改，不改写原始目标地址。
- “重启所有服务”先生成并校验配置，再由服务管理器逐个重启；不再预先停止全部代理。Sing-box 重启或监听检查失败时恢复旧配置及运行状态，错误会显示在终端；只有主动停止服务才设置“已暂停”标记。

安全回归测试（仅临时配置，不安装服务或修改防火墙）：

```bash
# VLESS 双核心并存、多端口、用户、REALITY 握手及分享/订阅
bash tests/test-singbox-vless.sh
# VLESS Sing-box 安装事务成功路径及配置/重启/健康检查失败回滚
bash tests/test-singbox-vless-install.sh
# VLESS 卸载保留共享 Snell 服务、订阅及失败回滚
bash tests/test-singbox-vless-uninstall.sh
# Snell 多版本、多端口、共享分流、升级保护与失败回滚
bash tests/test-singbox-snell.sh
# v4/v5、内置 ShadowTLS、多端口及与 Mieru 的资源隔离
bash tests/test-singbox-snell-v45.sh
# Instagram 域名规则、候选配置及入站隔离
bash tests/test-singbox-instagram.sh
# AI 核心/出口隔离、完整源编译、缓存刷新回退与菜单/重载隔离
bash tests/test-singbox-ai.sh
# GeoSite/GeoIP 下载超时、源校验、编译失败保护和 Ctrl+C 清理（离线）
bash tests/test-singbox-geo-rulesets.sh
# 可选：使用真实核心编译本地 GeoSite/GeoIP 测试数据
VLESS_TEST_SINGBOX_BIN=/usr/bin/sing-box bash tests/test-singbox-geo-rulesets.sh
# 可选：使用本机核心真实编译 AI 规则集并校验配置（不启动服务）
VLESS_TEST_SINGBOX_BIN=/usr/bin/sing-box bash tests/test-singbox-ai.sh
# 脚本自身更新、校验与失败恢复
bash tests/test-script-update.sh
# 运行配置路径识别、完整输出及停止状态
bash tests/test-runtime-config.sh
# 服务重启顺序、配置失败保护、Sing-box 回滚、暂停恢复及菜单输入中断
bash tests/test-service-restart.sh
# 分内核排序、置顶/指定位置、生成顺序、重载隔离与失败回滚
bash tests/test-routing-order.sh
# 可选：使用真实 Sing-box 校验排序后的候选配置（不启动服务）
VLESS_TEST_SINGBOX_BIN=/usr/bin/sing-box bash tests/test-routing-order.sh
# 可选：VLESS 使用已有 Sing-box 1.14+ 执行真实配置校验（不启动监听）
VLESS_TEST_SINGBOX_BIN=/path/to/sing-box bash tests/test-singbox-vless.sh
# 可选：已有 Sing-box 1.14+ 的真实配置校验及回环 TCP/UDP 测试（需要 Python 3）
VLESS_TEST_SINGBOX_BIN=/path/to/sing-box bash tests/test-singbox-snell.sh
# 可选：真实 v4/v5 配置校验与 ShadowTLS 握手测试（还需 OpenSSL）
VLESS_TEST_SINGBOX_BIN=/path/to/sing-box bash tests/test-singbox-snell-v45.sh
```

测试使用临时目录和模拟服务；规则集使用本地测试数据，不下载规则库。真实核心流量测试只监听回环地址，不安装服务、不改防火墙。Snell 安装会写入 `/etc/vless-reality`、`/usr/local/bin` 和 systemd/OpenRC 服务目录；节点变更及核心升级会短暂重启所有 Sing-box 入站，请在维护窗口操作。

REALITY 防偷流量说明：

REALITY 对鉴权失败的连接会回落到伪装目标。如果伪装目标使用 Cloudflare 等公共 CDN，服务器可能被扫描后被当作 CDN 端口转发器，消耗额外出口流量。脚本会按照 XTLS 官方文档，仅为 **Xray** 的 VLESS+REALITY 和 VLESS+REALITY+XHTTP 写入 `limitFallbackUpload` / `limitFallbackDownload` 令牌桶限速，并为每个实例随机化参数；合法 REALITY 连接不受此限速影响。Sing-box 版不支持此限速。

这里针对的是 REALITY 的 `target` 使用 CDN 的场景；普通 Cloudflare CDN 不代理原始 TCP REALITY，需使用脚本中的 XHTTP+TLS+CDN 模式。

该限速字段由 Xray 25.6.8 起支持；如果服务器保留更早的 Xray 核心，请先在脚本的核心版本管理中升级。

官方说明：<https://xtls.github.io/config/transports/reality.html>
官方实现：<https://github.com/XTLS/Xray-core/pull/4553>
