@echo off
rem Abre la sala de muestras: suelo plano con todos los bloques, arboles y plantas (no se guarda).
rem Dentro, pulsa C para el modo creativo (todos los objetos) y E para el inventario.
start "" "%USERPROFILE%\Desktop\godot.windows.editor.x86_64.exe" --path "%~dp0." -- --showroom
