# Pre/PostToolUse hook for the gnc-executor's shell commands (PowerShell/Bash).
# The Write/Edit hook cannot see files a shell command creates, so this hook records the start
# time (pre) and afterwards (post) lists files changed since then in places the executor must not
# touch: the gnc-agents repo, the context folders, the session scratchpad and the workspace's
# frozen/planner files. A hit is reported back to the executor (exit 2); it cannot be undone here.
param([ValidateSet('pre', 'post')][string]$Phase = 'post')
. (Join-Path $PSScriptRoot 'gnc_common.ps1')
$evt = Get-GncEvent
if (-not $evt -or $evt.agent_type -ne 'gnc-executor' -or -not $evt.tool_use_id) { exit 0 }

$markDir = Join-Path $PSScriptRoot '..\gnc_sessions\tmp'
$mark = Join-Path $markDir "$($evt.tool_use_id).t"
if ($Phase -eq 'pre') {
    New-Item -ItemType Directory -Force $markDir | Out-Null
    [IO.File]::WriteAllText($mark, (Get-Date).ToUniversalTime().Ticks.ToString())
    exit 0
}
if (-not (Test-Path $mark)) { exit 0 }
$since = [datetime]::new([long](Get-Content $mark -Raw), [DateTimeKind]::Utc).AddSeconds(-1)
Remove-Item $mark -Force

$s = Get-GncSession $evt
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$roots = @($repo)
if ($s) { $roots += @($s.context) }
if ($evt.scratchpad_dir) { $roots += $evt.scratchpad_dir }

$wsNorm = if ($s) { ConvertTo-GncPath $s.workspace $null } else { $null }
$hits = @()
foreach ($r in $roots | Where-Object { $_ -and (Test-Path $_) } | Select-Object -Unique) {
    $hits += Get-ChildItem $r -Recurse -File -Force -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTimeUtc -ge $since -and $_.FullName -notmatch '\\(\.git|gnc_sessions)\\' } |
        Select-Object -ExpandProperty FullName |
        Where-Object { -not $wsNorm -or -not (Test-GncUnder (ConvertTo-GncPath $_ $null) $wsNorm) }
}
if ($s) {
    $ws = $s.workspace
    $protected = @(Get-GncFrozen $ws | ForEach-Object { Join-Path $ws $_ })
    $protected += Get-ChildItem (Join-Path $ws 'tests\acceptance'), (Join-Path $ws '.gnc') -Recurse -File -Force -ErrorAction SilentlyContinue |
        Select-Object -ExpandProperty FullName
    $hits += $protected | Where-Object { (Test-Path $_) -and (Get-Item $_).LastWriteTimeUtc -ge $since }
}
$hits = @($hits | Select-Object -Unique)
if ($hits.Count -gt 0) {
    [Console]::Error.WriteLine("PROTOCOL VIOLATION: this shell command changed files outside your allowed area:`n  " + ($hits -join "`n  ") +
        "`nUse absolute paths inside the workspace (scratch files: <workspace>/.scratch/). Do not try to repair or delete these files; list them in NOTES so the planner can clean up.")
    exit 2
}
exit 0
