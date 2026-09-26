# Coding agents never start with cwd = $HOME; they jump to $HOME\Work first.
foreach ($agent in 'claude', 'codex', 'opencode', 'gemini', 'pi', 'gentle-shell') {
    $body = "if ((Get-Location).Path -eq `$HOME) { Set-Location `"`$HOME\Work`" }; & (Get-Command '$agent' -CommandType Application | Select-Object -First 1) @args"
    Set-Item -Path "function:global:$agent" -Value ([scriptblock]::Create($body))
}
