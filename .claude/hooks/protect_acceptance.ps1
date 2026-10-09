# PreToolUse hook for gnc-executor: block writes to frozen acceptance tests (exit 2 = deny).
$raw = [Console]::In.ReadToEnd()
try { $evt = $raw | ConvertFrom-Json } catch { exit 0 }
$path = $evt.tool_input.file_path
if (-not $path) { $path = $evt.tool_input.notebook_path }
if ($path -and ($path -replace '\\', '/') -match '(^|/)tests/acceptance/') {
    [Console]::Error.WriteLine("BLOCKED: '$path' is a frozen acceptance test. The executor must not modify tests/acceptance/. If the test is wrong, report it in NOTES instead.")
    exit 2
}
exit 0
