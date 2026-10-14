# Shared helpers for the /gnc executor hooks (dot-sourced).
function Get-GncEvent {
    $raw = [Console]::In.ReadToEnd()
    try { return $raw | ConvertFrom-Json } catch { return $null }
}

function Get-GncSession($evt) {
    if (-not $evt.session_id) { return $null }
    $file = Join-Path $PSScriptRoot "..\gnc_sessions\$($evt.session_id).json"
    if (-not (Test-Path $file)) { return $null }
    return Get-Content $file -Raw -Encoding UTF8 | ConvertFrom-Json
}

function ConvertTo-GncPath($p, $cwd) {
    if (-not [IO.Path]::IsPathRooted($p)) { $p = Join-Path $(if ($cwd) { $cwd } else { (Get-Location).Path }) $p }
    ([IO.Path]::GetFullPath($p) -replace '\\', '/').TrimEnd('/').ToLowerInvariant()
}

function Test-GncUnder($p, $dir) { $p -eq $dir -or $p.StartsWith("$dir/") }

# Frozen files of a workspace: gate.json "frozen" and legacy "acceptance" maps (path -> SHA256).
function Get-GncFrozen($workspace) {
    $gateFile = Join-Path $workspace '.gnc\gate.json'
    if (-not (Test-Path $gateFile)) { return @() }
    $g = Get-Content $gateFile -Raw -Encoding UTF8 | ConvertFrom-Json
    $names = @()
    foreach ($key in 'frozen', 'acceptance') {
        if ($g.$key) { $names += $g.$key.PSObject.Properties.Name }
    }
    return $names
}

function Deny-Gnc($msg) {
    [Console]::Error.WriteLine("BLOCKED: $msg Report the problem in NOTES instead of working around it.")
    exit 2
}
