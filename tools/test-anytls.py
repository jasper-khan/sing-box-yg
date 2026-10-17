"""Exercise the script's actual jq filters; requires jq on PATH."""
import copy
import json
import re
import shutil
import subprocess
from pathlib import Path
from urllib.parse import parse_qs, unquote, urlsplit

source = (Path(__file__).resolve().parents[1] / "sb.sh").read_text(encoding="utf-8")


def body(name):
    return re.search(r"(?ms)^" + name + r"\(\)\{\n(.*?)^\}", source)[1]


def filter_in(name, marker):
    return body(name).split(marker, 1)[1].split("'", 1)[0]


def jq(data, expression, **args):
    command = ["jq"]
    for key, value in args.items():
        command += ["--argjson", key, json.dumps(value)]
    result = subprocess.run(command + [expression], input=json.dumps(data),
                            text=True, encoding="utf-8", capture_output=True, check=True)
    return json.loads(result.stdout)


add = filter_in("addanytls", "--argjson p \"$port\" '")
domain = filter_in("setym", "--arg v \"$ym_vl_re\" '")
password = filter_in("changeuuid", "--arg u \"$uuid\" '")
port = source.split("changeport(){", 1)[1].split("--argjson p \"$port\" '", 1)[1].split("'", 1)[0]
export = filter_in("resanytls", "--arg name \"$sbnode\" '")
chain = source.split("--slurpfile public \"$backup/outbound.json\" '", 1)[1].split("'", 1)[0]

base = {
    "inbounds": [
        {"type": "vless", "tag": "vless-sb", "listen": "::", "listen_port": 10443,
         "users": [{"uuid": "11111111-1111-4111-8111-111111111111", "flow": "xtls-rprx-vision"}],
         "tls": {"enabled": True, "server_name": "apple.com", "reality": {
             "enabled": True, "handshake": {"server": "apple.com", "server_port": 443},
             "private_key": "server-secret", "short_id": ["01234567"]}}},
        {"type": "hysteria2", "tag": "hy2-sb", "listen_port": 10444,
         "users": [{"password": "old"}], "masquerade": "https://apple.com"}
    ],
    "outbounds": [{"type": "direct", "tag": "direct"}],
    "route": {"rules": []}
}

# Both ordinary installs and existing LAN/public chains keep their original nodes.
for target in (None, "lan-ss-out", "public-vless-out"):
    original = copy.deepcopy(base)
    if target:
        original["inbounds"].append({"type": "shadowsocks", "tag": "lan-ss-in"})
        original["route"]["rules"] = [{"inbound": ["vless-sb", "hy2-sb"], "outbound": target}]
    result = jq(original, add, p=10445)
    assert result["inbounds"][:-1] == original["inbounds"]
    node = result["inbounds"][-1]
    assert node["type"] == "anytls" and node["listen_port"] == 10445
    assert node["tls"] == original["inbounds"][0]["tls"]
    assert node["users"][0]["password"] == original["inbounds"][0]["users"][0]["uuid"]
    if target:
        assert result["route"]["rules"][0]["inbound"] == ["vless-sb", "hy2-sb", "anytls-sb"]
    chained = jq(result, chain, role="relay", host="192.168.1.2", port=12345, public=[{}])
    assert chained["route"]["rules"][0]["inbound"] == ["vless-sb", "hy2-sb", "anytls-sb"]
    assert jq(result, port, p=10446)["inbounds"][-1]["listen_port"] == 10446

    updated = jq(jq(result, domain, v="www.tnm.jp"), password, u="new-password")
    assert updated["inbounds"][-1]["tls"] == updated["inbounds"][0]["tls"]
    assert updated["inbounds"][1]["masquerade"] == "https://www.tnm.jp"
    assert updated["inbounds"][-1]["users"][0]["password"] == "new-password"
    for address in ("192.0.2.1", "[2001:db8::1]"):
        link = jq(updated, export, server=address, key="public-key", name='My node 东京 "test" & + %')
        uri = urlsplit(link)
        assert uri.scheme == "anytls" and uri.hostname == address.strip("[]") and uri.port == 10445
        assert unquote(uri.username) == "new-password"
        assert parse_qs(uri.query) == {"security": ["reality"], "sni": ["www.tnm.jp"],
                                       "fp": ["firefox"], "pbk": ["public-key"], "sid": ["01234567"]}
        assert unquote(uri.fragment) == 'My node 东京 "test" & + %'
        assert "private_key" not in link and "server-secret" not in link

# Editing an old two-protocol configuration must not create an incomplete inbound.
legacy = jq(jq(base, domain, v="www.tnm.jp"), password, u="new-password")
assert len(legacy["inbounds"]) == 2
assert legacy["inbounds"][0]["users"][0]["uuid"] == legacy["inbounds"][1]["users"][0]["password"]
print("AnyTLS add, chain, updates and client export: OK")

# Run the real allocation flow with simulated listeners, without touching /etc.
functions = "\n".join(name + "(){\n" + body(name) + "\n}" for name in
                      ("anytlsversion", "randomport", "insport"))
functions = functions.replace("/etc/s-box/sing-box", "testcore")
port_test = r'''
export PATH="/usr/bin:$PATH"
red(){ :; }; green(){ :; }; yellow(){ :; }; blue(){ :; }
testcore(){ echo 11111111-1111-4111-8111-111111111111; }
ss(){ echo 'tcp LISTEN 0 128 0.0.0.0:10001 0.0.0.0:*'; }
shuf(){ read -r next <&3; echo "$next"; }
choices=0
readchoice(){ choices=$((choices+1)); port=1; }
readp(){ echo 'Unexpected extra port prompt' >&2; exit 1; }
''' + functions + r'''
set -e
sbnh=1.14
exec 3< <(printf '%s\n' 10001 10002 10002 10003 10004)
insport >/dev/null
[[ $choices = 1 && $port_vl_re = 10002 && $port_hy2 = 10003 && $port_anytls = 10004 ]]
sbnh=1.10
exec 3< <(printf '%s\n' 10005 10006)
insport >/dev/null
[[ $choices = 2 && $port_vl_re = 10005 && $port_hy2 = 10006 && -z $port_anytls ]]
exec 3< <(printf '%s\n' 10005 10006 10001 10007)
randomport 10005 10006
[[ $port = 10007 ]]
echo 'Port allocation: new install, legacy install and existing ports: OK'
'''
bash = shutil.which("bash") or "C:/Program Files/Git/usr/bin/bash.exe"
subprocess.run([bash], input=port_test, text=True, encoding="utf-8", check=True)
