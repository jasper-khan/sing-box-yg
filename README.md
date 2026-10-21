### 本 fork：Sing-box-yg 节点脚本（VPS 专用，VLESS + Hy2 + AnyTLS）

> 边界：本 fork 只维护 VPS 版 `sb.sh`（VLESS + REALITY、Hysteria2、AnyTLS + REALITY）。上游的 Serv00/Hostuno 相关文件（`serv00.sh`、`serv00keep.sh`、`serv00.yml`、`SSH.yml`、`kp.sh`、`sb.txt`、`app.js`、`index.html`、`sversion`、`workers_keep.js`、`sbwpph_amd64`、`sbwpph_arm64`、`.github/workflows/main.yml`）已从本 fork 删除；需要这些文件请去上游仓库。上游项目：[yonggekkk/sing-box-yg](https://github.com/yonggekkk/sing-box-yg)。

### 本 fork 说明（VLESS + Hy2 + AnyTLS，伪装域名按检测到的城市自动选择，兜底上游默认 apple.com）

* 公网节点支持 VLESS + REALITY、Hysteria2、AnyTLS + REALITY。1.12 及以上内核的新安装会添加三种节点；1.10 旧内核仍为双协议。旧安装选菜单 `6` 升级后，一次性自动补加 AnyTLS、按城市同步伪装域名，并提示更新客户端节点（需内核 1.12+，旧内核先选菜单 `7` 升级）。可选的内网链路使用只监听私网地址的 SS none。vmess-ws/Argo、tuic5 保持删除。
* AnyTLS 使用独立 TCP 端口，密码、REALITY 域名、密钥及 short ID 跟随 VLESS；默认填充策略不额外调整。新装选择自动分配时，一次生成三个互不重复且未被监听占用的端口；旧安装升级补加时自动避开已有配置和监听端口，不再询问。菜单 `4` → `3` 改端口，菜单 `8` 输出 `anytls://` 分享链接和二维码，并加入聚合节点。指纹 firefox，客户端连接池参数由客户端自身设置决定。链接适用于能识别 REALITY 参数的客户端，例如 v2rayN 使用 sing-box 内核；Mihomo 不支持此组合。已添加 AnyTLS 时禁止切换到 1.12 以下内核。
* 支持纯 IPv4、纯 IPv6、双栈 VPS；amd64/arm64 架构；Alpine 系统下不支持查看运行日志。
* 不再安装未使用的 `socat`，不再创建每日凌晨 1 点重启 sing-box 的任务。新脚本运行时只清理旧版创建的那条固定每日重启任务，保留其他 cron 内容；手动启停与 systemd 的异常退出自动重启保留。
* 安装时不再询问或关闭服务器防火墙；端口确定后直接提示 VPS 防火墙/云安全组需要放行的 VLESS TCP、Hysteria2 UDP 与 AnyTLS TCP 入站端口。
* 安装 `iptables-persistent` 前固定 IPv4/IPv6 规则保存选项为 No，不再出现两次保存询问，也不在安装时保存当前防火墙规则。该依赖仍用于用户主动设置 Hy2 多端口跳跃后的规则持久化。
* 保留系统现有 DNS 管理方式：不自动安装或启用 `systemd-resolved`。同步上游 `4d5cce9`（2026-10-05）时已按此边界过滤其 DNS 服务安装改动。
* WARP-WireGuard 出站（fork.11 起恢复）：安装时脚本用 openssl + curl 自动注册一个 Cloudflare WARP 账户（私钥 / IPv6 地址 / reserved 值），不依赖 python3、xxd；WARP-plus-Socks5、warp-plus 二进制、CFwarp 管理入口、端点 IP 优选一律不做。
* 域名分流（菜单 `3` → `6`）：
  * `1`-`4` 号通道按域名分流 —— WARP-WireGuard-IPv4 优先 / WARP-WireGuard-IPv6 优先 / VPS 本地-IPv4 优先 / VPS 本地-IPv6 优先；填后缀域名（多个用空格分隔，回车表示该通道不分流）。
  * `5` 号是**“其余流量出口”**：一键在「全局 Cloudflare WARP」与「全局 VPS 直连（默认）」之间切换，不用填域名就能全局走 WARP。
  * 规则从上往下先匹配先生效：全局 WARP 时，把需要走 VPS 原生 IP 的域名填进 `3`/`4` 号通道即当直连白名单用。
  * 写入按 jq 字段路径（`sb10.json`/`sb11.json`/`sb.json` 三份同步），改完自动重启服务。sb11（1.11 以上内核）用 `endpoints` 的 wireguard 端点 + `resolve`/`outbound` 成对规则，sb10（1.10 内核）用旧版 wireguard 出站 + 分流出站规则。
* 不再生成旧版完整订阅配置：原 `sbox.json`（sing-box 客户端）与 `clmi.yaml`（Mihomo/Clash）的生成、分段推送、软链与 GitLab 发布已全部删除。三种协议统一提供分享链接与二维码（菜单 8），不生成独立客户端 JSON。vless 分享链接默认 TLS 指纹为 `fp=firefox`（上游默认 chrome）。
* 本地IP订阅（busybox httpd 订阅服务）已删除：不再有 `subport.log` / `subtoken.log` / `/root/websbox`，也不会占额外端口。
* GitLab 订阅发布与 Telegram 推送已删除：脚本里不再有这两项功能，“变更配置”菜单有 6 项（证书路径 / 节点名称 / Reality 域名 / UUID / 域名分流 / Hy2 混淆），出入站 IPv4/IPv6 切换统一收在主菜单 12，依赖里也不再安装 `git`、`expect`。
* 节点名称：安装时会问一次（回车 = 默认主机名），装完可用菜单 `3` → `2` 随时修改（输入 `0` 恢复默认主机名）。客户端里显示的就是你输入的名字（空格保留，不再替换成 `-`；只去掉 `#`），**不会再自动加 `vl-reality-` / `hy2-` 前缀**；各协议节点同名，靠协议与端口区分。改完自动刷新分享链接。
* vless-reality 的 SNI/伪装域名按城市自动选择：安装时读取 ipwho.is 返回的 `city`，命中内置城市表（洛杉矶 `www.compton.edu`、湾区 `foothill.edu`、香港 `www.hkapa.edu`、东京 `www.tnm.jp`、西雅图 `www.eskimo.com`、达拉斯 `unt.edu`、纽约 `adelphi.edu`、大阪 `www.osaka-u.ac.jp`、首尔 `uos.ac.kr`、新加坡 `a-star.edu.sg`、台北 `www.ntust.edu.tw`、法兰克福 `uni-frankfurt.de`、阿姆斯特丹 `vu.nl`、伦敦 `kew.org`、巴黎 `inria.fr`）就用对应域名；表外城市或查询失败用上游默认 `apple.com`。安装时不询问（只打印选中结果），需要更换用菜单 `3` → `3`，回车即用自动选中的域名；改完会提示到客户端更新节点信息（重新导入分享链接），旧节点的 SNI 不变会连不上。
* 自己申请的 Hysteria2 证书：用菜单 `3` → `1`（或主菜单 `11`）填写证书文件路径与私钥文件路径，脚本会校验文件存在、写入配置并重启服务。不填就继续用自签证书。
* Hy2 防探测与混淆：两个内核模板的 hysteria2 端口默认带 `masquerade: https://foothill.edu`（探测请求反代 foothill.edu，不再裸回 404）；salamander 混淆默认开启，安装时自动生成随机密码写入 sb10/sb11/sb.json，分享链接自动带 obfs 参数；菜单 `3` → `6` 可关闭或重置（改完自动刷新链接，客户端需重新导入）。
* 脚本自更新、版本检查与安装命令均指向本 fork，避免"更新一次就被上游默认值覆盖"。
* 链式代理（菜单 `14`）：支持内网与公网，由 sing-box 原生转发。内网落地选择网卡上的私网 IPv4 与端口，中转粘贴 `内网IP:端口`，经 SS none 连接落地；公网中转粘贴落地机的本 fork VLESS+Reality 完整链接，经 VLESS+Reality 连接落地。两种方式都把中转机 VLESS、Hy2、AnyTLS 的流量交给落地机，客户端直接使用中转机菜单 `8` 的节点。SS none 仅用于内网，不提供代理层加密或认证，仅绑定指定私网地址；脚本不修改防火墙。同一台机器只保留一条当前链路，切换时替换原链路。取消链路只移除本功能的入口、出站和路由规则，保留原有节点、分流与 WARP 设置。配置先校验，公网落地连接另做实际验证，应用失败自动恢复；`sb10.json`、`sb11.json` 与当前配置同步保存，切换内核不会丢失链路。
* 仓库自带自动化守卫：`.github/workflows/fork-check.yml` 在每次 push / PR 自动跑 `bash -n sb.sh`、`fork-check.ps1`、`tools/render-configs.ps1` 与 `tools/test-anytls.py`。合并上游后如果这些 fork 边界被改丢（协议范围、城市伪装域名表与 `apple.com` 兜底、`fp=firefox`、WARP-WireGuard 结构、域名分流菜单、变更配置选项数等），GitHub 上会直接变成红灯，不会静默通过。
* 合并上游后运行 `powershell -NoProfile -ExecutionPolicy Bypass -File ./fork-check.ps1`：退出码 0 表示这些不变量都还在——默认伪装域名、服务端模板结构、协议范围、自更新与版本 URL 全部归本 fork（含 `lnsb()`/`upsbyg()` 函数体内的 URL）、`version` 文件归本 fork、UUID 变更同步 hy2 密码、分享链接指纹 `fp=firefox`、“不再按行号改配置 / 不再生成旧版订阅配置”、“GitLab/Telegram 不得回流”、“本地IP订阅服务不得回流”、上游推广字样不得回流、WARP-WireGuard 通道结构（账户注册函数 + 两个模板的 wireguard 出站/分流域名规则 + 按 JSON 路径写入的分流菜单）、“变更配置菜单保持 6 项与主菜单 12 出入站菜单”与“socat 安装及每日重启创建不得回流”。
* 服务端配置另可用 `tools/render-configs.ps1` 渲染校验：按 JSON 字段检查 Reality 的 `server_name` 与 `handshake.server` 默认值为 `apple.com`，不限制字段所在行号；基础模板 inbounds 为 `vless,hysteria2`，AnyTLS 由添加函数写入新内核配置；sb10 出站为 `direct`×5 + `wireguard` + `block`（含 4 条分流规则），sb11 出站为 `direct` + `endpoints` 的 wireguard（规则必须是 `sniff` + 4 组 resolve/outbound 对 + 兜底，共 10 条）。
* 从 fork.11 之前的版本（含旧的多协议版本）升级：必须**先卸载再重装**。菜单 2 卸载后会删除 `/usr/bin/sb`，请重新执行本 README 的安装命令并选菜单 1。只点菜单 6"更新脚本"不会重建 `/etc/s-box/sb10.json`、`sb11.json`，也不会注册 WARP-WireGuard 账户（菜单 3 → 5 的域名分流会读到旧结构）；旧配置里残留的其它协议 inbound 不会被清理；卸载只清理本 fork 组件（sing-box 服务、`/etc/s-box`、`/usr/bin/sb`、旧版固定每日重启任务、SBHY2PORT 链、脚本目录的 `sbyg_update` 标记），不再处理旧版 Argo/WARP/websbox 等残留。

### 当前菜单结构

主菜单：`1 一键安装` / `2 卸载` / `3 变更配置` / `4 更改主端口与多端口跳跃` / `5 启动/关闭/重启` / `6 更新脚本` / `7 更新或切换内核` / `8 刷新并查看节点` / `9 运行日志` / `10 BBR+FQ` / `11 填写 Hysteria2 证书路径` / `12 切换入站/出站 IPv4 / IPv6` / `13 脚本使用说明书` / `14 链式代理（内网/公网）` / `0 退出`。

变更配置（主菜单 3）：`1 证书路径` / `2 节点名称` / `3 Reality 伪装域名` / `4 UUID` / `5 域名分流（WARP-WireGuard / VPS 直连）` / `6 Hy2 混淆开关（salamander）` / `0 返回`。AnyTLS 由新装或旧版升级流程自动添加。

子菜单的 `0` 返回上一层，主菜单的 `0` 退出；无效选项会重新询问。各输入框保留原有回车默认行为，取消方式以提示为准。服务菜单按状态显示“启动”或“重启”；systemd 系统上，启动/重启同时开启开机自启，关闭同时取消开机自启。版本提示只显示当前最新版的更新内容，历史记录仍保留在仓库的 `version` 文件里。VPS 状态里的“服务器地区”来自 ipwho.is，显示国家、城市与 IP 归属公司，按机器实际使用的 IPv4/IPv6 分别查询。主菜单 12 是出/入站 IPv4/IPv6 菜单：1/2 直接把入站切换为 IPv4 或 IPv6 并刷新分享链接，3 设置出站优先级（只影响 1.10 系列内核的默认直连出口）。

### 两台机器通过内网串联

两台机器先按原流程安装公网节点，并确认服务器内网已接入。不需要给脚本填写资产名称。

1. **落地机**：运行 `sb` → `14` → `1`，选择本机的内网 IP。首次设置时自动生成 `10000-65535` 之间未被 TCP/UDP 监听占用的随机端口，回车使用，也可手动填写；已有配置回车保留当前端口。复制“内网入口（落地机内网 IP+端口）”显示的地址，例如 `192.168.1.2:54321`。
2. **中转机**：运行 `sb` → `14` → `2`，在“填写落地机内网 IP+端口”提示处粘贴上述地址。脚本会先检查能否连接落地机；连接失败不修改现有配置。
3. **客户端**：复制中转机 `sb` → `8` 的 VLESS 或 Hy2 节点。流量路径为：客户端 → 中转机公网节点 → 内网 SS none → 落地机 → 目标网站。

菜单 `14` → `3` 查看本机角色与内网地址，`14` → `4` 取消本机链路。中转启用后，链路的域名分流、WARP 出口在落地机设置。若使用防火墙，落地的内网端口需允许中转内网地址访问 TCP/UDP。

### 两台机器通过公网串联

可连接不同厂商的服务器。两台机器正常安装本 fork 的节点，落地机使用现有公网节点出网。

1. **落地机**：运行 `sb` → `8`，复制 VLESS+Reality 完整分享链接。
2. **中转机**：运行 `sb` → `14` → `5`，粘贴上述链接（输入隐藏）。当前仅支持本 fork 的 VLESS+Reality TCP Vision 链接。脚本先校验配置，再通过该节点实际访问 HTTPS；验证失败保留现有链路，成功后替换当前链路。
3. **客户端**：使用中转机 `sb` → `8` 的 VLESS 或 Hy2 节点。两种入口统一经落地机的 VLESS+Reality 节点出网。

菜单 `14` → `3` 查看链路类型、落地地址和协议；`14` → `4` 取消本机链路并恢复原有节点路由。链路的域名分流、WARP 出口在落地机设置。落地机公网节点需能从中转机访问。

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
2. `git merge upstream/main`：不要使用 `-X ours`。冲突时手工解决，明确保留本 fork 的删除边界（vmess/Argo、tuic、WARP-Socks5/warp-plus、端点 IP 优选、GitLab 订阅、Telegram 推送、本地IP订阅服务相关功能不得重新引入，删除处保持删除）；WARP-WireGuard 出站与域名分流（菜单 `3` → `6`，fork.11 结构）属于要保留的功能。接受 vless-reality、hysteria2 路径上的上游改动，并保留 `apple.com` 默认值（上游默认）、城市伪装域名表、`fp=firefox` 默认指纹与指向本 fork 的自更新/版本 URL。
3. 合并后依次运行：`bash -n sb.sh`、`powershell -NoProfile -ExecutionPolicy Bypass -File ./fork-check.ps1`、`powershell -NoProfile -ExecutionPolicy Bypass -File ./tools/render-configs.ps1`；三条全绿再 push，push 后 GitHub Actions 会再跑一遍同样的检查。
4. 不要用会把 fork 改动真正覆盖掉的操作：`git reset --hard upstream/main`、`git checkout upstream/main -- .`、`git merge -X theirs upstream/main`。要合上游就用第 2 步的普通 merge，冲突必须人工按 fork 边界解决。
5. 服务端配置的读写已全部改为按 jq 字段路径（`.inbounds[0]` = vless-reality、`.inbounds[1]` = hysteria2），上游增删字段不再影响这些功能；脚本中已不存在按行号改写配置的 sed，`fork-check.ps1` 会守住这一点。

-----------------------------------------------------

### Serv00/Hostuno（已从本 fork 删除）

* 本 fork 已删除上游 Serv00/Hostuno 相关文件（顶部边界所列 13 个文件，含 serv00 保活 Action），仓库只保留 VPS 版 `sb.sh`；`fork-check.ps1` 会检查它们不得回流。
* 需要 Serv00/Hostuno 脚本请前往上游仓库 `yonggekkk/sing-box-yg`；上游该部分是三协议（含 vmess-ws/Argo），与本 fork 的 VPS 范围无关。

-----------------------------------------------------

#### 声明：本 fork 代码来源于上游 yonggekkk/sing-box-yg 与 Github 社区整合。
