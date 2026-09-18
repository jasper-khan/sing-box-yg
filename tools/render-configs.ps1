[CmdletBinding()]
param(
    [string]$Script = (Join-Path (Split-Path -Parent $PSScriptRoot) 'sb.sh'),
    [string[]]$ExpectSb10 = @('vless', 'hysteria2'),
    [string[]]$ExpectSb11 = @('vless', 'hysteria2')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

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

try {
    $sourcePath = (Resolve-Path -LiteralPath $Script -ErrorAction Stop).Path
    $sourceText = [System.IO.File]::ReadAllText($sourcePath)
}
catch {
    Stop-WithError "Could not read '$Script': $($_.Exception.Message)"
}

$templates = Get-TargetTemplates -Text $sourceText
$expectedTypes = @{
    sb10 = @($ExpectSb10)
    sb11 = @($ExpectSb11)
}

foreach ($name in @('sb10', 'sb11')) {
    $json = Convert-TemplateToJson -Name $name -Template $templates[$name]

    if ($null -eq $json.PSObject.Properties['inbounds'] -or $null -eq $json.inbounds) {
        Stop-WithError "$name.json has no inbounds array."
    }

    $actual = @($json.inbounds | ForEach-Object { [string]$_.type })
    Write-Host ("{0} inbounds: {1}" -f $name, ($actual -join ','))

    $expected = @($expectedTypes[$name])
    $matches = $actual.Count -eq $expected.Count

    if ($matches) {
        for ($index = 0; $index -lt $actual.Count; $index++) {
            if ($actual[$index] -cne $expected[$index]) {
                $matches = $false
                break
            }
        }
    }

    if (-not $matches) {
        Stop-WithError ("{0} inbound mismatch. Expected: {1}; Actual: {2}." -f $name, ($expected -join ','), ($actual -join ','))
    }
}

Write-Host 'OK'
exit 0
