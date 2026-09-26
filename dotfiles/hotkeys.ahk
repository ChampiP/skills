#Requires AutoHotkey v2.0
#SingleInstance Force
; Global Windows hotkeys, mirroring the Hyprland muscle memory on Linux.
; Loaded at logon by a shortcut in shell:startup (see asistente-personal/references/bootstrap.md).

; Win+Enter: new Windows Terminal window with PowerShell 7 in ~/Work.
#Enter::Run('wt.exe -w new -d "' EnvGet("USERPROFILE") '\Work" pwsh.exe')
