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

# 3) changeym still writes the domain back via the 23/27 sed calls
if (-not $text.Contains('echo $sbfiles | xargs -n1 sed -i "23s/$a/$ym_vl_re/"') -or
    -not $text.Contains('echo $sbfiles | xargs -n1 sed -i "27s/$b/$ym_vl_re/"')) {
  $errors += 'changeym 23/27 write-back changed, needs manual review'
}

# 4) self-update and version check must point at this fork
if ($text -match 'raw\.githubusercontent\.com/yonggekkk/sing-box-yg/main/(sb\.sh|version)') {
  $errors += 'self-update/version URL fell back to upstream, foothill.edu would be lost on update'
}
if ($text -notmatch 'raw\.githubusercontent\.com/jasper-khan/sing-box-yg/main/sb\.sh') {
  $errors += 'no self-update URL pointing at this fork'
}

if ($errors.Count) {
  $errors | ForEach-Object { Write-Host "FAIL: $_" -ForegroundColor Red }
  exit 1
}
Write-Host 'reality invariant: OK' -ForegroundColor Green
exit 0
