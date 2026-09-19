### 本 fork：Sing-box-yg 一键双协议共存脚本（VPS 专用，仅 vless-reality + hysteria2）
> 边界：本 fork 只维护 VPS 版 `sb.sh`（vless-reality + hysteria2 两个协议）。Serv00/Hostuno 及相关文件（如 `serv00.sh`）按上游原样保留，不属于本 fork 的维护范围。

### 注：本项目分享订阅节点都为本地化生成，不使用节点转换、订阅器等第三方外链引用，无需担心节点订阅被外链作者查看

### 交流平台：[甬哥博客地址](https://ygkkk.blogspot.com)、[甬哥YouTube频道](https://www.youtube.com/@ygkkk)、[甬哥TG电报群组](https://t.me/+jZHc6-A-1QQ5ZGVl)、[甬哥TG电报频道](https://t.me/+DkC9ZZUgEFQzMTZl)

----------------------------------------------------------------
#### 本 fork 与上游多协议版本（含 Argo）相互独立：本 README 只提供 VPS `sb.sh`（vless-reality + hysteria2）的安装与说明。

--------------------------------------------------------------

### 一、Sing-box-yg小白专享一键双协议共存脚本（VPS专用，本 fork 维护）

* 支持两个协议：Vless-reality-vision、Hysteria-2（Vmess-ws(tls)/Argo、Tuic-v5、Anytls 已删除）

* 支持纯IPV6、纯IPV4、双栈VPS，支持amd与arm架构，支持alpine系统，推荐使用最新的Ubuntu系统

* 小白简单模式：安装时自动生成自签证书，无需域名证书、也不再询问证书选项，回车三次就安装完成，复制、扫描你要的节点配置

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
* 不再生成客户端配置文件：原 `sbox.json`（sing-box 客户端）与 `clmi.yaml`（Mihomo/Clash）的生成、分段推送、软链与 GitLab 发布已全部删除。订阅只提供两个协议的分享链接与聚合订阅 `jhsub.txt`（本地 IP 订阅、GitLab、TG 推送都只推这些）。
* vless-reality 默认 SNI/伪装域名固定为 `foothill.edu`：安装时提示处直接回车即可；已安装的可用菜单 `3` → `2` 更换。
* 自己申请的 Hysteria2 证书：用菜单 `3` → `1`（或主菜单 `11`）填写证书文件路径与私钥文件路径，脚本会校验文件存在、写入配置并重启服务。不填就继续用自签证书。
* 脚本自更新、版本检查与上面的安装命令均指向本 fork，避免"更新一次就被上游默认值覆盖"。
* 合并上游后运行 `powershell -NoProfile -ExecutionPolicy Bypass -File ./fork-check.ps1`：退出码 0 表示默认伪装域名、服务端模板结构、自更新 URL、协议范围、以及"不再按行号改配置 / 不再生成客户端配置"这些不变量都还在。
* 服务端配置另可用 `tools/render-configs.ps1` 渲染校验（预期两个模板都只输出 `vless,hysteria2`）。
* 从旧的多协议版本升级：必须**先卸载再重装**。菜单 2 卸载后会删除 `/usr/bin/sb`，请重新执行上面的安装命令并选菜单 1。只点菜单 6"更新脚本"不会重建 `/etc/s-box/sb10.json`、`sb11.json`；旧配置里残留的其它协议 inbound 不会被清理；卸载流程保留了旧版 Argo/WARP/WARP-plus 服务、进程与定时任务的清理。

### 同步上游更新

1. `git fetch upstream`
2. `git merge upstream/main`：不要使用 `-X ours`。冲突时手工解决，明确保留本 fork 的删除边界（vmess/Argo、tuic、anytls、WARP、域名分流相关功能不得重新引入，删除处保持删除）；接受 vless-reality、hysteria2 路径上的上游改动，并保留 `foothill.edu` 默认值与指向本 fork 的自更新 URL。
3. 合并后依次运行：`bash -n sb.sh`、`powershell -NoProfile -ExecutionPolicy Bypass -File ./fork-check.ps1`、`powershell -NoProfile -ExecutionPolicy Bypass -File ./tools/render-configs.ps1`。
4. 服务端配置的读写已全部改为按 jq 字段路径（`.inbounds[0]` = vless-reality、`.inbounds[1]` = hysteria2），上游增删字段不再影响这些功能；脚本中已不存在按行号改写配置的 sed，`fork-check.ps1` 会守住这一点。

