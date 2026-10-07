@echo off
cd /d "%~dp0"
start "" "godot.windows.editor.x86_64.exe" --path "%~dp0." res://scenes/combat_arena.tscn
