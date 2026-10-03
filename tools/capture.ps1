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
    [string]$Wear = "", # ropa puesta: "shirt,pants,belt,backpack"
    [string]$Shape = "", # receta dibujada en el suelo delante (p. ej. "rough_backpack")
    [switch]$Working,   # el personaje agachado trabajando
    [switch]$Journal,   # recoger el diario del capitán y abrirlo
    [switch]$Pause,     # menú de pausa a la vista
    [switch]$Help,      # ayuda de controles (F1)
    [string]$Cracks = "", # grietas en el bloque apuntado (avance 0..1)
    [switch]$Title,     # foto de la pantalla de título (mundo ya cargado)
    [switch]$Bench,     # dos mesas de trabajo delante, con el pico a medio montar
    [switch]$Torches,   # dos antorchas clavadas delante
    [switch]$Craft,     # inventario de rodillas y vista de fabricar
    [switch]$Showcase,  # modelos voxelizados delante
    [switch]$Campfire,  # hoguera encendida delante
    [switch]$Rain,      # que llueva
    [string]$Textures = "", # paquete de texturas ("16x16")
    [int]$Page = 0,     # con -Journal: página izquierda (par)
    [string]$Learn = "", # con -Journal: recetas aprendidas, p. ej. "chest,belt"
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
if ($Wear -ne "") { $gameArgs += "--wear=$Wear" }
if ($Shape -ne "") { $gameArgs += "--shape=$Shape" }
if ($Working) { $gameArgs += "--working" }
if ($Journal) { $gameArgs += "--journal"; $gameArgs += "--page=$Page" }
if ($Learn -ne "") { $gameArgs += "--learn=$Learn" }
if ($Pause) { $gameArgs += "--pause" }
if ($Help) { $gameArgs += "--help" }
if ($Cracks -ne "") { $gameArgs += "--cracks=$Cracks" }
if ($Title) { $gameArgs += "--title" }
if ($Bench) { $gameArgs += "--bench" }
if ($Torches) { $gameArgs += "--torches" }
if ($Craft) { $gameArgs += "--craft" }
if ($Showcase) { $gameArgs += "--showcase" }
if ($Campfire) { $gameArgs += "--campfire" }
if ($Rain) { $gameArgs += "--rain" }
if ($Textures -ne "") { $gameArgs += "--textures=$Textures" }
if ($At -ne "") { $gameArgs += "--at=$At" }
$p = Start-Process -FilePath $Godot -ArgumentList $gameArgs -RedirectStandardOutput "$env:TEMP\capture_out.txt" -RedirectStandardError "$env:TEMP\capture_err.txt" -PassThru
if (-not $p.WaitForExit(180000)) { $p.Kill(); Write-Output "TIMEOUT" }
Get-Content "$env:TEMP\capture_out.txt", "$env:TEMP\capture_err.txt" | Select-String "captura|SCRIPT ERROR|ERROR:" | Select-Object -First 6
