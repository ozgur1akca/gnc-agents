# Deterministic hard gate for the /gnc workflow.
# Reads <workspace>/.gnc/gate.json, verifies acceptance-test hashes, runs the test command,
# prints a JSON result and writes it to <workspace>/.gnc/gate_last.json. Exit 0 = gate passed.
param(
    [Parameter(Mandatory = $true)][string]$Workspace,
    [int]$TailLines = 40
)
$ErrorActionPreference = 'Stop'
$ws = (Resolve-Path $Workspace).Path
$gnc = Join-Path $ws '.gnc'
$cfg = Get-Content (Join-Path $gnc 'gate.json') -Raw -Encoding UTF8 | ConvertFrom-Json

$hashProblems = @()
if ($cfg.acceptance) {
    foreach ($p in $cfg.acceptance.PSObject.Properties) {
        $file = Join-Path $ws $p.Name
        if (-not (Test-Path $file)) { $hashProblems += "missing: $($p.Name)"; continue }
        $h = (Get-FileHash $file -Algorithm SHA256).Hash
        if ($h -ne $p.Value) { $hashProblems += "changed: $($p.Name) (expected $($p.Value), got $h)" }
    }
}

$sw = [Diagnostics.Stopwatch]::StartNew()
Push-Location $ws
try {
    $ErrorActionPreference = 'Continue'
    # EncodedCommand: PowerShell 5.1 mangles embedded double quotes in -Command arguments.
    $enc = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($cfg.test_command + '; exit $LASTEXITCODE'))
    $out = & powershell -NoProfile -ExecutionPolicy Bypass -EncodedCommand $enc 2>&1 | Out-String
    $code = $LASTEXITCODE
} finally {
    Pop-Location
    $ErrorActionPreference = 'Stop'
}
$sw.Stop()

$lines = $out -split "`r?`n"
$tail = ($lines | Select-Object -Last $TailLines) -join "`n"
$result = [ordered]@{
    timestamp     = (Get-Date).ToString('s')
    gate_passed   = ($code -eq 0 -and $hashProblems.Count -eq 0)
    tests_passed  = ($code -eq 0)
    exit_code     = $code
    acceptance_ok = ($hashProblems.Count -eq 0)
    hash_problems = $hashProblems
    duration_s    = [math]::Round($sw.Elapsed.TotalSeconds, 1)
    test_command  = $cfg.test_command
    output_tail   = $tail
}
$json = $result | ConvertTo-Json -Depth 4
[IO.File]::WriteAllText((Join-Path $gnc 'gate_last.json'), $json, (New-Object Text.UTF8Encoding $false))
$json
if ($result.gate_passed) { exit 0 } else { exit 1 }