```
bash <(wget -qO- https://raw.githubusercontent.com/jasper-khan/sing-box-yg/main/sb.sh)
```
或者
```
bash <(curl -Ls https://raw.githubusercontent.com/jasper-khan/sing-box-yg/main/sb.sh)
```

一键快捷命令实现本地IP订阅：```printf '3\n6\n1\n订阅密码' | sb```


### Sing-box-yg脚本界面预览图（注：相关参数随意填写，仅供围观）

![1d5425c093618313888fe41a55f493f](https://github.com/user-attachments/assets/2b4b04a6-2de4-499a-afa1-ed78bccc50a8)

-----------------------------------------------------

### 二、Serv00/Hostuno（上游原样保留，不属于本 fork 维护范围）：

* 目前免费Serv00使用代理脚本有被封账号的风险，收费版Hostuno不受影响，可正常使用

* 切勿与其他Serv00脚本混用！！！

* 引用[老王eooce](https://github.com/eooce/Sing-box/blob/test/sb_00.sh)、[frankiejun](https://github.com/frankiejun/serv00-play/blob/main/start.sh)相关功能，支持一键三协议：vless-reality、vmess-ws(argo)、hysteria2

* 主要增加reality协议默认支持 CF vless/trojan 节点的proxyip以及非标端口的优选反代IP功能

* 聚合通用节点分享，支持到22个节点：三协议各自三个IP，argo全覆盖13个端口节点，已添加不死优选IP

#### 相关说明及注意点请查看[甬哥博客说明与Serv00视频教程](https://ygkkk.blogspot.com/2025/01/serv00.html)

#### 视频教程：

[Serv00免费代理脚本最终教程（一）：独家支持三个IP自定义安装，支持Proxyip+反代IP、支持Argo临时/固定隧道+CDN回源；支持五个节点的Sing-box与Clash订阅配置输出](https://youtu.be/2VF9D6z2z7w)

[Serv00免费代理脚本最终教程（二）：Serv00不必再登录SSH了，部署保活融为一体，独家支持Github、VPS、软路由多平台多账户通用部署，四大方案总有一款适合你](https://youtu.be/rYeX1iU_iZ0)

[Serv00免费代理脚本最终教程（三）：多功能网页生成【保活+重启+重置端口+查看订阅节点】、随意重置端口功能；Github+Workers自动执行保活功能任你选！](https://youtu.be/9uCfFNnjNc0)

[Serv00免费代理脚本最终教程（四）：重大更新！支持Argo临时/固定隧道相互切换，实时更新节点信息；完美适配Serv00收费版Hostuno.com](https://youtu.be/XN6_vpz1NhE)

[Serv00免费代理脚本最终教程（五）：Github、VPS、软路由多平台脚本大更新！支持多功能网页，Cron内射保活+网页外射保活，任你选](https://youtu.be/tKaBdbU4G4s)

### 关于 Serv00/Hostuno

* 本 fork 不维护 Serv00/Hostuno，也不提供安装入口；`serv00.sh` 等文件按上游原样保留、未做双协议改造。
* 如需 Serv00/Hostuno 脚本，请前往上游仓库 `yonggekkk/sing-box-yg` 自行了解，但上游脚本不属于本 fork 的 vless-reality + hysteria2 范围。

#### Serv00/Hostuno-sb-yg脚本界面预览图，仅限方案一的SSH端安装脚本（注：仅供围观）
![a6b776a094566ab14e88fdcd70ba9e9](https://github.com/user-attachments/assets/90a918ed-aec7-4a1f-8159-97f3acfd0092)


-----------------------------------------------------
### 感谢支持！微信打赏甬哥侃侃侃ygkkk
![41440820a366deeb8109db5610313a1](https://github.com/user-attachments/assets/5cd2d891-ae54-4397-8211-ac4c6d1099c9)

---------------------------------------
### 感谢你右上角的star🌟
[![Stargazers over time](https://starchart.cc/yonggekkk/sing-box-yg.svg)](https://starchart.cc/yonggekkk/sing-box-yg)

---------------------------------------
#### 声明：所有代码来源于Github社区与ChatGPT的整合
