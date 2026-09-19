[CmdletBinding()]
param(
    [string]$Script,
    [string[]]$ExpectSb10 = @('vless', 'hysteria2'),
    [string[]]$ExpectSb11 = @('vless', 'hysteria2'),
    [string[]]$ExpectSb10Outbounds = @('direct', 'direct', 'direct', 'direct', 'direct', 'wireguard', 'block'),
    [string[]]$ExpectSb11Outbounds = @('direct')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# $PSScriptRoot is not populated inside the param block on Windows PowerShell 5.1
if (-not $Script) { $Script = Join-Path (Split-Path -Parent $PSScriptRoot) 'sb.sh' }

function Stop-WithError {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    [Console]::Error.WriteLine("ERROR: $Message")
    exit 1
}

function Remove-CommandSubstitutions {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Text
    )

    $builder = New-Object System.Text.StringBuilder
    $index = 0

    while ($index -lt $Text.Length) {
        if ($Text[$index] -eq '$' -and ($index + 1) -lt $Text.Length -and $Text[$index + 1] -eq '(') {
            $start = $index
            $depth = 0

            while ($index -lt $Text.Length) {
                if ($Text[$index] -eq '(') {
                    $depth++
                }
                elseif ($Text[$index] -eq ')') {
                    $depth--
                    if ($depth -eq 0) {
                        $index++
                        break
                    }
                }

                $index++
            }

            if ($depth -ne 0) {
                [void]$builder.Append($Text.Substring($start))
                break
            }
        }
        else {
            [void]$builder.Append($Text[$index])
            $index++
        }
    }

    return $builder.ToString()
}

function Get-TargetTemplates {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Text
    )

    $pattern = '(?ms)^[ \t]*cat[ \t]+>[ \t]+/etc/s-box/(?<name>sb10|sb11)\.json[ \t]+<<EOF[ \t]*\r?\n(?<body>.*?)^[ \t]*EOF[ \t]*\r?$'
    $templates = @{}

    foreach ($match in [regex]::Matches($Text, $pattern)) {
        $name = $match.Groups['name'].Value
        if ($templates.ContainsKey($name)) {
            Stop-WithError "Found multiple heredocs for $name.json."
        }

        $templates[$name] = $match.Groups['body'].Value
    }

    foreach ($name in @('sb10', 'sb11')) {
        if (-not $templates.ContainsKey($name)) {
            Stop-WithError "Could not find the $name.json heredoc in '$Script'."
        }
    }

    return $templates
}

function Convert-TemplateToJson {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [Parameter(Mandatory = $true)]
        [string]$Template
    )

    $rendered = [regex]::Replace($Template, '\$\{[^}\r\n]*\}', '0')
    $rendered = Remove-CommandSubstitutions -Text $rendered

    # The templates also use bare variables such as $res in numeric positions.
    $rendered = [regex]::Replace($rendered, '\$[A-Za-z_][A-Za-z0-9_]*', '0')

    if ($rendered.Contains('${') -or $rendered.Contains('$(')) {
        Stop-WithError "$Name.json still contains an unresolved shell expansion."
    }

    try {
        return ConvertFrom-Json -InputObject $rendered -ErrorAction Stop
    }
    catch {
        Stop-WithError "$Name.json failed to parse: $($_.Exception.Message)"
    }
}

function Assert-ExactTypes {
    param(
        [string]$Name = '',
        [string]$Kind = '',
        [string[]]$Expected = @(),
        [string[]]$Actual = @()
    )

    Write-Host ("{0} {1}s: {2}" -f $Name, $Kind, ($Actual -join ','))

    $match = $Actual.Count -eq $Expected.Count

    if ($match) {
        for ($index = 0; $index -lt $Actual.Count; $index++) {
            if ($Actual[$index] -cne $Expected[$index]) {
                $match = $false
                break
            }
        }
    }

    if (-not $match) {
        Stop-WithError ("{0} {1} mismatch. Expected: {2}; Actual: {3}." -f $Name, $Kind, ($Expected -join ','), ($Actual -join ','))
    }
}

try {
    $sourcePath = (Resolve-Path -LiteralPath $Script -ErrorAction Stop).Path
    $sourceText = [System.IO.File]::ReadAllText($sourcePath)
}
catch {
    Stop-WithError "Could not read '$Script': $($_.Exception.Message)"
}

$templates = Get-TargetTemplates -Text $sourceText
$expectedOutbounds = @{
    sb10 = @($ExpectSb10Outbounds)
    sb11 = @($ExpectSb11Outbounds)
}

$expectedTypes = @{
    sb10 = @($ExpectSb10)
    sb11 = @($ExpectSb11)
}

