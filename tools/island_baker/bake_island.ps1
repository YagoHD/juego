# Hornea los mapas de la isla (height/water/biome/preview) en assets/island/.
# Uso: powershell -ExecutionPolicy Bypass -File tools/island_baker/bake_island.ps1
param([int]$Seed = 1337)

$src = Get-Content -Raw -Encoding UTF8 (Join-Path $PSScriptRoot "IslandBaker.cs")
Add-Type -TypeDefinition $src -ReferencedAssemblies System.Drawing

$outDir = Resolve-Path (Join-Path $PSScriptRoot "..\..\assets\island")
$sw = [Diagnostics.Stopwatch]::StartNew()
$summary = [IslandBaker]::Bake($outDir.Path, $Seed)
$sw.Stop()
Write-Output $summary
Write-Output ("Horneado en {0:F1} s -> {1}" -f $sw.Elapsed.TotalSeconds, $outDir.Path)

# Los mapas se importan en Godot como "Image": hay que reimportarlos para que el juego use los
# nuevos (el editor lo hace solo al recuperar el foco; sin editor, hay que pedirlo).
$godot = "$env:USERPROFILE\Desktop\godot.windows.editor.x86_64.exe"
if (Test-Path $godot) {
    $project = Resolve-Path (Join-Path $PSScriptRoot "..\..")
    & $godot --headless --path "$project" --import 2>&1 | Out-Null
    Write-Output "Mapas reimportados en Godot."
} else {
    Write-Output "AVISO: no encuentro Godot; abre el editor para que reimporte los mapas."
}
