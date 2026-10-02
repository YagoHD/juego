# Saca una captura del juego con la cámara colocada (para revisar el aspecto sin jugar).
# Ejemplo: powershell -File tools/capture.ps1 -Out C:/tmp/foto.png -Pitch -0.3 -Yaw 40 -Up 30 -ThirdPerson
param(
    [Parameter(Mandatory = $true)][string]$Out,
    [double]$Pitch = 0,
    [double]$Yaw = 0,
    [double]$Up = 0,
    [switch]$ThirdPerson,
    [int]$Wait = 90,
    [string]$Godot = "$env:USERPROFILE\Desktop\godot.windows.editor.x86_64.exe"
)
$project = Resolve-Path (Join-Path $PSScriptRoot "..")
$gameArgs = @("--path", "`"$project`"", "--", "--capture=$Out", "--pitch=$Pitch", "--yaw=$Yaw", "--up=$Up", "--wait=$Wait")
if ($ThirdPerson) { $gameArgs += "--tp" }
$p = Start-Process -FilePath $Godot -ArgumentList $gameArgs -RedirectStandardOutput "$env:TEMP\capture_out.txt" -RedirectStandardError "$env:TEMP\capture_err.txt" -PassThru
if (-not $p.WaitForExit(180000)) { $p.Kill(); Write-Output "TIMEOUT" }
Get-Content "$env:TEMP\capture_out.txt", "$env:TEMP\capture_err.txt" | Select-String "captura|SCRIPT ERROR|ERROR:" | Select-Object -First 6
