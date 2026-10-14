# PreToolUse hook for Write/Edit (exit 2 = deny). Applies only to the gnc-executor subagent:
# writes are allowed only inside the workspace registered for this session (gnc_session.ps1),
# never under tests/acceptance/, .gnc/, a context folder or a frozen file listed in gate.json.
. (Join-Path $PSScriptRoot 'gnc_common.ps1')
$evt = Get-GncEvent
if (-not $evt -or $evt.agent_type -ne 'gnc-executor') { exit 0 }
$path = $evt.tool_input.file_path
if (-not $path) { $path = $evt.tool_input.notebook_path }
if (-not $path) { exit 0 }

$s = Get-GncSession $evt
if (-not $s) { Deny-Gnc "no /gnc session is registered for session $($evt.session_id); the planner must run gnc_session.ps1 first." }

$target = ConvertTo-GncPath $path $evt.cwd
$ws = ConvertTo-GncPath $s.workspace $null
if ($target -match '(^|/)tests/acceptance/') { Deny-Gnc "'$path' is a frozen acceptance test." }
if ($target -match '(^|/)\.gnc/') { Deny-Gnc "'$path' is planner state (.gnc/)." }
foreach ($c in @($s.context)) { if ($c -and (Test-GncUnder $target (ConvertTo-GncPath $c $null))) { Deny-Gnc "'$path' is inside read-only context folder '$c'." } }
if (-not (Test-GncUnder $target $ws)) { Deny-Gnc "'$path' is outside the workspace '$($s.workspace)'. Scratch files go to <workspace>/.scratch/." }
foreach ($f in Get-GncFrozen $s.workspace) {
    if ($target -eq (ConvertTo-GncPath (Join-Path $s.workspace $f) $null)) { Deny-Gnc "'$path' is a frozen file (hashed in gate.json)." }
}
exit 0
