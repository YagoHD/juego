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
