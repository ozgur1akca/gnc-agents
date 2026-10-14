# Deterministic hard gate for the /gnc workflow.
# Reads <workspace>/.gnc/gate.json, verifies the hashes of all frozen files, runs the test command
# with a timeout, prints a JSON result and writes it to <workspace>/.gnc/gate_last.json.
# Exit 0 = gate passed.
#
# gate.json: {"lang", "test_command", "timeout_s" (default 1800), "slow_command" (optional),
#             "context", "frozen": {path: sha256}, "acceptance": {path: sha256} (legacy, merged)}
param(
    [Parameter(Mandatory = $true)][string]$Workspace,
    [switch]$Slow,
    [int]$TailLines = 40
)
$ErrorActionPreference = 'Stop'
$ws = (Resolve-Path $Workspace).Path
$gnc = Join-Path $ws '.gnc'
$cfg = Get-Content (Join-Path $gnc 'gate.json') -Raw -Encoding UTF8 | ConvertFrom-Json

$hashProblems = @()
foreach ($key in 'frozen', 'acceptance') {
    if (-not $cfg.$key) { continue }
    foreach ($p in $cfg.$key.PSObject.Properties) {
        $file = Join-Path $ws $p.Name
        if (-not (Test-Path $file)) { $hashProblems += "missing: $($p.Name)"; continue }
        $h = (Get-FileHash $file -Algorithm SHA256).Hash
        if ($h -ne $p.Value) { $hashProblems += "changed: $($p.Name) (expected $($p.Value), got $h)" }
    }
}

$command = if ($Slow) { $cfg.slow_command } else { $cfg.test_command }
if (-not $command) { throw "gate.json has no $(if ($Slow) { 'slow_command' } else { 'test_command' })." }
$timeoutS = if ($cfg.timeout_s) { [int]$cfg.timeout_s } else { 1800 }

# Keep the machine awake while the tests run (an idle machine went to sleep mid-run before).
Add-Type -Namespace GncGate -Name Power -MemberDefinition '[DllImport("kernel32.dll")] public static extern uint SetThreadExecutionState(uint esFlags);' -ErrorAction SilentlyContinue
[void][GncGate.Power]::SetThreadExecutionState([uint32]'0x80000001')  # ES_CONTINUOUS | ES_SYSTEM_REQUIRED

function Get-Descendants([int]$rootPid, $all) {
    $kids = @($all | Where-Object { $_.ParentProcessId -eq $rootPid })
    $out = @()
    foreach ($k in $kids) { $out += $k; $out += Get-Descendants $k.ProcessId $all }
    return $out
}

$outFile = [IO.Path]::GetTempFileName()
$errFile = [IO.Path]::GetTempFileName()
$gateStart = Get-Date
$seen = @{}
$timedOut = $false
try {
    # EncodedCommand: PowerShell 5.1 mangles embedded double quotes in -Command arguments.
    $enc = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes('$ProgressPreference = ''SilentlyContinue''; ' + $command + '; exit $LASTEXITCODE'))
    $proc = Start-Process powershell -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-EncodedCommand', $enc `
        -WorkingDirectory $ws -NoNewWindow -PassThru -RedirectStandardOutput $outFile -RedirectStandardError $errFile
    $null = $proc.Handle  # keep the handle so ExitCode stays available
    $deadline = $gateStart.AddSeconds($timeoutS)
    while (-not $proc.WaitForExit(2000)) {
        $all = Get-CimInstance Win32_Process -Property ProcessId, ParentProcessId, CreationDate
        foreach ($d in Get-Descendants $proc.Id $all) { $seen[[int]$d.ProcessId] = $d.CreationDate }
        if ((Get-Date) -gt $deadline) { $timedOut = $true; break }
    }
    if ($timedOut) { & taskkill /PID $proc.Id /T /F 2>&1 | Out-Null }
    $code = if ($timedOut) { -1 } else { $proc.ExitCode }
} finally {
    # Kill descendants that outlived the test command (e.g. process-pool workers, MATLAB helpers).
    $leftover = @()
    foreach ($procId in $seen.Keys) {
        $p = Get-CimInstance Win32_Process -Filter "ProcessId = $procId" -ErrorAction SilentlyContinue
        if ($p -and $p.CreationDate -eq $seen[$procId]) {
            $leftover += "$procId $($p.Name)"
            & taskkill /PID $procId /T /F 2>&1 | Out-Null
        }
    }
    [void][GncGate.Power]::SetThreadExecutionState([uint32]'0x80000000')  # ES_CONTINUOUS: release
}
$duration = ((Get-Date) - $gateStart).TotalSeconds

$out = (Get-Content $outFile -Raw -ErrorAction SilentlyContinue) + (Get-Content $errFile -Raw -ErrorAction SilentlyContinue)
Remove-Item $outFile, $errFile -Force -ErrorAction SilentlyContinue
$tail = (($out -split "`r?`n") | Select-Object -Last $TailLines) -join "`n"

$result = [ordered]@{
    timestamp        = (Get-Date).ToString('s')
    suite            = $(if ($Slow) { 'slow' } else { 'gate' })
    gate_passed      = ($code -eq 0 -and $hashProblems.Count -eq 0)
    tests_passed     = ($code -eq 0)
    exit_code        = $code
    timed_out        = $timedOut
    timeout_s        = $timeoutS
    acceptance_ok    = ($hashProblems.Count -eq 0)
    hash_problems    = $hashProblems
    killed_leftovers = $leftover
    duration_s       = [math]::Round($duration, 1)
    test_command     = $command
    output_tail      = $tail
}
$json = $result | ConvertTo-Json -Depth 4
[IO.File]::WriteAllText((Join-Path $gnc 'gate_last.json'), $json, (New-Object Text.UTF8Encoding $false))
$json
if ($result.gate_passed) { exit 0 } else { exit 1 }
