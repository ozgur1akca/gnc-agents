# PreToolUse hook (exit 2 = deny), registered in .claude/settings.json. Applies only to the gnc-executor
# subagent: writes allowed only inside the active workspace, never under tests/acceptance/, .gnc/ or a
# read-only context folder. Workspace and context come from .claude/gnc_session.json (written by /gnc).
$raw = [Console]::In.ReadToEnd()
try { $evt = $raw | ConvertFrom-Json } catch { exit 0 }
if ($evt.agent_type -ne 'gnc-executor') { exit 0 }
$path = $evt.tool_input.file_path
if (-not $path) { $path = $evt.tool_input.notebook_path }
if (-not $path) { exit 0 }

function Deny($msg) { [Console]::Error.WriteLine("BLOCKED: $msg Report the problem in NOTES instead."); exit 2 }
function Norm($p) {
    if (-not [IO.Path]::IsPathRooted($p)) { $p = Join-Path $(if ($evt.cwd) { $evt.cwd } else { (Get-Location).Path }) $p }
    ([IO.Path]::GetFullPath($p) -replace '\\', '/').TrimEnd('/').ToLowerInvariant()
}
function Under($p, $dir) { $p -eq $dir -or $p.StartsWith("$dir/") }

$target = Norm $path
if ($target -match '(^|/)tests/acceptance/') { Deny "'$path' is a frozen acceptance test." }
if ($target -match '(^|/)\.gnc/') { Deny "'$path' is planner state (.gnc/)." }

$sessionFile = Join-Path $PSScriptRoot '..\gnc_session.json'
if (Test-Path $sessionFile) {
    $s = Get-Content $sessionFile -Raw -Encoding UTF8 | ConvertFrom-Json
    foreach ($c in @($s.context)) { if ($c -and (Under $target (Norm $c))) { Deny "'$path' is inside read-only context folder '$c'." } }
    if ($s.workspace -and -not (Under $target (Norm $s.workspace))) { Deny "'$path' is outside the workspace '$($s.workspace)'." }
}
exit 0
