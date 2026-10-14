# Registers the active /gnc workspace and read-only context folders for THIS Claude Code session.
# The executor hooks look the file up by the hook input's session_id, so parallel /gnc sessions
# on different workspaces do not interfere.
param(
    [Parameter(Mandatory = $true)][string]$Workspace,
    [string[]]$Context = @()
)
$ErrorActionPreference = 'Stop'
$sid = $env:CLAUDE_CODE_SESSION_ID
if (-not $sid) { throw 'CLAUDE_CODE_SESSION_ID is not set; run this from a Claude Code tool call.' }
$dir = Join-Path $PSScriptRoot '..\gnc_sessions'
New-Item -ItemType Directory -Force $dir | Out-Null
$ws = (Resolve-Path $Workspace).Path
$ctx = @($Context | Where-Object { $_ } | ForEach-Object { (Resolve-Path $_).Path })
$json = [ordered]@{ session_id = $sid; workspace = $ws; context = $ctx; registered = (Get-Date).ToString('s') } | ConvertTo-Json
$file = Join-Path $dir "$sid.json"
[IO.File]::WriteAllText($file, $json, (New-Object Text.UTF8Encoding $false))
"registered session $sid -> $ws (context: $($ctx -join ', '))"
