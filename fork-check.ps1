# Fork invariant check: vless-reality disguise domain stays foothill.edu,
# and self-update URLs point at this fork.
# Usage: powershell -NoProfile -ExecutionPolicy Bypass -File .\fork-check.ps1
# Exit code 0 = pass, 1 = invariant broken.
[CmdletBinding()]
param([string]$Path)

if (-not $Path) { $Path = Join-Path $PSScriptRoot 'sb.sh' }

$errors = @()
$text   = Get-Content -Raw -LiteralPath $Path
$lines  = $text -split '\r?\n'

# 1) Every ym_vl_re assignment must be foothill.edu
#    (a new assignment added elsewhere by upstream shows up here)
$assigns = @()
foreach ($line in $lines) {
  if ($line -match '^\s*(?:export\s+)?ym_vl_re=(.*)$') {
    $assigns += $Matches[1].Trim().Trim([char[]](34, 39))
  }
}
if ($assigns.Count -lt 3) {
  $errors += "only $($assigns.Count) ym_vl_re assignment(s) found, expected at least 3"
}
$bad = @($assigns | Where-Object { $_ -ne 'foothill.edu' -and $_ -ne '${menu:-foothill.edu}' })
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

# 3) changeym must keep writing the reality domain by JSON path (no line numbers)
if ($text -notmatch 'jq --arg v "\$ym_vl_re"' -or
    $text -notmatch '\(\.inbounds\[0\]\.tls\.server_name\) = \$v' -or
    $text -notmatch '\(\.inbounds\[0\]\.tls\.reality\.handshake\.server\) = \$v') {
  $errors += 'changeym reality-domain write-back is missing or no longer path-based'
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
if ($text -match '\bopenyn\b|systemctl\s+stop\s+firewalld|ufw\s+disable') {
  $errors += 'firewall-disabling install flow reappeared'
}
if ($text -notmatch 'Vless-reality：TCP \$port_vl_re' -or
    $text -notmatch 'Hysteria-2：UDP \$port_hy2') {
  $errors += 'install no longer prints the VLESS/Hysteria2 inbound port reminder'
}
if ($errors.Count) {
  $errors | ForEach-Object { Write-Host "FAIL: $_" -ForegroundColor Red }
  exit 1
}
Write-Host 'reality invariant: OK' -ForegroundColor Green
exit 0
