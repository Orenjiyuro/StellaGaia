[CmdletBinding()]
param(
    [Parameter()]
    [string] $ContractRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
$issues = [System.Collections.Generic.List[string]]::new()

function Test-ContainsForbiddenPropertyName {
    param(
        [Parameter()]
        [AllowNull()]
        [object] $Value
    )

    if ($null -eq $Value -or $Value -is [string]) {
        return $false
    }

    if ($Value -is [System.Management.Automation.PSCustomObject]) {
        foreach ($property in $Value.PSObject.Properties) {
            if ($property.Name -cin @('OriginalUnityProjectRestored', 'originalUnityProjectRestored')) {
                return $true
            }

            if (Test-ContainsForbiddenPropertyName -Value $property.Value) {
                return $true
            }
        }

        return $false
    }

    if ($Value -is [System.Collections.IDictionary]) {
        foreach ($key in $Value.Keys) {
            if ([string]$key -cin @('OriginalUnityProjectRestored', 'originalUnityProjectRestored')) {
                return $true
            }

            if (Test-ContainsForbiddenPropertyName -Value $Value[$key]) {
                return $true
            }
        }

        return $false
    }

    if ($Value -is [System.Collections.IEnumerable]) {
        foreach ($item in $Value) {
            if (Test-ContainsForbiddenPropertyName -Value $item) {
                return $true
            }
        }
    }

    return $false
}

if ([string]::IsNullOrWhiteSpace($ContractRoot)) {
    $repositoryRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
    $ContractRoot = Join-Path $repositoryRoot 'docs\asset-migration\schemas'
}
else {
    $ContractRoot = [System.IO.Path]::GetFullPath($ContractRoot)
}

$vocabularyPath = [System.IO.Path]::GetFullPath((Join-Path $ContractRoot 'status-vocabulary.json'))
$vocabulary = $null
$serializedVocabulary = $null

if (-not (Test-Path -LiteralPath $vocabularyPath -PathType Leaf)) {
    $issues.Add("Missing contract file: $vocabularyPath")
}
else {
    try {
        $serializedVocabulary = Get-Content -LiteralPath $vocabularyPath -Raw
        $vocabulary = $serializedVocabulary | ConvertFrom-Json
    }
    catch {
        $issues.Add("Invalid JSON contract file: $vocabularyPath")
    }
}

if ($null -ne $vocabulary) {
    $schemaVersionProperty = $vocabulary.PSObject.Properties['schemaVersion']
    if ($null -eq $schemaVersionProperty -or $schemaVersionProperty.Value -isnot [string] -or $schemaVersionProperty.Value -cne '1.0.0') {
        $issues.Add('schemaVersion must be exactly 1.0.0')
    }

    $expectedArrays = [ordered]@{
        corpus                   = @('Cataloged', 'Missing', 'StaleInput')
        extraction               = @('NotAttempted', 'ExtractedReadable', 'CrossToolVerified', 'Opaque', 'Failed')
        semantics                = @('Known', 'PartiallyKnown', 'Unknown')
        configurationDisposition = @('Parsed', 'DiscoveredOpaque', 'Encrypted', 'RequiresRuntimeType', 'LikelyServerDependent', 'NotConfiguration')
        unity                    = @('NotTested', 'StaticQualified', 'RepresentativeValidated', 'Rejected', 'UnityExecutionUnavailable')
        disposition              = @('NeedsDiagnosis', 'UseOriginalAsset', 'RepairOnce', 'PrototypeReplacement', 'RetainForLater', 'DiagnosticOnly', 'Stop')
        familyStaticOutcome      = @('StaticQualified', 'StaticRejected', 'NeedsDiagnosis')
        sourceKind               = @('PcInstall', 'PcPatchOrCache', 'AndroidApk', 'AndroidDataOrCache')
    }

    foreach ($entry in $expectedArrays.GetEnumerator()) {
        $property = $vocabulary.PSObject.Properties[$entry.Key]
        $matches = $null -ne $property

        if ($matches) {
            $actual = @($property.Value)
            $expected = @($entry.Value)
            $matches = $actual.Count -eq $expected.Count

            if ($matches) {
                for ($index = 0; $index -lt $expected.Count; $index++) {
                    if ($actual[$index] -isnot [string] -or $actual[$index] -cne $expected[$index]) {
                        $matches = $false
                        break
                    }
                }
            }
        }

        if (-not $matches) {
            $issues.Add("Vocabulary array '$($entry.Key)' does not match the contract")
        }
    }

    if (Test-ContainsForbiddenPropertyName -Value $vocabulary) {
        $issues.Add('Forbidden OriginalUnityProjectRestored property name is present')
    }
}

$stopwatch.Stop()
$result = [pscustomobject][ordered]@{
    status            = if ($issues.Count -eq 0) { 'Passed' } else { 'Failed' }
    issueCount        = $issues.Count
    issues            = $issues.ToArray()
    schemaCount       = 0
    fixtureCount      = 0
    childProcessCount = 0
    durationMs        = $stopwatch.ElapsedMilliseconds
}

if ($issues.Count -gt 0) {
    Write-Output ($result | ConvertTo-Json -Depth 5 -Compress)
    throw "Asset corpus contract validation failed with $($issues.Count) issue(s)."
}

Write-Output $result
