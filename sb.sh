#!/bin/bash
export LANG=en_US.UTF-8
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
blue='\033[0;36m'
bblue='\033[0;34m'
plain='\033[0m'
red(){ echo -e "\033[31m\033[01m$1\033[0m";}
green(){ echo -e "\033[32m\033[01m$1\033[0m";}
yellow(){ echo -e "\033[33m\033[01m$1\033[0m";}
blue(){ echo -e "\033[36m\033[01m$1\033[0m";}
white(){ echo -e "\033[37m\033[01m$1\033[0m";}
readp(){ read -p "$(yellow "$1")" $2;}
[[ $EUID -ne 0 ]] && yellow "请以root模式运行脚本" && exit
stty erase $'\b' 2>/dev/null || stty erase '^H' 2>/dev/null
if [[ -f /etc/redhat-release ]]; then
release="Centos"
elif cat /etc/issue | grep -q -E -i "alpine"; then
release="alpine"
elif cat /etc/issue | grep -q -E -i "debian"; then
release="Debian"
elif cat /etc/issue | grep -q -E -i "ubuntu"; then
release="Ubuntu"
elif cat /etc/issue | grep -q -E -i "centos|red hat|redhat"; then
release="Centos"
elif cat /proc/version | grep -q -E -i "debian"; then
release="Debian"
elif cat /proc/version | grep -q -E -i "ubuntu"; then
release="Ubuntu"
elif cat /proc/version | grep -q -E -i "centos|red hat|redhat"; then
release="Centos"
else 
red "脚本不支持当前的系统，请选择使用Ubuntu,Debian,Centos系统。" && exit
fi
export sbfiles="/etc/s-box/sb10.json /etc/s-box/sb11.json /etc/s-box/sb.json"
export sbnh=$(/etc/s-box/sing-box version 2>/dev/null | awk '/version/{print $NF}' 2>/dev/null | cut -d '.' -f 1,2)
vsid=$(grep -i version_id /etc/os-release | cut -d \" -f2 | cut -d . -f1)
op=$(cat /etc/redhat-release 2>/dev/null || cat /etc/os-release 2>/dev/null | grep -i pretty_name | cut -d \" -f2)
#if [[ $(echo "$op" | grep -i -E "arch|alpine") ]]; then
if [[ $(echo "$op" | grep -i -E "arch") ]]; then
red "脚本不支持当前的 $op 系统，请选择使用Ubuntu,Debian,Centos系统。" && exit
fi
version=$(uname -r | cut -d "-" -f1)
[[ -z $(systemd-detect-virt 2>/dev/null) ]] && vi=$(virt-what 2>/dev/null) || vi=$(systemd-detect-virt 2>/dev/null)
case $(uname -m) in
armv7l) cpu=armv7;;
aarch64) cpu=arm64;;
x86_64) cpu=amd64;;
*) red "目前脚本不支持$(uname -m)架构" && exit;;
esac
if [[ -n $(sysctl net.ipv4.tcp_congestion_control 2>/dev/null | awk -F ' ' '{print $3}') ]]; then
bbr=`sysctl net.ipv4.tcp_congestion_control | awk -F ' ' '{print $3}'`
elif [[ -n $(ping 10.0.0.2 -c 2 | grep ttl) ]]; then
bbr="Openvz版bbr-plus"
else
bbr="Openvz/Lxc"
fi
hostname=$(hostname)
sbnode=$(cat /etc/s-box/nodename.log 2>/dev/null)
sbnode=${sbnode:-$hostname}

if [ ! -f sbyg_update ]; then
green "首次安装Sing-box-yg脚本必要的依赖……"
if command -v apk >/dev/null 2>&1; then
apk update
apk add bash libc6-compat jq openssl procps busybox-extras iproute2 iputils coreutils socat iptables grep tar tzdata util-linux
apk add virt-what
else
if [[ $release = Centos && ${vsid} =~ 8 ]]; then
cd /etc/yum.repos.d/ && mkdir backup && mv *repo backup/ 
curl -o /etc/yum.repos.d/CentOS-Base.repo http://mirrors.aliyun.com/repo/Centos-8.repo
sed -i -e "s|mirrors.cloud.aliyuncs.com|mirrors.aliyun.com|g " /etc/yum.repos.d/CentOS-*
sed -i -e "s|releasever|releasever-stream|g" /etc/yum.repos.d/CentOS-*
yum clean all && yum makecache
cd
fi
if [ -x "$(command -v apt-get)" ]; then
apt update -y
apt install jq cron socat busybox iptables-persistent coreutils util-linux -y
elif [ -x "$(command -v yum)" ]; then
yum update -y && yum install epel-release -y
yum install jq socat busybox coreutils util-linux -y
elif [ -x "$(command -v dnf)" ]; then
dnf update -y
dnf install jq socat busybox coreutils util-linux -y
fi
if [ -x "$(command -v yum)" ] || [ -x "$(command -v dnf)" ]; then
if [ -x "$(command -v yum)" ]; then
yum install -y cronie iptables-services
elif [ -x "$(command -v dnf)" ]; then
dnf install -y cronie iptables-services
fi
systemctl enable iptables >/dev/null 2>&1
systemctl start iptables >/dev/null 2>&1
fi
if [[ -z $vi ]]; then
apt install iputils-ping iproute2 systemctl -y
fi

packages=("curl" "openssl" "iptables" "tar" "wget" "qrencode")
inspackages=("curl" "openssl" "iptables" "tar" "wget" "qrencode")
for i in "${!packages[@]}"; do
package="${packages[$i]}"
inspackage="${inspackages[$i]}"
if ! command -v "$package" &> /dev/null; then
if [ -x "$(command -v apt-get)" ]; then
apt-get install -y "$inspackage"
elif [ -x "$(command -v yum)" ]; then
yum install -y "$inspackage"
elif [ -x "$(command -v dnf)" ]; then
dnf install -y "$inspackage"
fi
fi
done
fi
touch sbyg_update
fi

