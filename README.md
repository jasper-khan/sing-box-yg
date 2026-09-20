### 本 fork：Sing-box-yg 一键双协议共存脚本（VPS 专用，仅 vless-reality + hysteria2）

> 边界：本 fork 只维护 VPS 版 `sb.sh`（vless-reality + hysteria2 两个协议）。上游的 Serv00/Hostuno 相关文件（`serv00.sh`、`serv00keep.sh`、`serv00.yml`、`SSH.yml`、`kp.sh`、`sb.txt`、`app.js`、`index.html`、`sversion`、`workers_keep.js`、`sbwpph_amd64`、`sbwpph_arm64`、`.github/workflows/main.yml`）已从本 fork 删除；需要这些文件请去上游仓库。上游项目：[yonggekkk/sing-box-yg](https://github.com/yonggekkk/sing-box-yg)。

### 本 fork 说明（仅 vless-reality + hysteria2，默认伪装域名 = foothill.edu）

* 只有两个协议：vless-reality 与 hysteria2。vmess-ws/Argo、tuic5、anytls 已从脚本中删除（服务端 inbound、客户端配置、订阅分享、菜单、端口、卸载逻辑均不含这三种协议）。
* 支持纯 IPv4、纯 IPv6、双栈 VPS；amd64/arm64 架构；Alpine 系统下不支持查看运行日志。
* 安装时不再询问或关闭服务器防火墙；端口确定后直接提示 VPS 防火墙/云安全组需要放行的 VLESS TCP 与 Hysteria2 UDP 入站端口。
* WARP-WireGuard 出站（fork.11 起恢复）：安装时脚本用 openssl + curl 自动注册一个 Cloudflare WARP 账户（私钥 / IPv6 地址 / reserved 值），不依赖 python3、xxd；WARP-plus-Socks5、warp-plus 二进制、CFwarp 管理入口、端点 IP 优选一律不做。
* 域名分流（菜单 `3` → `6`）：
  * `1`-`4` 号通道按域名分流 —— WARP-WireGuard-IPv4 优先 / WARP-WireGuard-IPv6 优先 / VPS 本地-IPv4 优先 / VPS 本地-IPv6 优先；填后缀域名（多个用空格分隔，回车表示该通道不分流）。
  * `5` 号是**“其余流量出口”**：一键在「全局 Cloudflare WARP」与「全局 VPS 直连（默认）」之间切换，不用填域名就能全局走 WARP。
  * 规则从上往下先匹配先生效：全局 WARP 时，把需要走 VPS 原生 IP 的域名填进 `3`/`4` 号通道即当直连白名单用。
  * 写入按 jq 字段路径（`sb10.json`/`sb11.json`/`sb.json` 三份同步），改完自动重启服务。sb11（1.11 以上内核）用 `endpoints` 的 wireguard 端点 + `resolve`/`outbound` 成对规则，sb10（1.10 内核）用旧版 wireguard 出站 + 分流出站规则。
* 不再生成客户端配置文件：原 `sbox.json`（sing-box 客户端）与 `clmi.yaml`（Mihomo/Clash）的生成、分段推送、软链与 GitLab 发布已全部删除。只提供两个协议的分享链接（菜单 8 打印或扫码）。vless 分享链接默认 TLS 指纹为 `fp=firefox`（上游默认 chrome）。
* 本地IP订阅（busybox httpd 订阅服务）已删除：不再有 `subport.log` / `subtoken.log` / `/root/websbox`，也不会占额外端口。
* GitLab 订阅发布与 Telegram 推送已删除：脚本里不再有这两项功能，“变更配置”菜单只剩 5 项（证书路径 / 节点名称 / Reality 域名 / UUID / IP 优先级），依赖里也不再安装 `git`、`expect`。
* 节点名称：安装时会问一次（回车 = 默认主机名），装完可用菜单 `3` → `2` 随时修改（输入 `0` 恢复默认主机名）。客户端里显示的就是你输入的名字（空格保留，不再替换成 `-`；只去掉 `#`），**不会再自动加 `vl-reality-` / `hy2-` 前缀**；两条节点同名，靠协议与端口区分。改完自动刷新分享链接。
* vless-reality 默认 SNI/伪装域名固定为 `foothill.edu`：安装时不询问（只打印提示），需要更换用菜单 `3` → `3`。
* 自己申请的 Hysteria2 证书：用菜单 `3` → `1`（或主菜单 `11`）填写证书文件路径与私钥文件路径，脚本会校验文件存在、写入配置并重启服务。不填就继续用自签证书。
* 脚本自更新、版本检查与安装命令均指向本 fork，避免"更新一次就被上游默认值覆盖"。
* 仓库自带自动化守卫：`.github/workflows/fork-check.yml` 在每次 push / PR 自动跑 `bash -n sb.sh`、`fork-check.ps1`、`tools/render-configs.ps1`。合并上游后如果这些 fork 边界被改丢（协议范围、`foothill.edu`、`fp=firefox`、WARP-WireGuard 结构、域名分流菜单、变更配置选项数等），GitHub 上会直接变成红灯，不会静默通过。
* 合并上游后运行 `powershell -NoProfile -ExecutionPolicy Bypass -File ./fork-check.ps1`：退出码 0 表示这些不变量都还在——默认伪装域名、服务端模板结构、协议范围、自更新与版本 URL 全部归本 fork（含 `lnsb()`/`upsbyg()` 函数体内的 URL）、`version` 文件归本 fork、UUID 变更同步 hy2 密码、分享链接指纹 `fp=firefox`、“不再按行号改配置 / 不再生成客户端配置”、“GitLab/Telegram 不得回流”、“本地IP订阅服务不得回流”、上游推广字样不得回流、WARP-WireGuard 通道结构（账户注册函数 + 两个模板的 wireguard 出站/分流域名规则 + 按 JSON 路径写入的分流菜单）与“变更配置菜单保持 6 项”。
* 服务端配置另可用 `tools/render-configs.ps1` 渲染校验：inbounds 只允许 `vless,hysteria2`；sb10 出站为 `direct`×5 + `wireguard` + `block`（含 4 条分流规则），sb11 出站为 `direct` + `endpoints` 的 wireguard（规则必须是 `sniff` + 4 组 resolve/outbound 对 + 兜底，共 10 条）。
* 从 fork.11 之前的版本（含旧的多协议版本）升级：必须**先卸载再重装**。菜单 2 卸载后会删除 `/usr/bin/sb`，请重新执行本 README 的安装命令并选菜单 1。只点菜单 6"更新脚本"不会重建 `/etc/s-box/sb10.json`、`sb11.json`，也不会注册 WARP-WireGuard 账户（菜单 3 → 6 的域名分流会读到旧结构）；旧配置里残留的其它协议 inbound 不会被清理；卸载只清理本 fork 组件（sing-box 服务、`/etc/s-box`、`/usr/bin/sb`、crontab 的 sing-box 行、SBHY2PORT 链、脚本目录的 `sbyg_update` 标记），不再处理旧版 Argo/WARP/websbox 等残留。

### 当前菜单结构

主菜单：`1 一键安装` / `2 卸载` / `3 变更配置` / `4 更改主端口与多端口跳跃` / `5 关闭或重启` / `6 更新脚本` / `7 更新或切换内核` / `8 刷新并查看节点` / `9 运行日志` / `10 BBR+FQ` / `11 填写 Hysteria2 证书路径` / `12 更换 IP 与 IPV4/IPV6 输出` / `13 脚本使用说明书` / `0 退出`。

变更配置（主菜单 3）：`1 证书路径` / `2 节点名称` / `3 Reality 伪装域名` / `4 UUID` / `5 IPV4/IPV6 代理优先级` / `6 域名分流（WARP-WireGuard / VPS 直连）` / `0 返回`。

### 安装

```
bash <(wget -qO- https://raw.githubusercontent.com/jasper-khan/sing-box-yg/main/sb.sh)
```
或者
```
bash <(curl -Ls https://raw.githubusercontent.com/jasper-khan/sing-box-yg/main/sb.sh)
```

安装完成后运行 `sb` 打开主菜单。

### 同步上游更新

1. `git fetch upstream`
2. `git merge upstream/main`：不要使用 `-X ours`。冲突时手工解决，明确保留本 fork 的删除边界（vmess/Argo、tuic、anytls、WARP-Socks5/warp-plus、端点 IP 优选、GitLab 订阅、Telegram 推送、本地IP订阅服务相关功能不得重新引入，删除处保持删除）；WARP-WireGuard 出站与域名分流（菜单 `3` → `6`，fork.11 结构）属于要保留的功能。接受 vless-reality、hysteria2 路径上的上游改动，并保留 `foothill.edu` 默认值、`fp=firefox` 默认指纹与指向本 fork 的自更新/版本 URL。
3. 合并后依次运行：`bash -n sb.sh`、`powershell -NoProfile -ExecutionPolicy Bypass -File ./fork-check.ps1`、`powershell -NoProfile -ExecutionPolicy Bypass -File ./tools/render-configs.ps1`；三条全绿再 push，push 后 GitHub Actions 会再跑一遍同样的检查。
4. 不要用会把 fork 改动真正覆盖掉的操作：`git reset --hard upstream/main`、`git checkout upstream/main -- .`、`git merge -X theirs upstream/main`。要合上游就用第 2 步的普通 merge，冲突必须人工按 fork 边界解决。
5. 服务端配置的读写已全部改为按 jq 字段路径（`.inbounds[0]` = vless-reality、`.inbounds[1]` = hysteria2），上游增删字段不再影响这些功能；脚本中已不存在按行号改写配置的 sed，`fork-check.ps1` 会守住这一点。

-----------------------------------------------------

### Serv00/Hostuno（已从本 fork 删除）

* 本 fork 已删除上游 Serv00/Hostuno 相关文件（顶部边界所列 13 个文件，含 serv00 保活 Action），仓库只保留 VPS 版 `sb.sh`；`fork-check.ps1` 会检查它们不得回流。
* 需要 Serv00/Hostuno 脚本请前往上游仓库 `yonggekkk/sing-box-yg`；上游该部分是三协议（含 vmess-ws/Argo），与本 fork 的双协议范围无关。

-----------------------------------------------------

#### 声明：本 fork 代码来源于上游 yonggekkk/sing-box-yg 与 Github 社区整合。
