# Saca una captura del juego con la cámara colocada (para revisar el aspecto sin jugar).
# Ejemplo: powershell -File tools/capture.ps1 -Out C:/tmp/foto.png -Pitch -0.3 -Yaw 40 -Up 30 -ThirdPerson
param(
    [Parameter(Mandatory = $true)][string]$Out,
    [double]$Pitch = 0,
    [double]$Yaw = 0,
    [double]$Up = 0,
    [switch]$ThirdPerson,
    [switch]$Front,     # con -ThirdPerson: cámara delante, mirando al personaje de frente
    [switch]$Side,      # con -ThirdPerson: cámara de perfil
    [int]$Swing = -1,   # lanzar un golpe N frames antes de la foto (para ver la animación)
    [string]$Action = "",  # congelar una animación del cuerpo: "voltereta:0.5", "estirarse:0.5"...
    [string]$At = "",   # "x,z" en voxels: teletransporte a ese punto de la isla
    [string]$Time = "", # hora del día (0-24) para la foto, p. ej. "19.4"
    [string]$Give = "", # objetos para la foto: "stone:12,dirt:30"
    [string]$Drop = "", # soltar un objeto delante (p. ej. "wood")
    [switch]$Inventory, # abrir la pantalla de inventario
    [int]$Wait = 90,
    [string]$Godot = "$env:USERPROFILE\Desktop\godot.windows.editor.x86_64.exe"
)
$project = Resolve-Path (Join-Path $PSScriptRoot "..")
$gameArgs = @("--path", "`"$project`"", "--", "--capture=$Out", "--pitch=$Pitch", "--up=$Up", "--wait=$Wait")
if ($ThirdPerson) { $gameArgs += "--tp" }
if ($Front) { $gameArgs += "--front" }
if ($Side) { $gameArgs += "--side" }
if ($Swing -ge 0) { $gameArgs += "--swing=$Swing" }
if ($Action -ne "") { $gameArgs += "--action=$Action" }
if ($Time -ne "") { $gameArgs += "--time=$Time" }
if ($PSBoundParameters.ContainsKey("Yaw")) { $gameArgs += "--yaw=$Yaw" }
if ($Give -ne "") { $gameArgs += "--give=$Give" }
if ($Drop -ne "") { $gameArgs += "--drop=$Drop" }
if ($Inventory) { $gameArgs += "--inventory" }
if ($At -ne "") { $gameArgs += "--at=$At" }
$p = Start-Process -FilePath $Godot -ArgumentList $gameArgs -RedirectStandardOutput "$env:TEMP\capture_out.txt" -RedirectStandardError "$env:TEMP\capture_err.txt" -PassThru
if (-not $p.WaitForExit(180000)) { $p.Kill(); Write-Output "TIMEOUT" }
Get-Content "$env:TEMP\capture_out.txt", "$env:TEMP\capture_err.txt" | Select-String "captura|SCRIPT ERROR|ERROR:" | Select-Object -First 6