if [[ $vi = openvz ]]; then
TUN=$(cat /dev/net/tun 2>&1)
if [[ ! $TUN =~ 'in bad state' ]] && [[ ! $TUN =~ '处于错误状态' ]] && [[ ! $TUN =~ 'Die Dateizugriffsnummer ist in schlechter Verfassung' ]]; then 
red "检测到未开启TUN，现尝试添加TUN支持" && sleep 4
cd /dev && mkdir net && mknod net/tun c 10 200 && chmod 0666 net/tun
TUN=$(cat /dev/net/tun 2>&1)
if [[ ! $TUN =~ 'in bad state' ]] && [[ ! $TUN =~ '处于错误状态' ]] && [[ ! $TUN =~ 'Die Dateizugriffsnummer ist in schlechter Verfassung' ]]; then 
green "添加TUN支持失败，建议与VPS厂商沟通或后台设置开启" && exit
else
echo '#!/bin/bash' > /root/tun.sh && echo 'cd /dev && mkdir net && mknod net/tun c 10 200 && chmod 0666 net/tun' >> /root/tun.sh && chmod +x /root/tun.sh
grep -qE "^ *@reboot root bash /root/tun.sh >/dev/null 2>&1" /etc/crontab || echo "@reboot root bash /root/tun.sh >/dev/null 2>&1" >> /etc/crontab
green "TUN守护功能已启动"
fi
fi
fi
v4v6(){
v4=$(curl -s4m5 icanhazip.com -k)
v6=$(curl -s6m5 icanhazip.com -k)
#v4dq=$(curl -s4m5 -k https://myip.ipip.net | awk -F'来自于：' '{print $2}' 2>/dev/null)
v4dq=$(curl -s4m5 -k https://ip.fm | sed -n 's/.*Location: //p' 2>/dev/null)
v6dq=$(curl -s6m5 -k https://ip.fm | sed -n 's/.*Location: //p' 2>/dev/null)
}
v6(){
if [ -z "$(curl -s4m5 icanhazip.com -k)" ]; then
echo
red "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
yellow "检测到 纯IPV6 VPS，添加NAT64"
echo -e "nameserver 2a00:1098:2b::1\nnameserver 2a00:1098:2c::1" > /etc/resolv.conf
ipv=prefer_ipv6
else
ipv=prefer_ipv4
fi
}

inssb(){
red "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
green "使用哪个内核版本？"
yellow "1：使用目前最新正式版内核 (回车默认)"
yellow "2：使用之前1.10.7正式版内核 (支持IPV4/IPV6代理优先级切换)"
readp "请选择【1-2】：" menu
if [ -z "$menu" ] || [ "$menu" = "1" ] ; then
sbcore=$(curl -Ls https://github.com/SagerNet/sing-box/releases/latest | grep -oP 'tag/v\K[0-9.]+' | head -n 1)
else
sbcore='1.10.7'
fi
sbname="sing-box-$sbcore-linux-$cpu"
curl -L -o /etc/s-box/sing-box.tar.gz  -# --retry 2 https://github.com/SagerNet/sing-box/releases/download/v$sbcore/$sbname.tar.gz
if [[ -f '/etc/s-box/sing-box.tar.gz' ]]; then
tar xzf /etc/s-box/sing-box.tar.gz -C /etc/s-box
mv /etc/s-box/$sbname/sing-box /etc/s-box
rm -rf /etc/s-box/{sing-box.tar.gz,$sbname}
if [[ -f '/etc/s-box/sing-box' ]]; then
chown root:root /etc/s-box/sing-box
chmod +x /etc/s-box/sing-box
blue "成功安装 Sing-box 内核版本：$(/etc/s-box/sing-box version | awk '/version/{print $NF}')"
sbnh=$(/etc/s-box/sing-box version 2>/dev/null | awk '/version/{print $NF}' 2>/dev/null | cut -d '.' -f 1,2)
else
red "下载 Sing-box 内核不完整，安装失败，请再运行安装一次" && exit
fi
else
red "下载 Sing-box 内核失败，请再运行安装一次，并检测VPS的网络是否可以访问Github" && exit
fi
}

inscertificate(){
ym_vl_re=foothill.edu
certificatec_hy2='/etc/s-box/cert.pem'
certificatep_hy2='/etc/s-box/private.key'
red "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
green "二、生成并设置相关证书"
echo
blue "自动生成bing自签证书中……" && sleep 2
openssl ecparam -genkey -name prime256v1 -out /etc/s-box/private.key
openssl req -new -x509 -days 36500 -key /etc/s-box/private.key -out /etc/s-box/cert.pem -subj "/CN=www.bing.com"
echo
if [[ -f /etc/s-box/cert.pem ]]; then
blue "生成bing自签证书成功"
else
red "生成bing自签证书失败" && exit
fi
echo
blue "Vless-reality的SNI域名默认为 foothill.edu"
}

chooseport(){
if [[ -z $port ]]; then
port=$(shuf -i 10000-65535 -n 1)
until [[ -z $(ss -tunlp | grep -w udp | awk '{print $5}' | sed 's/.*://g' | grep -w "$port") && -z $(ss -tunlp | grep -w tcp | awk '{print $5}' | sed 's/.*://g' | grep -w "$port") ]] 
do
[[ -n $(ss -tunlp | grep -w udp | awk '{print $5}' | sed 's/.*://g' | grep -w "$port") || -n $(ss -tunlp | grep -w tcp | awk '{print $5}' | sed 's/.*://g' | grep -w "$port") ]] && yellow "\n端口被占用，请重新输入端口" && readp "自定义端口:" port
until [[ $port =~ ^[0-9]+$ && $((10#$port)) -ge 1 && $((10#$port)) -le 65535 ]]
do
yellow "\n端口必须是1-65535之间的数字" && readp "自定义端口:" port
done
port=$((10#$port))
done
else
until [[ $port =~ ^[0-9]+$ && $((10#$port)) -ge 1 && $((10#$port)) -le 65535 ]]
do
yellow "\n端口必须是1-65535之间的数字" && readp "自定义端口:" port
done
port=$((10#$port))
until [[ -z $(ss -tunlp | grep -w udp | awk '{print $5}' | sed 's/.*://g' | grep -w "$port") && -z $(ss -tunlp | grep -w tcp | awk '{print $5}' | sed 's/.*://g' | grep -w "$port") ]]
do
[[ -n $(ss -tunlp | grep -w udp | awk '{print $5}' | sed 's/.*://g' | grep -w "$port") || -n $(ss -tunlp | grep -w tcp | awk '{print $5}' | sed 's/.*://g' | grep -w "$port") ]] && yellow "\n端口被占用，请重新输入端口" && readp "自定义端口:" port
until [[ $port =~ ^[0-9]+$ && $((10#$port)) -ge 1 && $((10#$port)) -le 65535 ]]
do
yellow "\n端口必须是1-65535之间的数字" && readp "自定义端口:" port
done
port=$((10#$port))
done
fi
blue "确认的端口：$port" && sleep 2
}

vlport(){
readp "\n设置Vless-reality端口 (回车跳过为10000-65535之间的随机端口)：" port
chooseport
port_vl_re=$port
}
hy2port(){
readp "\n设置Hysteria2主端口 (回车跳过为10000-65535之间的随机端口)：" port
chooseport
port_hy2=$port
}

insport(){
red "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
green "三、设置各个协议端口"
yellow "1：自动生成每个协议的随机端口 (10000-65535范围内)，回车默认"
yellow "2：自定义每个协议端口"
readp "请输入【1-2】：" port
if [ -z "$port" ] || [ "$port" = "1" ] ; then
ports=()
for i in {1..2}; do
while true; do
port=$(shuf -i 10000-65535 -n 1)
if ! [[ " ${ports[@]} " =~ " $port " ]] && \
[[ -z $(ss -tunlp | grep -w tcp | awk '{print $5}' | sed 's/.*://g' | grep -w "$port") ]] && \
[[ -z $(ss -tunlp | grep -w udp | awk '{print $5}' | sed 's/.*://g' | grep -w "$port") ]]; then
ports+=($port)
break
fi
done
done
port_vl_re=${ports[0]}
port_hy2=${ports[1]}
else
vlport && hy2port
fi
echo
blue "各协议端口确认如下"
blue "Vless-reality端口：$port_vl_re"
blue "Hysteria-2端口：$port_hy2"
yellow "请在 VPS 防火墙与云安全组放行以下入站流量："
yellow "Vless-reality：TCP $port_vl_re"
yellow "Hysteria-2：UDP $port_hy2"
red "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
green "四、自动生成各个协议统一的uuid (密码)"
uuid=$(/etc/s-box/sing-box generate uuid)
blue "已确认uuid (密码)：${uuid}"
}

insname(){
red "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
green "五、设置节点名称"
yellow "节点名称就是分享链接末尾显示的名字，回车使用默认主机名：$hostname"
readp "请输入节点名称：" menu
menu=$(printf '%s' "$menu" | tr -d '\r\n#')
if [ -n "$menu" ]; then
printf '%s\n' "$menu" > /etc/s-box/nodename.log
sbnode=$menu
blue "节点名称已设置为：$sbnode"
fi
}

warpwg(){
red "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
green "六、自动生成 WARP-WireGuard 出站账户" && sleep 2
[[ "$ipv" == "prefer_ipv6" ]] && wgend='2606:4700:d0::a29f:c001' || wgend='162.159.192.1'
openssl genpkey -algorithm X25519 -outform DER -out /etc/s-box/warp.key 2>/dev/null
pvk=$(tail -c 32 /etc/s-box/warp.key | base64)
wpk=$(openssl pkey -in /etc/s-box/warp.key -inform DER -pubout -outform DER 2>/dev/null | tail -c 32 | base64)
rm -f /etc/s-box/warp.key
warpres=$(curl -sL --connect-timeout 5 --max-time 15 -X POST 'https://api.cloudflareclient.com/v0a2158/reg' -H 'CF-Client-Version: a-7.21-0721' -H 'Content-Type: application/json' -d '{"key":"'"$wpk"'","tos":"'"$(date -u +'%Y-%m-%dT%H:%M:%S.000Z')"'"}')
wgaddr6=$(printf '%s' "$warpres" | jq -r '.config.interface.addresses.v6' 2>/dev/null)
wgres=$(printf '%s' "$warpres" | jq -r '.config.client_id' 2>/dev/null | base64 -d 2>/dev/null | od -An -tu1 | tr -s ' ' | sed 's/^ //;s/ /, /g;s/^/[/;s/$/]/')
wgres_ok=$(printf '%s' "$wgres" | sed -n 's/^\[[0-9]\{1,3\}, [0-9]\{1,3\}, [0-9]\{1,3\}\]$/ok/p')
if [[ -z $pvk || -z $wpk || -z $wgaddr6 || $wgaddr6 = "null" || $wgres_ok != "ok" ]]; then
red "自动注册 WARP-WireGuard 账户失败，请确认VPS可访问 api.cloudflareclient.com 后重新安装" && exit
fi
wgaddr6="$wgaddr6/128"
blue "WARP-WireGuard账户生成成功 (对端：$wgend:2408)"
blue "私钥：$pvk"
blue "IPv6地址：$wgaddr6"
blue "reserved值：$wgres"
}

inssbjsonser(){
cat > /etc/s-box/sb10.json <<EOF
{
"log": {
    "disabled": false,
    "level": "info",
    "timestamp": true
  },
  "inbounds": [
    {
      "type": "vless",
      "sniff": true,
      "sniff_override_destination": true,
      "tag": "vless-sb",
      "listen": "::",
      "listen_port": ${port_vl_re},
      "users": [
        {
          "uuid": "${uuid}",
          "flow": "xtls-rprx-vision"
        }
      ],
      "tls": {
        "enabled": true,
        "server_name": "${ym_vl_re}",
          "reality": {
          "enabled": true,
          "handshake": {
            "server": "${ym_vl_re}",
            "server_port": 443
          },
          "private_key": "$private_key",
          "short_id": ["$short_id"]
        }
      }
    },
    {
        "type": "hysteria2",
        "sniff": true,
        "sniff_override_destination": true,
        "tag": "hy2-sb",
        "listen": "::",
        "listen_port": ${port_hy2},
        "users": [
            {
                "password": "${uuid}"
            }
        ],
        "ignore_client_bandwidth":false,
        "masquerade":"https://foothill.edu",
        "tls": {
            "enabled": true,
            "alpn": [
                "h3"
            ],
            "certificate_path": "$certificatec_hy2",
            "key_path": "$certificatep_hy2"
        }
    }
],
"outbounds": [
{
"type":"direct",
"tag":"direct",
"domain_strategy": "$ipv"
},
{
"type":"direct",
"tag":"vps-outbound-v4",
"domain_strategy":"prefer_ipv4"
},
{
"type":"direct",
"tag":"vps-outbound-v6",
"domain_strategy":"prefer_ipv6"
},
{
"type":"direct",
"tag":"warp-IPv4-out",
"detour":"wireguard-out",
"domain_strategy":"prefer_ipv4"
},
{
"type":"direct",
"tag":"warp-IPv6-out",
"detour":"wireguard-out",
"domain_strategy":"prefer_ipv6"
},
{
"type":"wireguard",
"tag":"wireguard-out",
"server":"$wgend",
"server_port":2408,
"local_address":[
"172.16.0.2/32",
"$wgaddr6"
],
"private_key":"$pvk",
"peer_public_key":"bmXOC+F1FxEMF9dyiK2H5/1SUtzH0JuVo51h2wPfgyo=",
"reserved":$wgres
},
{
"type": "block",
"tag": "block"
}
],
"route":{
"rules":[
{
"protocol": [
"quic",
"stun"
],
"outbound": "block"
},
{
"domain_suffix": [
"yg_kkk"
],
"outbound": "warp-IPv4-out"
},
{
"domain_suffix": [
"yg_kkk"
],
"outbound": "warp-IPv6-out"
},
{
"domain_suffix": [
"yg_kkk"
],
"outbound": "vps-outbound-v4"
},
{
"domain_suffix": [
"yg_kkk"
],
"outbound": "vps-outbound-v6"
},
{
"outbound": "direct",
"network": "udp,tcp"
}
]
}
}
EOF

cat > /etc/s-box/sb11.json <<EOF
{
"log": {
    "disabled": false,
    "level": "info",
    "timestamp": true
  },
  "inbounds": [
    {
      "type": "vless",

      
      "tag": "vless-sb",
      "listen": "::",
      "listen_port": ${port_vl_re},
      "users": [
        {
          "uuid": "${uuid}",
          "flow": "xtls-rprx-vision"
        }
      ],
      "tls": {
        "enabled": true,
        "server_name": "${ym_vl_re}",
          "reality": {
          "enabled": true,
          "handshake": {
            "server": "${ym_vl_re}",
            "server_port": 443
          },
          "private_key": "$private_key",
          "short_id": ["$short_id"]
        }
      }
    },
    {
        "type": "hysteria2",

 
        "tag": "hy2-sb",
        "listen": "::",
        "listen_port": ${port_hy2},
        "users": [
            {
                "password": "${uuid}"
            }
        ],
        "ignore_client_bandwidth":false,
        "masquerade":"https://foothill.edu",
        "tls": {
            "enabled": true,
            "alpn": [
                "h3"
            ],
            "certificate_path": "$certificatec_hy2",
            "key_path": "$certificatep_hy2"
        }
    }
],









"endpoints": [
{
"type":"wireguard",
"tag":"warp-out",
"address":[
"172.16.0.2/32",
"$wgaddr6"
],
"private_key":"$pvk",
"peers":[
{
"address":"$wgend",
"port":2408,
"public_key":"bmXOC+F1FxEMF9dyiK2H5/1SUtzH0JuVo51h2wPfgyo=",
"allowed_ips":[
"0.0.0.0/0",
"::/0"
],
"reserved":$wgres
}
]
}
],
"outbounds": [
{
"type":"direct",
"tag":"direct"
}
],
"route":{
"rules":[
{
 "action": "sniff"
},
{
"action": "resolve",
"domain_suffix": [
"yg_kkk"
],
"strategy": "prefer_ipv4"
},
{
"domain_suffix": [
"yg_kkk"
],
"outbound": "warp-out"
},
{
"action": "resolve",
"domain_suffix": [
"yg_kkk"
],
"strategy": "prefer_ipv6"
},
{
"domain_suffix": [
"yg_kkk"
],
"outbound": "warp-out"
},
{
"action": "resolve",
"domain_suffix": [
"yg_kkk"
],
"strategy": "prefer_ipv4"
},
{
"domain_suffix": [
"yg_kkk"
],
"outbound": "direct"
},
{
"action": "resolve",
"domain_suffix": [
"yg_kkk"
],
"strategy": "prefer_ipv6"
},
{
"domain_suffix": [
"yg_kkk"
],
"outbound": "direct"
},
{
"outbound": "direct",
"network": ["tcp","udp"]
}
]
}
}
EOF
[[ "$sbnh" == "1.10" ]] && num=10 || num=11
cp /etc/s-box/sb${num}.json /etc/s-box/sb.json
defobfs
}

sbservice(){
if command -v apk >/dev/null 2>&1; then
echo '#!/sbin/openrc-run
description="sing-box service"
command="/etc/s-box/sing-box"
command_args="run -c /etc/s-box/sb.json"
command_background=true
pidfile="/var/run/sing-box.pid"' > /etc/init.d/sing-box
chmod +x /etc/init.d/sing-box
rc-update add sing-box default
rc-service sing-box start
else
cat > /etc/systemd/system/sing-box.service <<EOF
[Unit]
After=network.target nss-lookup.target
[Service]
User=root
WorkingDirectory=/root
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
ExecStart=/etc/s-box/sing-box run -c /etc/s-box/sb.json
ExecReload=/bin/kill -HUP \$MAINPID
Restart=on-failure
RestartSec=10
LimitNOFILE=infinity
[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable sing-box >/dev/null 2>&1
systemctl start sing-box
systemctl restart sing-box
fi
}

ipuuid(){
if command -v apk >/dev/null 2>&1; then
status_cmd="rc-service sing-box status"
status_pattern="started"
else
status_cmd="systemctl is-active sing-box"
status_pattern="active"
fi
if [[ -n $($status_cmd 2>/dev/null | grep -w "$status_pattern") && -f '/etc/s-box/sb.json' ]]; then
v4v6
if [[ -n $v4 && -n $v6 ]]; then
green "调整IPv4/IPV6配置输出"
yellow "1：刷新本地IP，使用IPV4配置输出 (回车默认) "
yellow "2：刷新本地IP，使用IPV6配置输出"
readp "请选择【1-2】：" menu
if [ -z "$menu" ] || [ "$menu" = "1" ]; then
server_ip="$v4"
echo "$server_ip" > /etc/s-box/server_ip.log
else
server_ip="[$v6]"
echo "$server_ip" > /etc/s-box/server_ip.log
fi
else
yellow "VPS并不是双栈VPS，不支持IP配置输出的切换"
serip=$(curl -s4m5 icanhazip.com -k || curl -s6m5 icanhazip.com -k)
if [[ -z $serip ]]; then
red "本地IP探测失败（VPS网络异常），已保留原分享链接IP，请稍后重试"
elif [[ "$serip" =~ : ]]; then
server_ip="[$serip]"
echo "$server_ip" > /etc/s-box/server_ip.log
else
server_ip="$serip"
echo "$server_ip" > /etc/s-box/server_ip.log
fi
fi
else
red "Sing-box服务未运行" && exit
fi
}

result_vl_hy2(){
server_ip=$(cat /etc/s-box/server_ip.log)
uuid=$(cat /etc/s-box/sb.json | jq -r '.inbounds[0].users[0].uuid')
vl_port=$(cat /etc/s-box/sb.json | jq -r '.inbounds[0].listen_port')
vl_name=$(cat /etc/s-box/sb.json | jq -r '.inbounds[0].tls.server_name')
public_key=$(cat /etc/s-box/public.key)
short_id=$(cat /etc/s-box/sb.json | jq -r '.inbounds[0].tls.reality.short_id[0]')
hy2_port=$(cat /etc/s-box/sb.json | jq -r '.inbounds[1].listen_port')
hy2_obfspwd=$(cat /etc/s-box/sb.json | jq -r '.inbounds[1].obfs.password // empty' 2>/dev/null)
if [[ -n $hy2_obfspwd ]]; then
hyobs="&obfs=salamander&obfs-password=$hy2_obfspwd"
else
hyobs=
fi
hy2_ports=$(for ipt in iptables ip6tables; do $ipt -t nat -nL SBHY2PORT --line 2>/dev/null | awk '/DNAT/{for(i=1;i<=NF;i++)if($i~/^dpts?:[0-9]/)print $i}'; done | sed 's/dpts://; s/dpt://' | awk '!a[$0]++' | tr '\n' ',' | sed 's/,$//')
if [[ -n $hy2_ports ]]; then
cmhy2pt=$(echo $hy2_ports | tr ':' '-')
hyps="&mport=$cmhy2pt"
else
hyps=
fi
hy2_certpath=$(cat /etc/s-box/sb.json | jq -r '.inbounds[1].tls.certificate_path' 2>/dev/null)
hy2_sniname=$(cat /etc/s-box/sb.json | jq -r '.inbounds[1].tls.key_path' 2>/dev/null)
hy2_name=$(openssl x509 -in "$hy2_certpath" -noout -text 2>/dev/null | grep -oE 'DNS:[^, ]+' | head -n 1 | sed 's/DNS://')
hy2_name=${hy2_name:-$(openssl x509 -in "$hy2_certpath" -noout -subject 2>/dev/null | sed 's/.*CN *= *//')}
hy2_name=${hy2_name#\*.}
SHA256=
if [[ "$hy2_certpath" = '/etc/s-box/cert.pem' && "$hy2_sniname" = '/etc/s-box/private.key' ]]; then
SHA256=$(openssl x509 -in "$hy2_certpath" -outform DER 2>/dev/null | sha256sum | awk '{print $1}')
echo "$SHA256" > /etc/s-box/SHA256.txt
SHA256=$(cat /etc/s-box/SHA256.txt)
sb_hy2_ip=$server_ip
else
sb_hy2_ip=${hy2_name:-$server_ip}
fi
hy2_name=${hy2_name:-www.bing.com}
}

resvless(){
echo
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
vl_link="vless://$uuid@$server_ip:$vl_port?encryption=none&flow=xtls-rprx-vision&security=reality&sni=$vl_name&fp=firefox&pbk=$public_key&sid=$short_id&type=tcp&headerType=none#$sbnode"
echo "$vl_link" > /etc/s-box/vl_reality.txt
red "🚀【 vless-reality-vision 】节点信息如下：" && sleep 2
echo
echo "分享链接【v2ran(切换singbox内核)、nekobox、小火箭shadowrocket】"
echo -e "${yellow}$vl_link${plain}"
echo
echo "二维码【v2ran(切换singbox内核)、nekobox、小火箭shadowrocket】"
qrencode -o - -t ANSIUTF8 "$(cat /etc/s-box/vl_reality.txt)"
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo
}

reshy2(){
echo
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
hy2_link="hysteria2://$uuid@$sb_hy2_ip:$hy2_port?security=tls&alpn=h3&insecure=0&allowInsecure=0$hyps$hyobs&sni=$hy2_name${SHA256:+&pinSHA256=$SHA256}#$sbnode"
echo "$hy2_link" > /etc/s-box/hy2.txt
red "🚀【 Hysteria-2 】节点信息如下：" && sleep 2
echo
echo "分享链接【v2rayn、v2rayng、nekobox、小火箭shadowrocket】"
echo -e "${yellow}$hy2_link${plain}"
echo
echo "二维码【v2rayn、v2rayng、nekobox、小火箭shadowrocket】"
qrencode -o - -t ANSIUTF8 "$(cat /etc/s-box/hy2.txt)"
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo
}

instsllsingbox(){
if [[ -f '/etc/systemd/system/sing-box.service' ]]; then
red "已安装Sing-box服务，无法再次安装" && exit
fi
mkdir -p /etc/s-box
v6
inssb
inscertificate
insport
insname
sleep 2
echo
blue "Vless-reality相关key与id将自动生成……"
key_pair=$(/etc/s-box/sing-box generate reality-keypair)
private_key=$(echo "$key_pair" | awk '/PrivateKey/ {print $2}' | tr -d '"')
public_key=$(echo "$key_pair" | awk '/PublicKey/ {print $2}' | tr -d '"')
echo "$public_key" > /etc/s-box/public.key
short_id=$(/etc/s-box/sing-box generate rand --hex 4)
warpwg
inssbjsonser
sbservice
sbactive
newv=$(curl -fsSL https://raw.githubusercontent.com/jasper-khan/sing-box-yg/main/version | awk -F "更新内容" '{print $1}' | head -n 1)
[[ -n $newv ]] && echo "$newv" > /etc/s-box/v
red "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
lnsb && blue "Sing-box-yg脚本安装成功，脚本快捷方式：sb" && cronsb
echo
ipuuid
sbshare
red "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
blue "可选择8，刷新并显示分享链接"
red "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo
}

setcert(){
certc_now=$(cat /etc/s-box/sb.json | jq -r '.inbounds[1].tls.certificate_path' 2>/dev/null)
certp_now=$(cat /etc/s-box/sb.json | jq -r '.inbounds[1].tls.key_path' 2>/dev/null)
echo
blue "当前证书：${certc_now:-未知}"
blue "当前私钥：${certp_now:-未知}"
echo
readp "输入证书文件路径 (回车保持当前)：" certc_new
readp "输入私钥文件路径 (回车保持当前)：" certp_new
certc_new=${certc_new:-$certc_now}
certp_new=${certp_new:-$certp_now}
if [[ ! -f $certc_new || ! -f $certp_new ]]; then
red "证书或私钥文件不存在，未做修改" && sleep 3 && sb
return
fi
for f in $sbfiles; do
jq --arg c "$certc_new" --arg k "$certp_new" '(.inbounds[1].tls.certificate_path) = $c | (.inbounds[1].tls.key_path) = $k' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
done
restartsb && sbshare > /dev/null 2>&1
green "Hysteria2证书路径已更新：$certc_new"
sleep 3 && sb
}

setname(){
green "当前节点名称：$sbnode"
readp "输入新的节点名称（回车保持当前，输入0恢复默认主机名）：" menu
if [ -z "$menu" ]; then
sb
elif [ "$menu" = "0" ]; then
rm -f /etc/s-box/nodename.log
sbnode=$(hostname)
sbshare > /dev/null 2>&1
green "节点名称已恢复默认主机名：$sbnode"
sleep 2 && sb
else
menu=$(printf '%s' "$menu" | tr -d '\r\n#')
if [ -z "$menu" ]; then
red "节点名称无效" && sleep 2 && sb
else
printf '%s\n' "$menu" > /etc/s-box/nodename.log
sbnode=$menu
sbshare > /dev/null 2>&1
green "节点名称已更新：$sbnode"
sleep 2 && sb
fi
fi
}

changeym(){
echo
vl_na="当前伪装域名：$(cat /etc/s-box/sb.json | jq -r '.inbounds[0].tls.server_name')"
green "$vl_na"
readp "请输入新的Reality伪装域名 (回车使用foothill.edu)：" ym_vl_re
ym_vl_re=${ym_vl_re:-foothill.edu}
for f in $sbfiles; do
jq --arg v "$ym_vl_re" '(.inbounds[0].tls.server_name) = $v | (.inbounds[0].tls.reality.handshake.server) = $v' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
done
restartsb && sbshare > /dev/null 2>&1
blue "Vless-reality伪装域名已更换为：$ym_vl_re"
sleep 3 && sb
}
allports(){
vl_port=$(cat /etc/s-box/sb.json | jq -r '.inbounds[0].listen_port')
hy2_port=$(cat /etc/s-box/sb.json | jq -r '.inbounds[1].listen_port')
hy2_ports=$(for ipt in iptables ip6tables; do $ipt -t nat -nL SBHY2PORT --line 2>/dev/null | awk '/DNAT/{for(i=1;i<=NF;i++)if($i~/^dpts?:[0-9]/)print $i}'; done | sed 's/dpts://; s/dpt://' | awk '!a[$0]++' | tr '\n' ',' | sed 's/,$//')
[[ -n $hy2_ports ]] && hy2zfport="$hy2_ports" || hy2zfport="未添加"
}

sbportjump(){
hy2p=$(cat /etc/s-box/sb.json 2>/dev/null | jq -r '.inbounds[1].listen_port' 2>/dev/null)
if [[ -n $hy2p && $hy2p =~ ^[0-9]+$ ]]; then
for ipt in iptables ip6tables; do
while $ipt -t nat -nL PREROUTING --line 2>/dev/null | awk -v p=":$hy2p" '/DNAT/{for(i=1;i<=NF;i++)if(substr($i,length($i)-length(p)+1)==p && $1+0>0){print $1;exit}}' | grep -q .; do
$ipt -t nat -D PREROUTING "$($ipt -t nat -nL PREROUTING --line 2>/dev/null | awk -v p=":$hy2p" '/DNAT/{for(i=1;i<=NF;i++)if(substr($i,length($i)-length(p)+1)==p && $1+0>0){print $1;exit}}')" 2>/dev/null || break
done
done
fi
iptables -t nat -N SBHY2PORT 2>/dev/null
iptables -t nat -C PREROUTING -j SBHY2PORT 2>/dev/null || iptables -t nat -I PREROUTING -j SBHY2PORT
ip6tables -t nat -N SBHY2PORT 2>/dev/null
ip6tables -t nat -C PREROUTING -j SBHY2PORT 2>/dev/null || ip6tables -t nat -I PREROUTING -j SBHY2PORT
}

changeport(){
sbactive
allports
fports(){
readp "\n请输入转发的端口范围 (1000-65535范围内，格式为 小数字:大数字)：" rangeport
if [[ $rangeport =~ ^([1-9][0-9]{3,4}:[1-9][0-9]{3,4})$ ]]; then
b=${rangeport%%:*}
c=${rangeport##*:}
if [[ $b -ge 1000 && $b -le 65535 && $c -ge 1000 && $c -le 65535 && $b -lt $c ]]; then
sbportjump
iptables -t nat -A SBHY2PORT -p udp --dport $rangeport -j DNAT --to-destination :$port
ip6tables -t nat -A SBHY2PORT -p udp --dport $rangeport -j DNAT --to-destination :$port
netfilter-persistent save >/dev/null 2>&1
service iptables save >/dev/null 2>&1
blue "已确认转发的端口范围：$rangeport"
else
red "输入的端口范围不在有效范围内" && fports
fi
else
red "输入格式不正确。格式为 小数字:大数字" && fports
fi
echo
}
fport(){
readp "\n请输入一个转发的端口 (1000-65535范围内)：" onlyport
if [[ $onlyport =~ ^[0-9]+$ && $onlyport -ge 1000 && $onlyport -le 65535 ]]; then
sbportjump
iptables -t nat -A SBHY2PORT -p udp --dport $onlyport -j DNAT --to-destination :$port
ip6tables -t nat -A SBHY2PORT -p udp --dport $onlyport -j DNAT --to-destination :$port
netfilter-persistent save >/dev/null 2>&1
service iptables save >/dev/null 2>&1
blue "已确认转发的端口：$onlyport"
else
blue "输入的端口不在有效范围内" && fport
fi
echo
}

hy2deports(){
allports
hy2_ports=$(echo "$hy2_ports" | sed 's/,/,/g')
IFS=',' read -ra ports <<< "$hy2_ports"
for port in "${ports[@]}"; do
iptables -t nat -D SBHY2PORT -p udp --dport $port -j DNAT --to-destination :$hy2_port
ip6tables -t nat -D SBHY2PORT -p udp --dport $port -j DNAT --to-destination :$hy2_port
done
netfilter-persistent save >/dev/null 2>&1
service iptables save >/dev/null 2>&1
}

allports
green "Vless-reality仅能更改唯一的端口"
green "Hysteria2支持更改主端口，也支持增删多个转发端口与端口跳跃"
echo
green "1：Vless-reality协议 ${yellow}端口:$vl_port${plain}"
green "2：Hysteria2协议 ${yellow}端口:$hy2_port  转发多端口: $hy2zfport${plain}"
green "0：返回上层"
readp "请选择要变更端口的协议：" menu
if [ "$menu" = "1" ]; then
vlport
for f in $sbfiles; do
jq --argjson p "$port_vl_re" '(.inbounds[0].listen_port) = $p' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
done
restartsb && sbshare > /dev/null 2>&1
blue "Vless-reality端口更改完成"
echo
elif [ "$menu" = "2" ]; then
green "1：更换Hysteria2主端口 (原多端口自动重置删除)"
green "2：添加Hysteria2多端口"
green "3：重置删除Hysteria2多端口"
green "0：返回上层"
readp "请选择【0-3】：" menu
if [ "$menu" = "1" ]; then
if [ -n "$hy2_ports" ]; then
hy2deports
hy2port
for f in $sbfiles; do
jq --argjson p "$port_hy2" '(.inbounds[1].listen_port) = $p' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
done
restartsb && sbshare > /dev/null 2>&1
else
hy2port
for f in $sbfiles; do
jq --argjson p "$port_hy2" '(.inbounds[1].listen_port) = $p' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
done
restartsb && sbshare > /dev/null 2>&1
fi
blue "Hysteria2端口更改完成"
elif [ "$menu" = "2" ]; then
green "1：添加Hysteria2范围端口"
green "2：添加Hysteria2单端口"
green "0：返回上层"
readp "请选择【0-2】：" menu
port=$(cat /etc/s-box/sb.json | jq -r '.inbounds[1].listen_port')
if [ "$menu" = "1" ]; then
fports && sbshare > /dev/null 2>&1 && changeport
elif [ "$menu" = "2" ]; then
fport && sbshare > /dev/null 2>&1 && changeport
else
changeport
fi
elif [ "$menu" = "3" ]; then
if [ -n "$hy2_ports" ]; then
hy2deports && sbshare > /dev/null 2>&1 yellow "Hysteria2多端口已删除" && changeport
else
sbshare > /dev/null 2>&1 && yellow "Hysteria2未设置多端口" && changeport
fi
else
changeport
fi
else
sb
fi
}

changeuuid(){
echo
olduuid=$(cat /etc/s-box/sb.json | jq -r '.inbounds[0].users[0].uuid')
green "全协议的uuid (密码)：$olduuid"
echo
yellow "1：自定义全协议的uuid (密码)"
yellow "0：返回上层"
readp "请选择【0-1】：" menu
if [ "$menu" = "1" ]; then
readp "输入uuid，必须是uuid格式，不懂就回车(重置并随机生成uuid)：" menu
if [ -z "$menu" ]; then
uuid=$(/etc/s-box/sing-box generate uuid)
elif [[ "$menu" =~ ^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$ ]]; then
uuid=$menu
else
red "uuid 格式不正确，未做修改" && sleep 3 && return
fi
for f in $sbfiles; do
jq --arg u "$uuid" '(.inbounds[0].users[0].uuid) = $u | (.inbounds[1].users[0].password) = $u' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
done
restartsb && sbshare > /dev/null 2>&1
blue "已确认uuid (密码)：${uuid}"
else
changeserv
fi
}

changeip(){
if [[ "$sbnh" == "1.10" ]]; then
v4v6
chip(){
jq --arg v "$rrpip" '(.outbounds[0].domain_strategy) = $v' /etc/s-box/sb10.json > /etc/s-box/sb10.json.tmp && mv /etc/s-box/sb10.json.tmp /etc/s-box/sb10.json
cp /etc/s-box/sb10.json /etc/s-box/sb.json
restartsb
}
readp "1. IPV4优先\n2. IPV6优先\n3. 仅IPV4\n4. 仅IPV6\n请选择：" choose
if [[ $choose == "1" && -n $v4 ]]; then
rrpip="prefer_ipv4" && chip && v4_6="IPV4优先($v4)"
elif [[ $choose == "2" && -n $v6 ]]; then
rrpip="prefer_ipv6" && chip && v4_6="IPV6优先($v6)"
elif [[ $choose == "3" && -n $v4 ]]; then
rrpip="ipv4_only" && chip && v4_6="仅IPV4($v4)"
elif [[ $choose == "4" && -n $v6 ]]; then
rrpip="ipv6_only" && chip && v4_6="仅IPV6($v6)"
else 
red "当前不存在你选择的IPV4/IPV6地址，或者输入错误" && changeip
fi
blue "当前已更换的IP优先级：${v4_6}" && sb
else
red "仅支持1.10.7内核可用" && exit
fi
}

defobfs(){
newpw=$(openssl rand -hex 16)
for f in $sbfiles; do
[[ -f $f ]] || continue
jq --arg pw "$newpw" '(.inbounds[1].obfs) = {"type":"salamander","password":$pw}' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
done
}

setobfs(){
sbactive
obfs_now=$(cat /etc/s-box/sb.json | jq -r '.inbounds[1].obfs.password // empty' 2>/dev/null)
echo
blue "Hy2混淆（salamander）：把 hy2 流量打乱成随机特征，用于应对专门识别/掐 QUIC 的网络环境"
if [[ -n $obfs_now ]]; then
green "当前状态：已开启"
else
yellow "当前状态：未开启（默认）"
fi
readp "1：开启/重置混淆密码（随机生成）\n2：关闭混淆\n0：返回上层\n请选择【0-2】：" menu
if [ "$menu" = "1" ]; then
defobfs
restartsb && sbshare > /dev/null 2>&1
green "Hy2混淆已开启，分享链接已刷新（客户端请重新导入节点）" && sleep 2 && sb
elif [ "$menu" = "2" ]; then
for f in $sbfiles; do
jq 'del(.inbounds[1].obfs)' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
done
restartsb && sbshare > /dev/null 2>&1
green "Hy2混淆已关闭，分享链接已刷新" && sleep 2 && sb
else
sb
fi
}

changefl(){
if [[ "$sbnh" == "1.10" ]]; then fli=(1 2 3 4); flb=5; else fli=(1 3 5 7); flb=9; fi
fln=("WARP-WireGuard-IPv4优先" "WARP-WireGuard-IPv6优先" "VPS本地-IPv4优先" "VPS本地-IPv6优先")
echo
blue "对所有协议进行统一的域名分流 (后缀域名方式，双栈优先模式)"
green "当前分流域名如下："
for i in 0 1 2 3; do
flnow=$(cat /etc/s-box/sb.json | jq -r ".route.rules[${fli[$i]}].domain_suffix | join(\" \")" 2>/dev/null)
[[ -z $flnow || $flnow = "yg_kkk" ]] && flnow="未分流"
blue "$((i+1))：${fln[$i]}：$flnow"
done
flog=$(cat /etc/s-box/sb.json | jq -r ".route.rules[$flb].outbound" 2>/dev/null)
case "$flog" in
warp-out|warp-IPv4-out|warp-IPv6-out) flog="全局走 Cloudflare WARP" ;;
*) flog="全局走 VPS 直连 (默认)" ;;
esac
blue "5：其余流量出口：$flog"
echo
yellow "1-4：给指定域名选通道，多个域名之间留空格 (例：netflix.com openai.com)，回车表示重置为不分流"
yellow "5：设置上面 4 个通道都没匹配到的域名走哪里 (全局 WARP / 全局直连)"
readp "请选择【1-5】，回车返回上层：" menu
if [ "$menu" = "5" ]; then
echo
green "当前其余流量出口：$flog"
readp "1：其余流量走 Cloudflare WARP\n2：其余流量走 VPS 直连 (默认)\n0：返回上层\n请选择【0-2】：" gmen
case "$gmen" in
1) gw11="warp-out"; gw10="warp-IPv4-out"; gwnow="全局走 Cloudflare WARP" ;;
2) gw11="direct"; gw10="direct"; gwnow="全局走 VPS 直连" ;;
*) changefl; return ;;
esac
for f in $sbfiles; do
case "$f" in
*/sb10.json) gi=5; gv=$gw10 ;;
*/sb11.json) gi=9; gv=$gw11 ;;
*/sb.json) if [[ "$sbnh" == "1.10" ]]; then gi=5; gv=$gw10; else gi=9; gv=$gw11; fi ;;
esac
jq --arg v "$gv" --argjson i "$gi" '(.route.rules[$i].outbound) = $v' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
done
restartsb && sbshare > /dev/null 2>&1
green "其余流量出口已设置为：$gwnow"
sleep 2 && changefl
return
fi
if [[ ! "$menu" =~ ^[1-4]$ ]]; then
changeserv
return
fi
readp "请输入域名：" fl
if [ -z "$fl" ]; then
fl='["yg_kkk"]'
else
fl=$(printf '%s' "$fl" | tr -s ' \t' ' ' | sed 's/^ //;s/ $//;s/ /","/g')
fl="[\"$fl\"]"
fi
if ! printf '%s' "$fl" | jq -e 'type == "array"' >/dev/null 2>&1; then
red "域名格式有误，未做修改" && sleep 3 && changefl
return
fi
for f in $sbfiles; do
case "$f" in
*/sb10.json) i1=$menu; i2=$menu ;;
*/sb11.json) i1=$((2*menu-1)); i2=$((2*menu)) ;;
*/sb.json) if [[ "$sbnh" == "1.10" ]]; then i1=$menu; i2=$menu; else i1=$((2*menu-1)); i2=$((2*menu)); fi ;;
esac
jq --argjson v "$fl" --argjson a "$i1" --argjson b "$i2" '(.route.rules[$a].domain_suffix) = $v | (.route.rules[$b].domain_suffix) = $v' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
done
restartsb && sbshare > /dev/null 2>&1
green "分流域名已设置为：$fl"
sleep 2 && changefl
}

changeserv(){
sbactive
echo
green "Sing-box配置变更选择如下:"
readp "1：设置Hysteria2证书路径（自己申请的证书）\n2：设置节点名称\n3：更换Reality域名伪装地址\n4：更换全协议UUID(密码)\n5：切换IPV4或IPV6的代理优先级 (仅 1.10.7 内核可用)\n6：设置域名分流（WARP-WireGuard / VPS直连）\n7：设置Hy2混淆（salamander，防QUIC特征被识别）\n0：返回上层\n请选择【0-7】：" menu
if [ "$menu" = "1" ];then
setcert
elif [ "$menu" = "2" ];then
setname
elif [ "$menu" = "3" ];then
changeym
elif [ "$menu" = "4" ];then
changeuuid
elif [ "$menu" = "5" ];then
changeip
elif [ "$menu" = "6" ];then
changefl
elif [ "$menu" = "7" ];then
setobfs
else 
sb
fi
}

restartsb(){
if command -v apk >/dev/null 2>&1; then
rc-service sing-box restart
else
systemctl enable sing-box
systemctl start sing-box
systemctl restart sing-box
fi
}

stclre(){
if [[ ! -f '/etc/s-box/sb.json' ]]; then
red "未正常安装Sing-box" && exit
fi
readp "1：重启\n2：关闭\n请选择：" menu
if [ "$menu" = "1" ]; then
restartsb
sbactive
green "Sing-box服务已重启\n" && sleep 3 && sb
elif [ "$menu" = "2" ]; then
if command -v apk >/dev/null 2>&1; then
rc-service sing-box stop
else
systemctl stop sing-box
systemctl disable sing-box
fi
green "Sing-box服务已关闭\n" && sleep 3 && sb
else
stclre
fi
}

cronsb(){
uncronsb
tmpct=$(mktemp) || { red "创建临时文件失败"; return 1; }
crontab -l 2>/dev/null > "$tmpct"
echo "0 1 * * * systemctl restart sing-box;rc-service sing-box restart" >> "$tmpct"
crontab "$tmpct" >/dev/null 2>&1
rm -f "$tmpct"
}
uncronsb(){
tmpct=$(mktemp) || { red "创建临时文件失败"; return 1; }
crontab -l 2>/dev/null > "$tmpct"
sed -i '/sing-box/d' "$tmpct"
crontab "$tmpct" >/dev/null 2>&1
rm -f "$tmpct"
}

lnsb(){
tmpsb=$(mktemp /usr/bin/sb.new.XXXXXX) || { red "创建临时文件失败"; return 1; }
if curl -L --fail --proto '=https' --retry 2 -# -o "$tmpsb" https://raw.githubusercontent.com/jasper-khan/sing-box-yg/main/sb.sh && bash -n "$tmpsb"; then
chmod +x "$tmpsb"
mv -f "$tmpsb" /usr/bin/sb
else
rm -f "$tmpsb"
red "下载脚本失败或语法校验不通过，已保留原有脚本" && return 1
fi
}

upsbyg(){
if [[ ! -f '/usr/bin/sb' ]]; then
red "未正常安装Sing-box-yg" && exit
fi
if lnsb; then
newv=$(curl -fsSL https://raw.githubusercontent.com/jasper-khan/sing-box-yg/main/version | awk -F "更新内容" '{print $1}' | head -n 1)
[[ -n $newv ]] && echo "$newv" > /etc/s-box/v
green "Sing-box-yg安装脚本升级成功" && sleep 5 && sb
else
red "更新失败，已保留原有脚本" && sleep 3 && sb
fi
}

lapre(){
json=$(curl -Ls --max-time 3 https://data.jsdelivr.com/v1/package/gh/SagerNet/sing-box)
if echo "$json"|grep -q '"versions"'; then
latcore=$(echo "$json"|grep -Eo '"[0-9.]+",'|head -n1|tr -d '",')
precore=$(echo "$json"|grep -Eo '"[0-9.]*-[^"]*"'|head -n1|tr -d '",')
else
page=$(curl -Ls --max-time 3 https://github.com/SagerNet/sing-box/releases)
latcore=$(echo "$page"|grep -oE 'tag/v[0-9.]+'|head -n1|cut -d'v' -f2)
precore=$(echo "$page"|grep -oE '/tag/v[0-9.]+-[^"]+'|head -n1|cut -d'v' -f2)
fi
inscore=$(/etc/s-box/sing-box version 2>/dev/null | awk '/version/{print $NF}')
}

upsbcroe(){
sbactive
lapre
[[ $inscore =~ ^[0-9.]+$ ]] && lat="【已安装v$inscore】" || pre="【已安装v$inscore】"
green "1：升级/切换Sing-box最新正式版 v$latcore  ${bblue}${lat}${plain}"
green "2：升级/切换Sing-box最新测试版 v$precore  ${bblue}${pre}${plain}"
green "3：切换Sing-box某个正式版或测试版，需指定版本号 (建议1.10.0以上版本)"
green "0：返回上层"
readp "请选择【0-3】：" menu
if [ "$menu" = "1" ]; then
upcore=$(curl -Ls https://github.com/SagerNet/sing-box/releases/latest | grep -oP 'tag/v\K[0-9.]+' | head -n 1)
elif [ "$menu" = "2" ]; then
upcore=$(curl -Ls https://github.com/SagerNet/sing-box/releases | grep -oP '/tag/v\K[0-9.]+-[^"]+' | head -n 1)
elif [ "$menu" = "3" ]; then
echo
red "注意: 版本号在 https://github.com/SagerNet/sing-box/tags 可查，且有Downloads字样 (必须1.10系或者1.30系以上版本)"
green "正式版版本号格式：数字.数字.数字 (例：1.10.7   注意，1.10系列内核与1.10以上内核的分流配置格式不同"
green "测试版版本号格式：数字.数字.数字-alpha或rc或beta.数字 (例：1.13.0-alpha或rc或beta.1)"
readp "请输入Sing-box版本号：" upcore
else
sb
fi
if [[ -n $upcore ]]; then
green "开始下载并更新Sing-box内核……请稍等"
sbname="sing-box-$upcore-linux-$cpu"
rm -rf /etc/s-box/sing-box.tar.gz /etc/s-box/$sbname
if curl -L --fail -o /etc/s-box/sing-box.tar.gz -# --retry 2 https://github.com/SagerNet/sing-box/releases/download/v$upcore/$sbname.tar.gz && tar xzf /etc/s-box/sing-box.tar.gz -C /etc/s-box && chmod +x /etc/s-box/$sbname/sing-box 2>/dev/null && [[ $(/etc/s-box/$sbname/sing-box version 2>/dev/null | awk '/version/{print $NF}') == "$upcore" ]]; then
chown root:root /etc/s-box/$sbname/sing-box
chmod +x /etc/s-box/$sbname/sing-box
mv -f /etc/s-box/$sbname/sing-box /etc/s-box/sing-box
rm -rf /etc/s-box/sing-box.tar.gz /etc/s-box/$sbname
sbnh=$(/etc/s-box/sing-box version 2>/dev/null | awk '/version/{print $NF}' 2>/dev/null | cut -d '.' -f 1,2)
[[ "$sbnh" == "1.10" ]] && num=10 || num=11
if [[ -f /etc/s-box/sb${num}.json ]]; then
cp -f /etc/s-box/sb${num}.json /etc/s-box/sb.json
restartsb && sbshare > /dev/null 2>&1
else
red "未找到 /etc/s-box/sb${num}.json，配置未切换，请重装脚本" && sleep 3
fi
blue "成功升级/切换 Sing-box 内核版本：$(/etc/s-box/sing-box version | awk '/version/{print $NF}')" && sleep 3 && sb
else
rm -rf /etc/s-box/sing-box.tar.gz /etc/s-box/$sbname
red "下载、解包或校验 Sing-box 内核失败，已保留原内核，请重试" && upsbcroe
fi
else
red "版本号检测出错，请重试" && upsbcroe
fi
}

unins(){
if command -v apk >/dev/null 2>&1; then
rc-service sing-box stop >/dev/null 2>&1
rc-update del sing-box default >/dev/null 2>&1
rm -f /etc/init.d/sing-box
else
systemctl stop sing-box >/dev/null 2>&1
systemctl disable sing-box >/dev/null 2>&1
rm -f /etc/systemd/system/sing-box.service
fi
rm -rf /etc/s-box sbyg_update /usr/bin/sb
uncronsb
for ipt in iptables ip6tables; do
$ipt -t nat -D PREROUTING -j SBHY2PORT >/dev/null 2>&1
$ipt -t nat -F SBHY2PORT >/dev/null 2>&1
$ipt -t nat -X SBHY2PORT >/dev/null 2>&1
done
netfilter-persistent save >/dev/null 2>&1
service iptables save >/dev/null 2>&1
green "Sing-box卸载完成！"
blue "欢迎继续使用Sing-box-yg脚本：bash <(curl -Ls https://raw.githubusercontent.com/jasper-khan/sing-box-yg/main/sb.sh)"
echo
}

sblog(){
red "退出日志 Ctrl+c"
if command -v apk >/dev/null 2>&1; then
yellow "暂不支持alpine查看日志"
else
#systemctl status sing-box
journalctl -u sing-box.service -o cat -f
fi
}

sbactive(){
if [[ ! -f /etc/s-box/sb.json ]]; then
red "未正常启动Sing-box，请卸载重装或者选择9查看运行日志反馈" && exit
fi
}

sbshare(){
rm -rf /etc/s-box/{jhdy,vl_reality,hy2}.txt
result_vl_hy2 && resvless && reshy2
cat /etc/s-box/vl_reality.txt 2>/dev/null >> /etc/s-box/jhdy.txt
cat /etc/s-box/hy2.txt 2>/dev/null >> /etc/s-box/jhdy.txt
v2sub=$(cat /etc/s-box/jhdy.txt 2>/dev/null)
echo
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
red "🚀【 聚合节点 】节点信息如下：" && sleep 2
echo
echo "分享链接"
echo -e "${yellow}$v2sub${plain}"
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo
}

clash_sb_share(){
sbactive
sbshare
}

bbr(){
if [[ $vi =~ lxc|openvz ]]; then
yellow "当前VPS的架构为 $vi，不支持开启原版BBR加速" && sleep 2 && exit 
else
green "点击任意键，即可开启BBR加速，ctrl+c退出"
bash <(curl -Ls https://raw.githubusercontent.com/teddysun/across/master/bbr.sh)
fi
}

showprotocol(){
allports
hy2_certpath=$(cat /etc/s-box/sb.json | jq -r '.inbounds[1].tls.certificate_path')
hy2_sniname=$(cat /etc/s-box/sb.json | jq -r '.inbounds[1].tls.key_path')
[[ "$hy2_certpath" = '/etc/s-box/cert.pem' && "$hy2_sniname" = '/etc/s-box/private.key' ]] && hy2_zs="自签证书" || hy2_zs="域名证书"
echo -e "Sing-box节点关键信息如下："
echo -e "🚀【 Vless-reality 】${yellow}端口:$vl_port  Reality域名证书伪装地址：$(cat /etc/s-box/sb.json | jq -r '.inbounds[0].tls.server_name')${plain}"
echo -e "🚀【  Hysteria-2   】${yellow}端口:$hy2_port  证书形式:$hy2_zs  转发多端口: $hy2zfport${plain}"
echo "------------------------------------------------------------------------------------"
}

sbsm(){
echo
blue "本 fork 仅保留 vless-reality 与 hysteria2 两个协议"
blue "项目地址与使用说明：https://github.com/jasper-khan/sing-box-yg"
echo
}

clear
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" 
white "Vless-reality-vision、Hysteria2 双协议共存脚本"
white "脚本快捷方式：sb"
red "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
green " 1. 一键安装 Sing-box" 
green " 2. 删除卸载 Sing-box"
white "----------------------------------------------------------------------------------"
green " 3. 变更配置 【证书/名称/域名/UUID/IP优先/分流】"
green " 4. 更改主端口/添加多端口跳跃复用" 
green " 5. 关闭/重启 Sing-box"
green " 6. 更新 Sing-box-yg 脚本"
green " 7. 更新/切换/指定 Sing-box 内核版本"
white "----------------------------------------------------------------------------------"
green " 8. 刷新并查看节点 【分享链接】"
green " 9. 查看 Sing-box 运行日志"
green "10. 一键原版BBR+FQ加速"
green "11. 填写Hysteria2证书路径"
green "12. 更换IP刷新本地IP、调整IPV4/IPV6配置输出"
white "----------------------------------------------------------------------------------"
green "13. Sing-box-yg脚本使用说明书"
white "----------------------------------------------------------------------------------"
green " 0. 退出脚本"
red "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
insV=$(cat /etc/s-box/v 2>/dev/null)
latestV=$(curl -sL https://raw.githubusercontent.com/jasper-khan/sing-box-yg/main/version | awk -F "更新内容" '{print $1}' | head -n 1)
if [ -f /etc/s-box/v ]; then
if [ "$insV" = "$latestV" ]; then
echo -e "当前 Sing-box-yg 脚本最新版：${bblue}${insV}${plain} (已安装)"
else
echo -e "当前 Sing-box-yg 脚本版本号：${bblue}${insV}${plain}"
echo -e "检测到最新 Sing-box-yg 脚本版本号：${yellow}${latestV}${plain} (可选择6进行更新)"
echo -e "${yellow}$(curl -sL https://raw.githubusercontent.com/jasper-khan/sing-box-yg/main/version)${plain}"
fi
else
echo -e "当前 Sing-box-yg 脚本版本号：${bblue}${latestV}${plain}"
yellow "未安装 Sing-box-yg 脚本！请先选择 1 安装"
fi

lapre
if [ -f '/etc/s-box/sb.json' ]; then
if [[ $inscore =~ ^[0-9.]+$ ]]; then
if [ "${inscore}" = "${latcore}" ]; then
echo
echo -e "当前 Sing-box 最新正式版内核：${bblue}${inscore}${plain} (已安装)"
echo
echo -e "当前 Sing-box 最新测试版内核：${bblue}${precore}${plain} (可切换)"
else
echo
echo -e "当前 Sing-box 已安装正式版内核：${bblue}${inscore}${plain}"
echo -e "检测到最新 Sing-box 正式版内核：${yellow}${latcore}${plain} (可选择7进行更新)"
echo
echo -e "当前 Sing-box 最新测试版内核：${bblue}${precore}${plain} (可切换)"
fi
else
if [ "${inscore}" = "${precore}" ]; then
echo
echo -e "当前 Sing-box 最新测试版内核：${bblue}${inscore}${plain} (已安装)"
echo
echo -e "当前 Sing-box 最新正式版内核：${bblue}${latcore}${plain} (可切换)"
else
echo
echo -e "当前 Sing-box 已安装测试版内核：${bblue}${inscore}${plain}"
echo -e "检测到最新 Sing-box 测试版内核：${yellow}${precore}${plain} (可选择7进行更新)"
echo
echo -e "当前 Sing-box 最新正式版内核：${bblue}${latcore}${plain} (可切换)"
fi
fi
else
echo
echo -e "当前 Sing-box 最新正式版内核：${bblue}${latcore}${plain}"
echo -e "当前 Sing-box 最新测试版内核：${bblue}${precore}${plain}"
fi
red "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo -e "VPS状态如下："
echo -e "系统:$blue$op$plain  \c";echo -e "内核:$blue$version$plain  \c";echo -e "处理器:$blue$cpu$plain  \c";echo -e "虚拟化:$blue$vi$plain  \c";echo -e "BBR算法:$blue$bbr$plain"
v4v6
[[ -z $v4 ]] && showv4='IPV4地址丢失，请切换至IPV6或者重装Sing-box' || showv4=$v4
[[ -z $v6 ]] && showv6='IPV6地址丢失，请切换至IPV4或者重装Sing-box' || showv6=$v6
if [[ -z $v4 ]]; then
vps_ipv4='无IPV4'      
vps_ipv6="$v6"
location="$v6dq"
elif [[ -n $v4 &&  -n $v6 ]]; then
vps_ipv4="$v4"    
vps_ipv6="$v6"
location="$v4dq"
else
vps_ipv4="$v4"    
vps_ipv6='无IPV6'
location="$v4dq"
fi
echo -e "本地IPV4地址：$blue$vps_ipv4$plain   本地IPV6地址：$blue$vps_ipv6$plain"
echo -e "服务器地区：$blue$location$plain"
if [[ "$sbnh" == "1.10" ]]; then
rpip=$(cat /etc/s-box/sb.json | jq -r '.outbounds[0].domain_strategy') 2>/dev/null
if [[ $rpip = 'prefer_ipv6' ]]; then
v4_6="IPV6优先出站($showv6)"
elif [[ $rpip = 'prefer_ipv4' ]]; then
v4_6="IPV4优先出站($showv4)"
elif [[ $rpip = 'ipv4_only' ]]; then
v4_6="仅IPV4出站($showv4)"
elif [[ $rpip = 'ipv6_only' ]]; then
v4_6="仅IPV6出站($showv6)"
fi
echo -e "代理IP优先级：$blue$v4_6$plain"
fi
if command -v apk >/dev/null 2>&1; then
status_cmd="rc-service sing-box status"
status_pattern="started"
else
status_cmd="systemctl is-active sing-box"
status_pattern="active"
fi
if [[ -n $($status_cmd 2>/dev/null | grep -w "$status_pattern") && -f '/etc/s-box/sb.json' ]]; then
echo -e "Sing-box状态：$blue运行中$plain"
elif [[ -z $($status_cmd 2>/dev/null | grep -w "$status_pattern") && -f '/etc/s-box/sb.json' ]]; then
echo -e "Sing-box状态：$yellow未启动，选择9查看日志并反馈，建议切换正式版内核或卸载重装脚本$plain"
else
echo -e "Sing-box状态：$red未安装$plain"
fi
red "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
if [ -f '/etc/s-box/sb.json' ]; then
showprotocol
fi
red "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo
readp "请输入数字【0-13】:" Input
case "$Input" in  
 1 ) instsllsingbox;;
 2 ) unins;;
 3 ) changeserv;;
 4 ) changeport;;
 5 ) stclre;;
 6 ) upsbyg;;
 7 ) upsbcroe;;
 8 ) clash_sb_share;;
 9 ) sblog;;
 10 ) bbr;;
 11 ) setcert;;
 12 ) ipuuid && sbshare;;
 13 ) sbsm;;
  * ) exit
esac