foreach ($name in @('sb10', 'sb11')) {
    $template = $templates[$name]

    $forbidden = [regex]::Match([regex]::Unescape($template), '(?i)\b(?:warp-plus|sbwpph|socks-out|warp-socks5|psiphon|cfwarp|cloudflared)\b')
    if ($forbidden.Success) {
        Stop-WithError ("{0}.json template contains a dropped WARP-Socks5 marker: {1}" -f $name, $forbidden.Value)
    }

    $json = Convert-TemplateToJson -Name $name -Template $template

    if ($null -eq $json.PSObject.Properties['inbounds'] -or $null -eq $json.inbounds) {
        Stop-WithError "$name.json has no inbounds array."
    }

    if ($null -eq $json.PSObject.Properties['outbounds'] -or $null -eq $json.outbounds) {
        Stop-WithError "$name.json has no outbounds array."
    }

    Assert-ExactTypes -Name $name -Kind 'inbound' -Expected @($expectedTypes[$name]) `
        -Actual @($json.inbounds | ForEach-Object { [string]$_.type })
    Assert-ExactTypes -Name $name -Kind 'outbound' -Expected @($expectedOutbounds[$name]) `
        -Actual @($json.outbounds | ForEach-Object { [string]$_.type })

    $rules = @($json.route.rules)

    if ($name -eq 'sb10') {
        if ($rules.Count -ne 6) {
            Stop-WithError ("sb10.json rule count is {0} (expected 6: quic block + 4 split channels + fallback)." -f $rules.Count)
        }

        $quicRule = $rules[0]
        $quicProtocols = @($quicRule.protocol)
        if ($quicProtocols.Count -ne 2 -or $quicProtocols -cnotcontains 'quic' -or $quicProtocols -cnotcontains 'stun') {
            Stop-WithError 'sb10.json rule[0] is no longer the quic/stun block rule.'
        }

        $splitOutbounds = @('warp-IPv4-out', 'warp-IPv6-out', 'vps-outbound-v4', 'vps-outbound-v6')
        for ($index = 0; $index -lt $splitOutbounds.Count; $index++) {
            $rule = $rules[1 + $index]
            $actual = if ($rule.PSObject.Properties['outbound']) { [string]$rule.outbound } else { '' }
            if ($actual -cne $splitOutbounds[$index]) {
                Stop-WithError ("sb10.json rule[{0}] outbound is '{1}' (expected '{2}')." -f (1 + $index), $actual, $splitOutbounds[$index])
            }
            $sentinel = @($rule.domain_suffix)
            if ($sentinel.Count -ne 1 -or [string]$sentinel[0] -cne 'yg_kkk') {
                Stop-WithError ("sb10.json rule[{0}] lost the yg_kkk sentinel domain list." -f (1 + $index))
            }
        }

        $fallback = $rules[5]
        $fallbackOut = if ($fallback.PSObject.Properties['outbound']) { [string]$fallback.outbound } else { '' }
        if ($fallbackOut -cne 'direct' -and $fallbackOut -cne 'warp-IPv4-out') {
            Stop-WithError ("sb10.json rule[5] (fallback) outbound is '{0}' (expected direct or warp-IPv4-out)." -f $fallbackOut)
        }
        if ($fallback.network -isnot [string]) {
            Stop-WithError 'sb10.json rule[5] network must keep the legacy string form (1.10 kernel).'
        }
    }
    else {
        if ($null -eq $json.PSObject.Properties['endpoints'] -or $null -eq $json.endpoints) {
            Stop-WithError 'sb11.json has no endpoints array (WARP-WireGuard endpoint).'
        }
        Assert-ExactTypes -Name $name -Kind 'endpoint' -Expected @('wireguard') `
            -Actual @($json.endpoints | ForEach-Object { [string]$_.type })

        if ($rules.Count -ne 10) {
            Stop-WithError ("sb11.json rule count is {0} (expected 10: sniff + 4 resolve/outbound pairs + fallback)." -f $rules.Count)
        }

        $sniffAction = if ($rules[0].PSObject.Properties['action']) { [string]$rules[0].action } else { '' }
        if ($sniffAction -cne 'sniff') {
            Stop-WithError 'sb11.json rule[0] is no longer the sniff rule (split-rule indices would shift).'
        }

        $splitTargets = @('warp-out', 'warp-out', 'direct', 'direct')
        $splitStrategies = @('prefer_ipv4', 'prefer_ipv6', 'prefer_ipv4', 'prefer_ipv6')
        for ($index = 0; $index -lt $splitTargets.Count; $index++) {
            $resolveRule = $rules[1 + 2 * $index]
            $routeRule = $rules[2 + 2 * $index]
            $actualAction = if ($resolveRule.PSObject.Properties['action']) { [string]$resolveRule.action } else { '' }
            $actualStrategy = if ($resolveRule.PSObject.Properties['strategy']) { [string]$resolveRule.strategy } else { '' }
            $actualOutbound = if ($routeRule.PSObject.Properties['outbound']) { [string]$routeRule.outbound } else { '' }
            if ($actualAction -cne 'resolve' -or $actualStrategy -cne $splitStrategies[$index]) {
                Stop-WithError ("sb11.json rule[{0}] is not resolve/{1}." -f (1 + 2 * $index), $splitStrategies[$index])
            }
            if ($actualOutbound -cne $splitTargets[$index]) {
                Stop-WithError ("sb11.json rule[{0}] outbound is '{1}' (expected '{2}')." -f (2 + 2 * $index), $actualOutbound, $splitTargets[$index])
            }
            foreach ($ruleIndex in @((1 + 2 * $index), (2 + 2 * $index))) {
                $sentinel = @($rules[$ruleIndex].domain_suffix)
                if ($sentinel.Count -ne 1 -or [string]$sentinel[0] -cne 'yg_kkk') {
                    Stop-WithError ("sb11.json rule[{0}] lost the yg_kkk sentinel domain list." -f $ruleIndex)
                }
            }
        }

        $fallback = $rules[9]
        $fallbackOut = if ($fallback.PSObject.Properties['outbound']) { [string]$fallback.outbound } else { '' }
        if ($fallbackOut -cne 'direct' -and $fallbackOut -cne 'warp-out') {
            Stop-WithError ("sb11.json rule[9] (fallback / global-egress) outbound is '{0}' (expected direct or warp-out)." -f $fallbackOut)
        }
        if ($fallback.network -isnot [array]) {
            Stop-WithError 'sb11.json rule[9] network must use the list form (1.11+ kernels silently ignore the legacy string).'
        }
    }
}

Write-Host 'OK'
exit 0
