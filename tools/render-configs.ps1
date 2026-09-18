[CmdletBinding()]
param(
    [string]$Script,
    [string[]]$ExpectSb10 = @('vless', 'hysteria2'),
    [string[]]$ExpectSb11 = @('vless', 'hysteria2'),
    [string[]]$ExpectSb10Outbounds = @('direct', 'block'),
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

    $forbidden = [regex]::Match([regex]::Unescape($template), '(?i)\b(?:wireguard|warp|wg-quick|cfwarp)\b|"endpoints"\s*:')
    if ($forbidden.Success) {
        Stop-WithError ("{0}.json template contains a forbidden wireguard/WARP marker: {1}" -f $name, $forbidden.Value)
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
}

Write-Host 'OK'
exit 0
