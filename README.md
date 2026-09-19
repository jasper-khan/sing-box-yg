### 本 fork：Sing-box-yg 一键双协议共存脚本（VPS 专用，仅 vless-reality + hysteria2）
> 边界：本 fork 只维护 VPS 版 `sb.sh`（vless-reality + hysteria2 两个协议）。上游的 Serv00/Hostuno 相关文件（`serv00.sh`、`serv00keep.sh`、`serv00.yml`、`SSH.yml`、`kp.sh`、`sb.txt`、`app.js`、`index.html`、`sversion`、`workers_keep.js`、`sbwpph_amd64`、`sbwpph_arm64`、`.github/workflows/main.yml`）已从本 fork 删除；需要这些文件请去上游仓库。

### 注：本项目分享订阅节点都为本地化生成，不使用节点转换、订阅器等第三方外链引用，无需担心节点订阅被外链作者查看

### 交流平台：[甬哥博客地址](https://ygkkk.blogspot.com)、[甬哥YouTube频道](https://www.youtube.com/@ygkkk)、[甬哥TG电报群组](https://t.me/+jZHc6-A-1QQ5ZGVl)、[甬哥TG电报频道](https://t.me/+DkC9ZZUgEFQzMTZl)

----------------------------------------------------------------
#### 本 fork 与上游多协议版本（含 Argo）相互独立：本 README 只提供 VPS `sb.sh`（vless-reality + hysteria2）的安装与说明。

--------------------------------------------------------------

### 一、Sing-box-yg小白专享一键双协议共存脚本（VPS专用，本 fork 维护）

* 支持两个协议：Vless-reality-vision、Hysteria-2（Vmess-ws(tls)/Argo、Tuic-v5、Anytls 已删除）

* 支持纯IPV6、纯IPV4、双栈VPS，支持amd与arm架构，支持alpine系统，推荐使用最新的Ubuntu系统

* 小白简单模式：安装时自动生成自签证书，无需域名证书、也不再询问证书选项，回车三次就安装完成（内核版本 / 端口方式 / 节点名称都可直接回车），复制、扫描你要的节点配置

#### 相关说明及注意点请查看[甬哥博客说明与Sing-box视频教程](https://ygkkk.blogspot.com/2023/10/sing-box-yg.html)

