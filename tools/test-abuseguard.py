"""Run the actual port callbacks with command doubles, without changing /etc."""
import re
import shutil
import subprocess
from pathlib import Path

source = (Path(__file__).resolve().parents[1] / "sb.sh").read_text(encoding="utf-8")


def body(name):
    return re.search(r"(?ms)^" + name + r"\(\)\{\n(.*?)^\}", source)[1]


functions = "agport(){\n" + body("agport").replace(
    "/usr/local/libexec/caddy-abuseguard", "$AG_TEST_ENGINE"
).replace("/usr/local/bin/ag", "testag") + "\n}\n"
functions += "install_ports(){\n" + body("instsllsingbox").split("\ninsname\n")[0].replace(
    "/etc/systemd/system/sing-box.service", "/nonexistent-abuseguard-test.service"
) + "\n}\n"
functions += "anytlsversion(){\n" + body("anytlsversion") + "\n}\n"
functions += "anytls_ports(){\n" + body("addanytls").split("\nlocal f\n")[0].replace(
    "/etc/s-box/sing-box", "testcore"
) + "\n}\n"
functions += "changeport(){\n" + source.split("changeport(){\n", 1)[1].split("\nchangeuuid(){", 1)[0].replace(
    "/etc/s-box/", "/nonexistent-abuseguard-test-config/"
)
functions += "\nlanding_ports()(\n" + source.split("lanapply()(\n", 1)[1].split("\numask 077", 1)[0] + "\n)\n"

checks = r'''
set -e
export PATH="/usr/bin:/bin:$PATH"
[[ ! -e /nonexistent-abuseguard-test-config ]]
AG_TEST_ENGINE=/bin/true
AG_TEST_STATUS=0
red(){ :; }; green(){ :; }; yellow(){ :; }; blue(){ :; }
testag(){ printf 'request:%s\n' "$*"; return "$AG_TEST_STATUS"; }
mkdir(){ :; }; v6(){ :; }; inssb(){ :; }; inscertificate(){ :; }
insport(){ port_vl_re=10001; port_hy2=10002; }
testcore(){ echo 'sing-box version 1.14.0'; }
randomport(){ port=10003; }
jq(){ return 1; }
[[ -z $(AG_TEST_ENGINE=/nonexistent-abuseguard-test agport tcp 10001) ]]
[[ $(install_ports) = $'request:--firewall-open tcp 10001\nrequest:--firewall-open udp 10002' ]]
port_anytls=10004
[[ $(anytls_ports install) = 'request:--firewall-open tcp 10004' ]]
[[ $(anytls_ports upgrade) = 'request:--firewall-open tcp 10003' ]]
AG_TEST_STATUS=1
if actual=$(install_ports); then echo 'Failed firewall request allowed installation' >&2; exit 1; fi
[[ $actual = 'request:--firewall-open tcp 10001' ]]
if anytls_ports upgrade >/dev/null; then echo 'Failed firewall request allowed AnyTLS creation' >&2; exit 1; fi

# Failed requests must return to the menu before any config write or restart.
sbactive(){ :; }
allports(){ anytls_port=30003; hy2_ports=; }
vlport(){ port_vl_re=10001; }; hy2port(){ port_hy2=10002; }; anytlsport(){ port=10003; }
jq(){ [[ $1 = -r ]] || { echo 'Unexpected config write' >&2; exit 1; }; }
restartsb(){ echo 'Unexpected restart' >&2; exit 1; }
choices=(1 3 2 1 0 0)
readchoice(){ menu=${choices[0]}; choices=("${choices[@]:1}"); }
actual=$(changeport | sed -n '/^request:/p') || true
[[ $actual = $'request:--firewall-open tcp 10001\nrequest:--firewall-open tcp 10003\nrequest:--firewall-open udp 10002' ]]

# Private inbound creation opens both protocols; cancelling a chain opens none.
AG_TEST_STATUS=0
lanprivate(){ return 0; }; ip(){ :; }; ss(){ :; }
jq(){ [[ "$*" = *addr_info* ]]; }
[[ $(landing_ports landing 192.168.1.2 54321) = $'request:--firewall-open tcp 54321\nrequest:--firewall-open udp 54321' ]]
[[ -z $(landing_ports none) ]]
AG_TEST_STATUS=1
if landing_ports landing 192.168.1.2 54321 >/dev/null; then echo 'Failed firewall request allowed private inbound creation' >&2; exit 1; fi
echo 'AbuseGuard callbacks: absent, create, change, private inbound and failures: OK'
'''
subprocess.run([shutil.which("bash") or "C:/Program Files/Git/usr/bin/bash.exe"],
               input=functions + checks, text=True, encoding="utf-8", check=True)
