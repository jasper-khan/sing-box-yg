# Fork invariant check: vless-reality disguise domain stays foothill.edu,
# and self-update URLs point at this fork.
# Usage: powershell -NoProfile -ExecutionPolicy Bypass -File .\fork-check.ps1
# Exit code 0 = pass, 1 = invariant broken.
[CmdletBinding()]
param([string]$Path)

if (-not $Path) { $Path = Join-Path $PSScriptRoot 'sb.sh' }

$errors = @()
# sb.sh is UTF-8. Reading it with the Windows PowerShell 5.1 default (ANSI,
# GB2312 on Chinese systems) would mojibake the text and let the checks below
# pass against equally mojibake pattern literals.
$text   = [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
$lines  = $text -split '\r?\n'

# 1) Every ym_vl_re assignment must be foothill.edu
#    (a new assignment added elsewhere by upstream shows up here)
$assigns = @()
foreach ($line in $lines) {
  if ($line -match '^\s*(?:export\s+)?ym_vl_re=(.*)$') {
    $assigns += $Matches[1].Trim().Trim([char[]](34, 39))
  }
}
if ($assigns.Count -lt 1) {
  $errors += "no ym_vl_re assignment found"
}
$bad = @($assigns | Where-Object { $_ -ne 'foothill.edu' -and $_ -ne '${menu:-foothill.edu}' -and $_ -ne '${ym_vl_re:-foothill.edu}' })
if ($bad.Count) {
  $errors += "ym_vl_re assigned to non-foothill value: $($bad -join ' | ')"
}

# 2) sb10/sb11 server templates: line 23 = server_name, line 27 = reality handshake.server
$blocks = [regex]::Matches($text, '(?ms)^cat > /etc/s-box/(sb10|sb11)\.json <<EOF\r?\n(.*?)^EOF\r?$')
if ($blocks.Count -ne 2) {
  $errors += "sb10/sb11 config templates not found (found $($blocks.Count))"
} else {
  foreach ($m in $blocks) {
    $name = $m.Groups[1].Value
    $body = $m.Groups[2].Value -split '\r?\n'
    if ($body.Count -lt 27) {
      $errors += "$name`: template shorter than 27 lines"
      continue
    }
    if ($body[22] -notmatch '"server_name": "\$\{ym_vl_re\}",') {
      $errors += "$name`: line 23 is no longer server_name (changeym sed 23 would miss)"
    }
    if ($body[26] -notmatch '"server": "\$\{ym_vl_re\}",') {
      $errors += "$name`: line 27 is no longer reality handshake.server (sed 27 would miss)"
    }
  }
}

# 3) the reality-domain setter must keep writing by JSON path (no line numbers)
if ($text -notmatch 'jq --arg v "\$ym_vl_re"' -or
    $text -notmatch '\(\.inbounds\[0\]\.tls\.server_name\) = \$v' -or
    $text -notmatch '\(\.inbounds\[0\]\.tls\.reality\.handshake\.server\) = \$v') {
  $errors += 'reality-domain write-back is missing or no longer path-based'
}

# 4) self-update and version check must point at this fork. Every
#    raw.githubusercontent.com/<owner>/sing-box-yg URL must be jasper-khan, and the
#    functions that actually execute the download must carry the fork URL.
$owners = [regex]::Matches($text, 'raw\.githubusercontent\.com/([^/\s"'']+)/sing-box-yg') |
  ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique
if (-not $owners.Count) {
  $errors += 'no raw.githubusercontent.com/<owner>/sing-box-yg URL found at all'
} else {
  $badOwners = @($owners | Where-Object { $_ -ne 'jasper-khan' })
  if ($badOwners.Count) {
    $errors += "self-update/version URL points at another owner: $($badOwners -join ', ')"
  }
}
$lnsb = [regex]::Match($text, '(?ms)^lnsb\(\)\{.*?^\}')
if (-not $lnsb.Success) {
  $errors += 'lnsb() function not found (self-update cannot be verified)'
} elseif ($lnsb.Value -notmatch 'raw\.githubusercontent\.com/jasper-khan/sing-box-yg/main/sb\.sh') {
  $errors += 'lnsb() no longer downloads sb.sh from this fork'
}
$upsbyg = [regex]::Match($text, '(?ms)^upsbyg\(\)\{.*?^\}')
if (-not $upsbyg.Success) {
  $errors += 'upsbyg() function not found (version stamp cannot be verified)'
} elseif ($upsbyg.Value -notmatch 'raw\.githubusercontent\.com/jasper-khan/sing-box-yg/main/version') {
  $errors += 'upsbyg() no longer reads the version file from this fork'
}

# 5) fork scope: only vless-reality + hysteria2 may remain.
#    Removed protocols must be gone, and the Argo tunnel feature must not come back.
#    (unins/uncronsb must not reference removed-feature leftovers either: see 5b)
$removed = [regex]::Matches($text, '(?i)\b(?:vmess|tuic|anytls)\w*|\bargo\w*|cfargo|argoym|cloudflared') | ForEach-Object { $_.Value } | Sort-Object -Unique
if ($removed) {
  $errors += "removed protocol code reappeared: $($removed -join ', ')"
}
$staleIndex = [regex]::Matches($text, '\.inbounds\[[2-9]\]') | ForEach-Object { $_.Value } | Sort-Object -Unique
if ($staleIndex) {
  $errors += "stale inbound index references: $($staleIndex -join ', ')"
}
foreach ($name in 'sb10', 'sb11') {
  $tmpl = [regex]::Match($text, "(?ms)^cat > /etc/s-box/$name\.json <<EOF\r?\n(.*?)^EOF\r?$")
  if (-not $tmpl.Success) { $errors += "$name config template not found"; continue }
  $types = [regex]::Matches($tmpl.Groups[1].Value, '"type"\s*:\s*"([a-z0-9]+)"') | ForEach-Object { $_.Groups[1].Value }
  $present = @($types | Where-Object { $_ -in @('vless', 'hysteria2') })
  if ($present.Count -lt 2) { $errors += "$name template lost vless/hysteria2 inbound" }
  # WARP-WireGuard is intentionally back in fork.11 (see guard 18); only the
  # dropped WARP-Socks5 / WARP-plus helpers must stay out of the configs.
  $wgMarkers = [regex]::Matches([regex]::Unescape($tmpl.Groups[1].Value), '(?i)\b(?:warp-plus|sbwpph|socks-out|warp-socks5|psiphon|cfwarp|cloudflared)\b') |
    ForEach-Object { $_.Value } | Sort-Object -Unique
  if ($wgMarkers) { $errors += "$name template contains dropped WARP-Socks5 markers: $($wgMarkers -join ', ')" }
}

# 5b) uninstall must only clean this fork's own components; legacy argo/warp/
#     websbox/sbwpph/cloudflared/geoip/geosite cleanup was removed on purpose.
foreach ($fn in 'unins', 'uncronsb') {
  $body = [regex]::Match($text, "(?ms)^$fn\(\)\{.*?^\}")
  if (-not $body.Success) {
    $errors += "$fn() not found: guard 5b cannot verify removed-feature leftovers"
    continue
  }
  $legacy = [regex]::Matches($body.Value, '(?i)\bargo\b|\bwarp-go\b|\bwg-quick\b|\bsbwpph\b|\bwebsbox\b|\bcloudflared\b|\bgeoip\.db\b|\bgeosite\.db\b') | ForEach-Object { $_.Value } | Sort-Object -Unique
  if ($legacy) { $errors += "$fn still references removed-feature leftovers: $($legacy -join ', ')" }
}

# 6) config files must be edited by JSON path (jq), never by fixed line numbers:
#    line numbers drift whenever upstream adds or removes a field.
$lineSeds = [regex]::Matches($text, 'sed\s+-i\s+"\d+s')
if ($lineSeds.Count) {
  $errors += "fixed-line sed edits are back ($($lineSeds.Count)); they break silently on upstream field changes"
}

# 7) client-config generation must stay removed (deleting legacy leftovers is allowed):
#    this fork ships share links + jhsub only
$clientGen = [regex]::Matches($text, 'cat > /etc/s-box/(sbox\.json|clmi\.yaml)|\b(sball|clall|sb_client|sbhy2ports)\s*\(\)')
if ($clientGen.Count) {
  $errors += "client config generation code reappeared ($($clientGen.Count) hits)"
}

# 8) firewall-disabling install flow must stay removed; print actual inbound ports instead.
#    Whole-firewall wipes only: targeted cleanup of one named chain such as
#    "iptables -t nat -F PREROUTING" (used by unins) stays allowed.
$fwHits = @()
$fwPatterns = @(
  @{ Label = 'openyn';                 Rx = '(?i)\bopenyn\b' },
  @{ Label = 'setenforce 0';           Rx = '(?i)\bsetenforce\s+0\b' },
  @{ Label = 'SELINUX=disabled';       Rx = '(?i)\bSELINUX\s*=\s*disabled\b' },
  @{ Label = 'firewalld stop/disable'; Rx = '(?i)\bsystemctl\s+(?:stop|disable|mask)\s+firewalld\b|\b(?:service|rc-service)\s+firewalld\s+stop\b' },
  @{ Label = 'ufw disable';            Rx = '(?i)\bufw\s+disable\b' },
  @{ Label = 'iptables -P ACCEPT';     Rx = '\biptables\b[^\r\n]*\s(?:-P|--policy)\s+(?:INPUT|OUTPUT|FORWARD)\s+ACCEPT\b' },
  @{ Label = 'apache/httpd stop';      Rx = '(?i)\bsystemctl\s+(?:stop|disable)\s+(?:apache2?|httpd)\b|\b(?:service|rc-service)\s+(?:apache2?|httpd)\s+stop\b|\bapachectl\s+stop\b' }
)
foreach ($fw in $fwPatterns) {
  if ($text -match $fw.Rx) { $fwHits += $fw.Label }
}
foreach ($line in $lines) {
  if ($line -notmatch '\biptables\b') { continue }
  foreach ($segment in ($line -split '[|;&]+')) {
    if ($segment -notmatch '\biptables\b') { continue }
    foreach ($m in [regex]::Matches($segment, '(?<=\s)(?<flag>-F|--flush|-X|--delete-chain)(?![A-Za-z-])(?:\s+(?<chain>[A-Za-z][\w.-]*))?')) {
      $chain = $m.Groups['chain'].Value
      if ($chain -eq '' -or $chain -in @('INPUT', 'OUTPUT', 'FORWARD')) {
        $fwHits += "iptables $($m.Groups['flag'].Value) $chain".Trim()
      }
    }
  }
}
$fwHits = @($fwHits | Sort-Object -Unique)
if ($fwHits.Count) {
  $errors += "firewall-disabling install flow reappeared: $($fwHits -join ', ')"
}
if ($text -notmatch 'Vless-reality\uFF1ATCP \$port_vl_re' -or
    $text -notmatch 'Hysteria-2\uFF1AUDP \$port_hy2') {
  $errors += 'install no longer prints the VLESS/Hysteria2 inbound port reminder'
}
# 9) GitLab publishing and Telegram push must stay removed, and "变更配置"
#    must stay at the 5 remaining interaction points.
$pushHits = [regex]::Matches($text, '(?i)gitlab|telegram|TG通知|电报|sbtg\.sh|gitpush\.sh') | ForEach-Object { $_.Value } | Sort-Object -Unique
if ($pushHits) {
  $errors += "gitlab/telegram feature reappeared: $($pushHits -join ', ')"
}
$cs = [regex]::Match($text, '(?ms)^changeserv\(\)\{.*?^\}')
if (-not $cs.Success) {
  $errors += 'changeserv menu not found'
} else {
  foreach ($fn in 'setcert', 'setname', 'changeym', 'changeuuid', 'changeip', 'changefl') {
    if ($cs.Value -notmatch "\b$fn\b") { $errors += "config-change menu lost $fn" }
  }
  $csOpts = [regex]::Matches($cs.Value, '"\$menu"\s*=\s*"([0-9]+)"') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique
  if (($csOpts -join ',') -ne '1,2,3,4,5,6') {
    $errors += "changeserv options changed: $($csOpts -join ',') (expected 1,2,3,4,5,6)"
  }
}

# 11) upstream Serv00 / web-UI / WARP-binary leftovers must stay deleted.
$removedFiles = 'serv00.sh', 'serv00keep.sh', 'serv00.yml', 'SSH.yml', 'kp.sh', 'sb.txt', 'app.js', 'index.html', 'sversion', 'workers_keep.js', 'sbwpph_amd64', 'sbwpph_arm64', '.github/workflows/main.yml'
$backAgain = @($removedFiles | Where-Object { Test-Path (Join-Path $PSScriptRoot $_) })
if ($backAgain.Count) {
  $errors += "deleted upstream files came back: $($backAgain -join ', ')"
}

# 12) share links must show exactly the configurable node name: no hostname and
#     no hard-coded "vl-reality-"/"hy2-" prefix in front of it.
$nodeFrag = [regex]::Matches($text, '#\$sbnode"').Count
if ($nodeFrag -ne 2) {
  $errors += "share links no longer use the configurable node name (found $nodeFrag of 2)"
}
if ($text -match '#(?:vl-reality|hy2)-\$sbnode') {
  $errors += 'share links re-added a hard-coded protocol prefix in front of the node name'
}

# 13) the local-IP subscription server (busybox httpd) must stay removed.
$subHits = [regex]::Matches($text, '(?i)\bipsub\b|subport\.log|subtoken\.log|busybox[^\r\n]*httpd|jhsub\.txt|websbox') | ForEach-Object { $_.Value } | Sort-Object -Unique
if ($subHits) {
  $errors += "local-IP subscription feature reappeared: $($subHits -join ', ')"
}

# 14) upstream promo/branding must stay out of the panel: no 甬哥 logo,
#     no upstream Github/blog/YouTube links, no video-tutorial list.
$promoHits = [regex]::Matches($text, '(?i)ygkkk|blogspot|youtube|youtu\.be|甬哥') | ForEach-Object { $_.Value } | Sort-Object -Unique
if ($promoHits) {
  $errors += "upstream promo/branding reappeared: $($promoHits -join ', ')"
}

# 15) the vless share link must keep the fork's TLS fingerprint default (firefox),
#     not upstream's chrome.
if ($text -notmatch 'fp=firefox') {
  $errors += 'vless share link lost the fp=firefox default'
}
if ($text -match 'fp=chrome') {
  $errors += 'vless share link fell back to upstream fp=chrome'
}

# 16) the version file must stay fork-owned: upstream's would stamp the wrong
#     version number and carry upstream promo links.
$versionFile = Join-Path $PSScriptRoot 'version'
if (-not (Test-Path $versionFile)) {
  $errors += 'version file missing from the repo root'
} else {
  $verText = [System.IO.File]::ReadAllText($versionFile, [System.Text.Encoding]::UTF8)
  if ($verText -notmatch '-fork\.') { $errors += 'version file lost the -fork. version tag' }
  if ($verText -notmatch 'github\.com/jasper-khan/sing-box-yg') { $errors += 'version file no longer links to this fork' }
}

# 17) changeuuid() must rewrite the hysteria2 password as well, otherwise the
#     second protocol silently keeps the old password after a UUID change.
$cu = [regex]::Match($text, '(?ms)^changeuuid\(\)\{.*?^\}')
if (-not $cu.Success) {
  $errors += 'changeuuid() function not found'
} elseif ($cu.Value -notmatch '\(\.inbounds\[1\]\.users\[0\]\.password\)\s*=\s*\$u') {
  $errors += 'changeuuid() no longer rewrites the hysteria2 password'
}

# 18) the WARP-WireGuard channel (restored in fork.11) must stay intact:
#     install registers its own Cloudflare account (no python3/xxd), both
#     server templates carry the wireguard outbound, and the domain-split menu
#     writes the four channels by JSON path.
$warpfn = [regex]::Match($text, '(?ms)^warpwg\(\)\{.*?^\}')
if (-not $warpfn.Success) {
  $errors += 'warpwg() function not found (WARP-WireGuard account registration)'
} else {
  if ($warpfn.Value -notmatch 'api\.cloudflareclient\.com') {
    $errors += 'warpwg() no longer registers a Cloudflare WARP account'
  }
  if ($warpfn.Value -match '(?i)\bpython3?\b|\bxxd\b') {
    $errors += 'warpwg() reintroduced the removed python3/xxd dependencies'
  }
}
$install = [regex]::Match($text, '(?ms)^instsllsingbox\(\)\{.*?^\}')
if (-not $install.Success) {
  $errors += 'instsllsingbox() not found'
} elseif ($install.Value -notmatch '(?m)^warpwg\r?$') {
  $errors += 'install flow no longer calls warpwg()'
}
$wg10 = [regex]::Match($text, '(?ms)^cat > /etc/s-box/sb10\.json <<EOF\r?\n(.*?)^EOF\r?$')
if (-not $wg10.Success) {
  $errors += 'sb10 config template not found (guard 18)'
} else {
  if ($wg10.Groups[1].Value -notmatch '"type":"wireguard"') {
    $errors += 'sb10 template lost the wireguard outbound'
  }
  $n = [regex]::Matches($wg10.Groups[1].Value, '"domain_suffix"').Count
  if ($n -ne 4) { $errors += "sb10 template domain-split rule count changed: $n (expected 4)" }
}
$wg11 = [regex]::Match($text, '(?ms)^cat > /etc/s-box/sb11\.json <<EOF\r?\n(.*?)^EOF\r?$')
if (-not $wg11.Success) {
  $errors += 'sb11 config template not found (guard 18)'
} else {
  $b11 = $wg11.Groups[1].Value
  if ($b11 -notmatch '"endpoints"') { $errors += 'sb11 template lost the wireguard endpoints array' }
  if ($b11 -notmatch '"type":"wireguard"') { $errors += 'sb11 template lost the wireguard endpoint' }
  $n20 = [regex]::Matches($b11, '"action": "resolve"').Count
  if ($n20 -ne 4) { $errors += "sb11 resolve-rule count changed: $n20 (expected 4)" }
  $n21 = [regex]::Matches($b11, '"domain_suffix"').Count
  if ($n21 -ne 8) { $errors += "sb11 domain-split rule count changed: $n21 (expected 8)" }
  $n22 = [regex]::Matches($b11, '"outbound": "warp-out"').Count
  if ($n22 -ne 2) { $errors += "sb11 warp-out rule count changed: $n22 (expected 2)" }
}
$flfn = [regex]::Match($text, '(?ms)^changefl\(\)\{.*?^\}')
if (-not $flfn.Success) {
  $errors += 'changefl() function not found (domain-split menu)'
} else {
  if ($flfn.Value -notmatch '\(\.route\.rules\[\$a\]\.domain_suffix\)') {
    $errors += 'changefl() no longer writes the split domains by JSON path'
  }
  if ($flfn.Value -notmatch '\$menu" = "5"') {
    $errors += 'changefl() lost the global-egress option (menu 3 -> 6 -> 5)'
  }
  if ($flfn.Value -notmatch '\(\.route\.rules\[\$i\]\.outbound\)') {
    $errors += 'changefl() no longer writes the global egress by JSON path'
  }
}

if ($errors.Count) {
  $errors | ForEach-Object { Write-Host "FAIL: $_" -ForegroundColor Red }
  exit 1
}
Write-Host 'reality invariant: OK' -ForegroundColor Green
exit 0
