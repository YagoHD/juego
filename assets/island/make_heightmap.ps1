# Genera un mapa de alturas (heightmap) de la isla, inspirado en la referencia:
# montaña escarpada a la derecha-arriba, tierras altas al norte (zona de la torre),
# bahía con playas abajo-izquierda, costa irregular. Gris 0=mar profundo, 255=cima.
# Salida: heightmap.png (256x256). Ejecutar con PowerShell una vez.

Add-Type -AssemblyName System.Drawing

$W = 256
$H = 256

$bmp = New-Object System.Drawing.Bitmap($W, $H)

for ($py = 0; $py -lt $H; $py++) {
    for ($px = 0; $px -lt $W; $px++) {
        $nx = ($px / ($W - 1.0)) - 0.5   # -0.5 .. 0.5 (derecha +)
        $ny = ($py / ($H - 1.0)) - 0.5   # -0.5 .. 0.5 (abajo +, arriba = norte)

        # Isla base con costa irregular (radio modulado por el ángulo).
        $ang = [math]::Atan2($ny, $nx)
        $d = [math]::Sqrt($nx * $nx + $ny * $ny)
        $radius = 0.46 + 0.05 * [math]::Sin($ang * 5.0) + 0.03 * [math]::Sin($ang * 11.0 + 1.3)
        $island = 1.0 - ($d / $radius)
        if ($island -lt 0) { $island = 0 }
        if ($island -gt 1) { $island = 1 }
        $island = $island * $island * (3 - 2 * $island)  # smoothstep
        $hv = $island * 0.36

        # Montaña escarpada (derecha-arriba).
        $mdx = $nx - 0.22; $mdy = $ny + 0.08
        $md = [math]::Sqrt($mdx * $mdx + $mdy * $mdy)
        $mt = 1.0 - ($md / 0.22)
        if ($mt -lt 0) { $mt = 0 }
        $mt = [math]::Pow($mt, 1.7)
        $hv += $mt * 0.78

        # Tierras altas al norte (zona de la torre).
        $hdx = $nx - 0.08; $hdy = $ny + 0.34
        $hd = [math]::Sqrt($hdx * $hdx + $hdy * $hdy)
        $ht = 1.0 - ($hd / 0.16)
        if ($ht -lt 0) { $ht = 0 }
        $ht = [math]::Pow($ht, 1.5)
        $hv += $ht * 0.34

        # Bahía (abajo-izquierda): resta altura para abrir una ensenada con playas.
        $bdx = $nx + 0.26; $bdy = $ny - 0.30
        $bd = [math]::Sqrt($bdx * $bdx + $bdy * $bdy)
        $bt = 1.0 - ($bd / 0.17)
        if ($bt -lt 0) { $bt = 0 }
        $hv -= $bt * 0.5

        # Detalle grueso para romper la suavidad (Godot añade el ruido fino).
        $hv += 0.04 * [math]::Sin($nx * 22.0) * [math]::Cos($ny * 19.0)

        if ($hv -lt 0) { $hv = 0 }
        if ($hv -gt 1) { $hv = 1 }
        $g = [int][math]::Round($hv * 255)

        $col = [System.Drawing.Color]::FromArgb($g, $g, $g)
        $bmp.SetPixel($px, $py, $col)
    }
}

$out = Join-Path $PSScriptRoot "heightmap.png"
$bmp.Save($out, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()
Write-Output "Heightmap guardado en $out"
