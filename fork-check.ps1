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

# 4) self-update and version check must point at this fork
if ($text -match 'raw\.githubusercontent\.com/yonggekkk/sing-box-yg/main/(sb\.sh|version)') {
  $errors += 'self-update/version URL fell back to upstream, foothill.edu would be lost on update'
}
if ($text -notmatch 'raw\.githubusercontent\.com/jasper-khan/sing-box-yg/main/sb\.sh') {
  $errors += 'no self-update URL pointing at this fork'
}

# 5) fork scope: only vless-reality + hysteria2 may remain.
#    Removed protocols must be gone, and the Argo tunnel feature must not come back.
#    (uninstall may still mention legacy argo/cloudflared leftovers on purpose)
$removed = [regex]::Matches($text, '(?i)\b(vmess|tuic|anytls)\b|cfargo|argoym|cloudflared tunnel') | ForEach-Object { $_.Value } | Sort-Object -Unique
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
  # WireGuard/WARP must not return to the shipped configs. Only the config
  # templates are scanned, so unins cleanup of legacy warp-go/wg-quick
  # leftovers (outside these heredocs) stays allowed.
  $wgMarkers = [regex]::Matches([regex]::Unescape($tmpl.Groups[1].Value), '(?i)\b(?:wireguard|warp|wg-quick|cfwarp)\b|"endpoints"\s*:') |
    ForEach-Object { $_.Value } | Sort-Object -Unique
  if ($wgMarkers) { $errors += "$name template contains wireguard/WARP markers: $($wgMarkers -join ', ')" }
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
  foreach ($fn in 'setcert', 'setname', 'changeym', 'changeuuid', 'changeip') {
    if ($cs.Value -notmatch "\b$fn\b") { $errors += "config-change menu lost $fn" }
  }
}

# 11) upstream Serv00 / web-UI / WARP-binary leftovers must stay deleted.
$removedFiles = 'serv00.sh', 'serv00keep.sh', 'serv00.yml', 'SSH.yml', 'kp.sh', 'sb.txt', 'app.js', 'index.html', 'sversion', 'workers_keep.js', 'sbwpph_amd64', 'sbwpph_arm64', '.github/workflows/main.yml'
$backAgain = @($removedFiles | Where-Object { Test-Path (Join-Path $PSScriptRoot $_) })
if ($backAgain.Count) {
  $errors += "deleted upstream files came back: $($backAgain -join ', ')"
}

# 12) share links must use the configurable node name (not the raw hostname).
if ($text -notmatch '#vl-reality-\$sbnode' -or $text -notmatch '#hy2-\$sbnode') {
  $errors += 'share links no longer use the configurable node name'
}

# 13) the local-IP subscription server (busybox httpd) must stay removed.
$subHits = [regex]::Matches($text, '(?i)\bipsub\b|subport\.log|subtoken\.log|busybox[^\r\n]*httpd|jhsub\.txt') | ForEach-Object { $_.Value } | Sort-Object -Unique
if ($subHits) {
  $errors += "local-IP subscription feature reappeared: $($subHits -join ', ')"
}

if ($errors.Count) {
  $errors | ForEach-Object { Write-Host "FAIL: $_" -ForegroundColor Red }
  exit 1
}
Write-Host 'reality invariant: OK' -ForegroundColor Green
exit 0