#### 视频教程：
[SSH连不上？使用VPS内置SSH，配合一键功能化脚本命令，小白也能快速搭节点！（Racknerd等所有VPS通用）](https://youtu.be/vhqPG9h8PB4)

[Racknerd VPS：小白自建最强翻墙代理协议组合方案；高速、稳定、无视IP被封；解决Google gemini无法使用问题](https://youtu.be/aGEmCu503V8)

[🥇搭建代理9大问题排行榜：第4名全网99%的人被误导！第1名每个人都被折腾到爆！](https://youtu.be/pJwJBqBkcfw)

[🥇2025年度代理协议"拉到夯"综合排名](https://youtu.be/IoFtykGXDao)

* 以下视频清单属于上游多协议教程（Argo/WARP/AnyTLS/vmess 等），本 fork 仅支持 vless-reality 与 hysteria2，视频中的部分功能在本 fork 不可用。

[Sing-box精装桶小白一键脚本（一）：配置文件通吃SFA/SFI/SFW三平台客户端，Argo隧道、双证书切换、域名分流](https://youtu.be/QwTapeVPeB0)

[Sing-box精装桶小白一键脚本（二）：纯IPV6 VPS搭建，CDN优选IP设置汇总，全平台多种客户端一个脚本全套带走](https://youtu.be/kmTgj1DundU)

[Sing-box精装桶小白一键脚本（三）：自建gitlab私有订阅链接一键同步推送全平台，WARP分流ChatGPT，SFW电脑客户端支持订阅链接](https://youtu.be/by7C2HU6-fU)

[Sing-box精装桶小白一键脚本（四）：vmess协议CDN优选IP多形态设置(详见说明图)](https://youtu.be/Qfm8DbLeb6w)

[Sing-box精装桶小白一键脚本（五）：集成oblivion warp免费vpn功能，本地WARP+赛风VPN切换分流(30个国家IP)](https://youtu.be/5Y6NPsYPws0)

[Sing-box精装桶五合一脚本重磅更新（六）：新增AnyTLS协议；本地IP订阅自动同步更新，通吃Clash/Mihomo、Sing-box与聚合节点](https://youtu.be/LF0-n6-Z6kI)

### VPS专用一键脚本如下：快捷方式：```sb```

### 本 fork 说明（仅 vless-reality + hysteria2，默认伪装域名 = foothill.edu）

* 只有两个协议：vless-reality 与 hysteria2。vmess-ws/Argo、tuic5、anytls 已从脚本中删除（服务端 inbound、客户端配置、订阅分享、菜单、端口、卸载逻辑均不含这三种协议）。
* 安装时不再询问或关闭服务器防火墙；端口确定后直接提示 VPS 防火墙/云安全组需要放行的 VLESS TCP 与 Hysteria2 UDP 入站端口。
* WARP 相关功能同样已删除：wireguard 出站、WARP-plus-Socks5、CFwarp 管理入口，以及依赖 WARP 通道的"三通道域名分流"。服务端模板现在只有 `direct`（sb10 另有 `block`）。
* 不再生成客户端配置文件：原 `sbox.json`（sing-box 客户端）与 `clmi.yaml`（Mihomo/Clash）的生成、分段推送、软链与 GitLab 发布已全部删除。只提供两个协议的分享链接（菜单 8 打印、复制或扫码）。
* 本地IP订阅（busybox httpd 订阅服务）已删除：不再有 `subport.log` / `subtoken.log` / `/root/websbox`，也不会占额外端口（卸载流程仍会清理旧版留下的 websbox 进程与目录）。
* GitLab 订阅发布与 Telegram 推送已删除：脚本里不再有这两项功能，“变更配置”菜单只剩 5 项（证书路径 / 节点名称 / Reality 域名 / UUID / IP 优先级），依赖里也不再安装 `git`、`expect`。
* 节点名称：安装时会问一次（回车 = 默认主机名），装完可用菜单 `3` → `2` 随时修改（输入 `0` 恢复默认主机名）。客户端里显示的就是你输入的名字（只把空格换成 `-`、去掉 `#`），**不会再自动加 `vl-reality-` / `hy2-` 前缀**；两条节点同名，靠协议与端口区分。改完自动刷新分享链接。
* vless-reality 默认 SNI/伪装域名固定为 `foothill.edu`：安装时提示处直接回车即可；已安装的可用菜单 `3` → `2` 更换。
* 自己申请的 Hysteria2 证书：用菜单 `3` → `1`（或主菜单 `11`）填写证书文件路径与私钥文件路径，脚本会校验文件存在、写入配置并重启服务。不填就继续用自签证书。
* 脚本自更新、版本检查与上面的安装命令均指向本 fork，避免"更新一次就被上游默认值覆盖"。
* 合并上游后运行 `powershell -NoProfile -ExecutionPolicy Bypass -File ./fork-check.ps1`：退出码 0 表示默认伪装域名、服务端模板结构、自更新 URL、协议范围、“不再按行号改配置 / 不再生成客户端配置”、“GitLab/Telegram 不得回流”、“本地IP订阅服务不得回流”与“变更配置菜单保持 5 项”这些不变量都还在。
* 服务端配置另可用 `tools/render-configs.ps1` 渲染校验（预期两个模板都只输出 `vless,hysteria2`）。
* 从旧的多协议版本升级：必须**先卸载再重装**。菜单 2 卸载后会删除 `/usr/bin/sb`，请重新执行上面的安装命令并选菜单 1。只点菜单 6"更新脚本"不会重建 `/etc/s-box/sb10.json`、`sb11.json`；旧配置里残留的其它协议 inbound 不会被清理；卸载流程保留了旧版 Argo/WARP/WARP-plus 服务、进程与定时任务的清理。

### 当前菜单结构

主菜单：`1 一键安装` / `2 卸载` / `3 变更配置` / `4 更改主端口与多端口跳跃` / `5 关闭或重启` / `6 更新脚本` / `7 更新或切换内核` / `8 刷新并查看节点` / `9 运行日志` / `10 BBR+FQ` / `11 填写 Hysteria2 证书路径` / `12 更换 IP 与 IPV4/IPV6 输出` / `13 脚本使用说明书` / `0 退出`。

变更配置（主菜单 3）：`1 证书路径` / `2 节点名称` / `3 Reality 伪装域名` / `4 UUID` / `5 IPV4/IPV6 代理优先级` / `0 返回`。

### 同步上游更新

1. `git fetch upstream`
2. `git merge upstream/main`：不要使用 `-X ours`。冲突时手工解决，明确保留本 fork 的删除边界（vmess/Argo、tuic、anytls、WARP、域名分流、GitLab 订阅、Telegram 推送、本地IP订阅服务相关功能不得重新引入，删除处保持删除）；接受 vless-reality、hysteria2 路径上的上游改动，并保留 `foothill.edu` 默认值与指向本 fork 的自更新 URL。
3. 合并后依次运行：`bash -n sb.sh`、`powershell -NoProfile -ExecutionPolicy Bypass -File ./fork-check.ps1`、`powershell -NoProfile -ExecutionPolicy Bypass -File ./tools/render-configs.ps1`。
4. 服务端配置的读写已全部改为按 jq 字段路径（`.inbounds[0]` = vless-reality、`.inbounds[1]` = hysteria2），上游增删字段不再影响这些功能；脚本中已不存在按行号改写配置的 sed，`fork-check.ps1` 会守住这一点。

```
bash <(wget -qO- https://raw.githubusercontent.com/jasper-khan/sing-box-yg/main/sb.sh)
```
或者
```
bash <(curl -Ls https://raw.githubusercontent.com/jasper-khan/sing-box-yg/main/sb.sh)
```


### Sing-box-yg脚本界面预览图（注：上游多协议版界面，本 fork 菜单更少，仅供围观）

![1d5425c093618313888fe41a55f493f](https://github.com/user-attachments/assets/2b4b04a6-2de4-499a-afa1-ed78bccc50a8)

-----------------------------------------------------

### 二、Serv00/Hostuno（已从本 fork 删除）

* 本 fork 已删除上游 Serv00/Hostuno 相关文件（`serv00.sh`、`serv00keep.sh`、`serv00.yml`、`SSH.yml`、`kp.sh`、`sb.txt`、`app.js`、`index.html`、`sversion`、`workers_keep.js`、`sbwpph_amd64`、`sbwpph_arm64`、`.github/workflows/main.yml`（serv00 保活 Action）），仓库只保留 VPS 版 `sb.sh`。
* 需要 Serv00/Hostuno 脚本请前往上游仓库 `yonggekkk/sing-box-yg`；上游该部分是三协议（含 vmess-ws/Argo），与本 fork 的双协议范围无关。

-----------------------------------------------------
### 感谢支持！微信打赏甬哥侃侃侃ygkkk
![41440820a366deeb8109db5610313a1](https://github.com/user-attachments/assets/5cd2d891-ae54-4397-8211-ac4c6d1099c9)

---------------------------------------
### 感谢你右上角的star🌟
[![Stargazers over time](https://starchart.cc/yonggekkk/sing-box-yg.svg)](https://starchart.cc/yonggekkk/sing-box-yg)

---------------------------------------
#### 声明：所有代码来源于Github社区与ChatGPT的整合
