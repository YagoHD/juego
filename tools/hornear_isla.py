#!/usr/bin/env python3
"""Hornea la isla a partir del mapa de ChatGPT (docs/mapa_isla/beta1.png), calcándolo.

Uso:  python3 tools/hornear_isla.py            (necesita numpy, Pillow y scipy: pip install scipy)

Sustituye al horneador antiguo (tools/island_baker, C#). Genera los mismos mapas de 1024x1024 que
lee el juego (scripts/world/island_generator.gd), en assets/island/:
  height.png  -> altura del suelo en voxels (16 bits: R alto, G bajo, valor = altura * 64)
  water.png   -> nivel del agua de ríos y lagos (misma codificación, 0 = sin agua)
  surface.png -> bloque de superficie (R), de subsuelo (G) y árbol (B = tipo * 64 + densidad en milésimas)
  biome.png / preview.png -> para mirar (el diario usa preview.png como mapa)
El mapa cubre 512 x 512 m (1 píxel = 1 voxel = 0,5 m), con el norte arriba como el dibujo.

Pasos: 1) se recorta el mapa y se clasifica cada píxel por su color (mar, arena, hierba, bosque,
roca, nieve, corrupción, agua dulce, camino, campo), quitando antes las etiquetas y los iconos;
2) con esas zonas se levanta el relieve: suelo que sube desde la costa con lomas suaves, acantilados
donde el dibujo pinta roca junto al mar, una montaña de verdad (crestas, valles y cumbre nevada)
donde están la roca y la nieve del este, tierras altas con agujas en la zona corrupta, el lago en
su meseta y el río bajando del lago al mar por su cauce; 3) superficie, árboles y vista previa.
"""
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage as ndi

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
SRC = os.path.join(ROOT, "docs", "mapa_isla", "beta1.png")
OUT = os.path.join(ROOT, "assets", "island")
SCRATCH = os.environ.get("HORNEO_DEBUG", "")  # carpeta para imágenes de depuración (opcional)
N = 1024
MAP_BOX = (43, 75, 1075, 1107)  # el mapa dentro de beta1.png (sin título ni leyenda)
SEA = 24.0

# Clases.
OCEAN, SHALLOW, SAND, GRASS, FOREST, ROCK, SNOW, CORRUPT, FRESH, ROAD, FIELD = range(11)
CLASS_COLORS = {OCEAN: (20, 50, 120), SHALLOW: (40, 150, 190), SAND: (230, 210, 150), GRASS: (130, 190, 80),
                FOREST: (40, 110, 45), ROCK: (120, 120, 125), SNOW: (240, 240, 245), CORRUPT: (110, 50, 130),
                FRESH: (70, 180, 230), ROAD: (180, 130, 80), FIELD: (230, 200, 60)}


def load_map():
    img = Image.open(SRC).convert("RGB").crop(MAP_BOX).resize((N, N), Image.LANCZOS)
    rgb = np.asarray(img).astype(np.float32) / 255.0
    return rgb


def hsv(rgb):
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    mx = rgb.max(-1)
    mn = rgb.min(-1)
    d = mx - mn + 1e-6
    h = np.where(mx == r, ((g - b) / d) % 6, np.where(mx == g, (b - r) / d + 2, (r - g) / d + 4)) * 60.0
    s = np.where(mx > 0, d / (mx + 1e-6), 0)
    return h, s, mx


def debug(name, arr):
    if not SCRATCH:
        return
    os.makedirs(SCRATCH, exist_ok=True)
    if arr.dtype == bool:
        arr = arr.astype(np.uint8) * 255
    if arr.ndim == 2 and arr.dtype != np.uint8:
        lo, hi = float(arr.min()), float(arr.max())
        arr = ((arr - lo) / max(hi - lo, 1e-6) * 255).astype(np.uint8)
    Image.fromarray(arr).save(os.path.join(SCRATCH, name + ".png"))


def labels_mask(rgb):
    """Etiquetas (cajas negras con letras blancas) e iconos con borde oscuro: se taparán."""
    h, s, v = hsv(rgb)
    black = v < 0.13
    # Cajas: zonas negras grandes y anchas (las etiquetas). Se rellenan con su letra dentro.
    lab, n = ndi.label(ndi.binary_closing(black, iterations=2))
    mask = np.zeros_like(black)
    for i, sl in enumerate(ndi.find_objects(lab), 1):
        hgt, wid = sl[0].stop - sl[0].start, sl[1].stop - sl[1].start
        if 12 <= hgt <= 40 and wid >= 45:
            mask[sl] = True
    # Círculos blancos con número/letra (marcadores) y letras blancas.
    white = (v > 0.9) & (s < 0.12)
    lab, n = ndi.label(white)
    for i, sl in enumerate(ndi.find_objects(lab), 1):
        hgt, wid = sl[0].stop - sl[0].start, sl[1].stop - sl[1].start
        if 10 <= hgt <= 30 and 10 <= wid <= 30:
            mask[sl[0].start - 3:sl[0].stop + 3, sl[1].start - 3:sl[1].stop + 3] = True
    return ndi.binary_dilation(mask, iterations=3)


def inpaint(arr, mask):
    """Rellena lo tapado con el valor del píxel bueno más cercano."""
    idx = ndi.distance_transform_edt(mask, return_distances=False, return_indices=True)
    return arr[tuple(idx)]


def classify(rgb):
    hide = labels_mask(rgb)
    rgb = inpaint(rgb, hide)
    soft = ndi.uniform_filter(rgb, size=(5, 5, 1))
    h, s, v = hsv(soft)
    cls = np.full((N, N), GRASS, np.uint8)
    blue = (h > 180) & (h < 235) & (s > 0.45)
    # Mar: el agua azul unida al borde del mapa (se cierran los huecos de rocas y espuma).
    water = ndi.binary_closing(blue | ((s < 0.25) & (v > 0.75) & (h > 170) & (h < 230)), iterations=2)
    lab, n = ndi.label(water)
    m = 8  # el mapa lleva un marco fino: se mira un poco hacia dentro
    border = set(np.unique(np.concatenate([lab[m], lab[-m], lab[:, m], lab[:, -m]]))) - {0}
    ocean = np.isin(lab, list(border))
    ocean = ndi.binary_opening(ocean, iterations=2)
    # Rellena las rocas sueltas e islotes pequeños dentro del mar (se quedan como mar).
    land = ~ocean
    lab, n = ndi.label(land)
    sizes = ndi.sum(land, lab, range(1, n + 1))
    small = np.isin(lab, [i + 1 for i, sz in enumerate(sizes) if sz < 900])
    ocean |= small
    land = ~ocean
    shallow_water = ocean & (((h < 200) & (v > 0.55)) | (ndi.distance_transform_edt(ocean) < 14))
    cls[ocean] = OCEAN
    cls[shallow_water] = SHALLOW
    # Agua dulce: azul dentro de la tierra (río y lago).
    fresh = land & blue & (v > 0.45)
    fresh = ndi.binary_opening(fresh, iterations=1)
    lab, n = ndi.label(fresh)
    sizes = ndi.sum(fresh, lab, range(1, n + 1))
    fresh = np.isin(lab, [i + 1 for i, sz in enumerate(sizes) if sz > 300])
    # Zona corrupta: donde dominan los morados (por zonas, no píxel a píxel).
    purple = ((h > 250) & (h < 340) & (s > 0.2)).astype(np.float32)
    corrupt = land & (ndi.uniform_filter(purple, 41) > 0.18)
    corrupt = ndi.binary_closing(corrupt, iterations=6) & land
    # Nieve y roca (gris).
    snow = land & (s < 0.2) & (v > 0.68)
    rock = land & (s < 0.32) & (v < 0.68) & (v > 0.08) & ~snow
    # Campos (dorado intenso) y caminos (tierra: marrón claro, líneas finas).
    golden = land & (h > 38) & (h < 58) & (s > 0.55) & (v > 0.55)
    field = ndi.binary_opening(golden, iterations=4)
    # Caminos: tierra marrón clara en líneas de 5-8 px. Se quitan las manchas anchas (campos, arena)
    # y los trocitos sueltos (paredes de casas, bordes de iconos).
    raw_hsv = hsv(rgb)
    tan = land & (raw_hsv[0] > 20) & (raw_hsv[0] < 50) & (raw_hsv[1] > 0.3) & (raw_hsv[1] < 0.72) & (raw_hsv[2] > 0.5) & ~field
    tan = ndi.binary_closing(tan, iterations=1)
    blobs = ndi.binary_opening(tan, iterations=5)
    road = tan & ~ndi.binary_dilation(blobs, iterations=2)
    lab, n = ndi.label(road)
    sizes = ndi.sum(road, lab, range(1, n + 1))
    road = np.isin(lab, [i + 1 for i, sz in enumerate(sizes) if sz > 150])
    road = ndi.binary_closing(road, iterations=2)
    # Arena: amarillo claro junto al mar.
    near_sea = ndi.distance_transform_edt(~ocean) < 40
    sand = land & near_sea & (h > 30) & (h < 70) & (s > 0.12) & (s < 0.55) & (v > 0.68)
    sand = ndi.binary_opening(sand, iterations=2)
    # Bosque: verde oscuro (copas); el resto de verde, pradera.
    green = land & (h > 70) & (h < 160)
    # Bosque por zonas: donde abundan las copas verde oscuro (el dibujo es casi todo bosque).
    dark = (green & (v < 0.45)).astype(np.float32)
    forest = green & (ndi.uniform_filter(dark, 15) > 0.35)
    cls[land & green] = GRASS
    cls[forest] = FOREST
    cls[sand] = SAND
    cls[rock] = ROCK
    cls[snow] = SNOW
    cls[field] = FIELD
    cls[road] = ROAD
    cls[corrupt & ~fresh] = CORRUPT
    cls[fresh] = FRESH
    # Suavizar: la clase más votada en una ventana pequeña (quita el moteado del dibujo).
    smooth = np.zeros_like(cls)
    best = np.zeros((N, N), np.float32)
    for c in range(11):
        if c in (ROAD,):
            continue
        votes = ndi.uniform_filter((cls == c).astype(np.float32), 7)
        better = votes > best
        smooth[better] = c
        best[better] = votes[better]
    smooth[cls == ROAD] = ROAD
    return smooth, {"ocean": ocean, "fresh": fresh, "corrupt": corrupt, "snow": snow, "rock": rock,
                    "road": road, "field": field, "sand": sand, "forest": forest, "rgb": rgb}


def class_image(cls):
    out = np.zeros((N, N, 3), np.uint8)
    for c, col in CLASS_COLORS.items():
        out[cls == c] = col
    return out


# ------------------------------------------------------------------ relieve

# Ríos trazados sobre el dibujo (píxeles del mapa de 1024): bajan del lago al mar.
# Medidos sobre el agua azul del dibujo (cauce y puentes), del lago al mar.
RIVER_SOUTH = [(715, 400), (690, 403), (673, 404), (667, 427), (657, 457), (647, 480), (643, 500), (633, 513),
               (610, 540), (597, 560), (588, 580), (587, 595), (595, 620), (585, 650), (570, 680), (555, 710), (550, 740), (555, 755),
               (575, 780), (610, 805), (640, 825), (670, 845), (690, 865), (705, 880), (712, 892), (720, 905)]
RIVER_WEST = [(690, 405), (675, 407), (650, 402), (625, 392), (607, 372), (590, 360), (570, 352), (550, 345),
              (530, 335), (510, 315), (485, 295), (460, 280), (430, 255), (410, 245), (395, 238), (385, 232)]
RIVER_WIDTH = {"south": 6.5, "west": 4.5}   # medio ancho del cauce (px)
LAKE = (760, 358)            # centro del lago en la meseta
LAKE_LEVEL = 62.0            # nivel del agua del lago (voxels)
PEAK = (835, 470)            # cumbre de la montaña (centro de la nieve)
RUINS = (240, 185)           # colina de las ruinas del noroeste
VILLAGES = [((300, 478), 100.0), ((135, 645), 65.0)]  # pueblo principal (B) y pueblo pesquero (A): llanos


def fbm(seed, scale, octaves=4):
    """Ruido suave en [-1, 1]: ruido blanco difuminado a varias escalas (colinas, no grumos).
    'scale' = cuántas ondas caben a lo ancho del mapa en la primera octava."""
    rng = np.random.default_rng(seed)
    out = np.zeros((N, N), np.float32)
    amp = 1.0
    for o in range(octaves):
        sigma = N / (scale * 2 ** o) / 2.5
        layer = ndi.gaussian_filter(rng.standard_normal((N, N)).astype(np.float32), sigma, mode="wrap")
        layer /= layer.std() + 1e-6
        out += layer * amp
        amp *= 0.5
    return np.clip(out / (2.2 * out.std() + 1e-6), -1, 1)


def ridged(seed, scale, octaves=5):
    """Ruido de crestas en [0, 1] (aristas afiladas para la montaña)."""
    r = 1.0 - np.abs(fbm(seed, scale, octaves))
    return r ** 2.0


def mountain_shape(xx, yy):
    """Montaña de verdad: cumbre, crestas retorcidas que bajan con valles entre ellas y laderas
    que se suavizan abajo. Devuelve la altura que añade (voxels)."""
    # Deformar el espacio para que las crestas no salgan rectas.
    wx = xx + fbm(31, 5, 3) * 28.0
    wy = yy + fbm(32, 5, 3) * 28.0
    dx = (wx - PEAK[0])
    dy = (wy - PEAK[1]) / 1.2
    r = np.hypot(dx, dy)
    ang = np.arctan2(dy, dx)
    t = np.clip(1.0 - r / 215.0, 0, 1)
    profile = t ** 1.7
    # Espolones de altura desigual (cada uno con su propia fuerza) que bajan de la cumbre.
    rng = np.random.default_rng(33)
    count = 6
    phases = rng.uniform(0, np.pi * 2)
    strength = rng.uniform(0.4, 1.0, count)
    sector = ((ang + np.pi + phases) / (np.pi * 2) * count) % count
    k0 = np.floor(sector).astype(int) % count
    k1 = (k0 + 1) % count
    f = sector - np.floor(sector)
    ridge_line = np.cos((f - 0.5) * np.pi) ** 2  # 1 en medio del sector (la cresta), 0 en los valles
    amp = strength[k0] * (1 - f) + strength[k1] * f
    # Los espolones mandan a media ladera: ni en la cumbre (sería una estrella) ni abajo.
    spurs = ridge_line * amp * (4.0 * t * (1.0 - t)) ** 0.8
    # Aristas finas y canales: crestas estrechas del ruido (|ruido| cerca de 0).
    crests = (1.0 - np.abs(fbm(34, 7, 4))) ** 7
    gullies = (1.0 - np.abs(fbm(35, 14, 3))) ** 9
    shape = profile * (110.0 + 55.0 * spurs) + t ** 1.1 * (crests * 30.0 - gullies * 12.0)
    for (px, py), hh, rr in (((790, 410), 30.0, 65.0), ((885, 565), 40.0, 80.0), ((760, 520), 22.0, 60.0)):
        rs = np.hypot(xx - px, yy - py)
        shape += hh * np.clip(1.0 - rs / rr, 0, 1) ** 1.8
    return np.maximum(shape, 0.0)


def polyline_mask(points, width):
    """Distancia (px) de cada píxel a la línea, y a qué fracción del recorrido cae (0 = fuente)."""
    from PIL import ImageDraw
    pts = [(float(x), float(y)) for x, y in points]
    # Densificar.
    dense = []
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
        steps = int(max(abs(x1 - x0), abs(y1 - y0))) + 1
        for k in range(steps):
            t = k / steps
            dense.append((x0 + (x1 - x0) * t, y0 + (y1 - y0) * t))
    dense.append(pts[-1])
    seed_img = np.zeros((N, N), bool)
    order = np.full((N, N), -1, np.int32)
    for k, (x, y) in enumerate(dense):
        xi, yi = int(round(x)), int(round(y))
        if 0 <= xi < N and 0 <= yi < N:
            seed_img[yi, xi] = True
            order[yi, xi] = k
    dist, idx = ndi.distance_transform_edt(~seed_img, return_indices=True)
    frac = order[idx[0], idx[1]] / max(len(dense) - 1, 1)
    return dist, frac


def relief(cls, masks):
    ocean = masks["ocean"]
    land = ~ocean
    d_sea = ndi.distance_transform_edt(land)            # px hasta el mar (en tierra)
    d_land = ndi.distance_transform_edt(ocean)          # px hasta la tierra (en el mar)
    yy, xx = np.mgrid[0:N, 0:N].astype(np.float32)
    # --- Mar: plataforma somera turquesa junto a la costa y fondo hondo lejos.
    h = np.where(ocean, SEA - 1.5 - np.minimum(d_land, 60) * 0.32, 0).astype(np.float32)
    h = np.maximum(h, 4.0)
    # --- Tierra: sube desde la costa y forma lomas suaves.
    hills = fbm(11, 4, 3) * 9.0 + fbm(12, 12, 2) * 2.5
    base = SEA + 1.2 + 10.0 * np.clip(d_sea / 70.0, 0, 1) ** 0.8 + 9.0 * np.clip(d_sea / 220.0, 0, 1)
    base += hills * np.clip(d_sea / 40.0, 0, 1)
    # Playas: donde el dibujo pinta arena, rampa suave y baja.
    sand = ndi.gaussian_filter((cls == SAND).astype(np.float32), 6)
    beach = SEA + 0.8 + np.minimum(d_sea, 40) * 0.08
    base = base * (1 - np.clip(sand * 1.5, 0, 1)) + beach * np.clip(sand * 1.5, 0, 1)
    # Acantilados: roca pintada junto al mar -> pared que sale del agua.
    coast_rock = ndi.gaussian_filter(((cls == ROCK) & (d_sea < 30)).astype(np.float32), 5)
    cliff = np.clip(coast_rock * 2.2, 0, 1) * np.clip(1.0 - (d_sea - 25) / 40.0, 0, 1)
    base = np.maximum(base, base + cliff * (12.0 + 6.0 * fbm(13, 10, 3)))
    # Colina de las ruinas: meseta de laderas empinadas.
    r = np.hypot(xx - RUINS[0], yy - RUINS[1])
    base += 12.0 * np.clip((105 - r) / 35.0, 0, 1) ** 1.5
    # Zona corrupta: tierras altas con agujas de roca oscura.
    corrupt = ndi.gaussian_filter(masks["corrupt"].astype(np.float32), 10)
    base += corrupt * (16.0 + 6.0 * fbm(14, 6, 3))
    # Agujas: pináculos sueltos de roca oscura, repartidos por la zona (como las del dibujo).
    rng = np.random.default_rng(15)
    cz = np.argwhere(ndi.binary_erosion(masks["corrupt"], iterations=12))
    for k in rng.choice(len(cz), size=min(26, len(cz)), replace=False) if len(cz) else []:
        py, px = cz[k]
        rr = rng.uniform(5, 11)
        hh = rng.uniform(10, 30)
        rs = np.hypot(xx - px, yy - py)
        base += hh * np.clip(1.0 - rs / rr, 0, 1) ** 0.9
    # --- Montaña: cumbre nevada con crestas en abanico y valles (ver mountain_shape). Se limita a
    # donde el dibujo pinta montaña (nieve y roca del este), con un borde suave.
    mtn_paint = ndi.gaussian_filter(((cls == SNOW) | ((cls == ROCK) & (xx > 640) & (yy > 360) & (yy < 820))).astype(np.float32), 25)
    region = np.clip(mtn_paint * 3.0, 0, 1) ** 0.7
    region = np.maximum(region, np.clip(1.0 - np.hypot(xx - PEAK[0], (yy - PEAK[1]) / 1.2) / 150.0, 0, 1))
    base += mountain_shape(xx, yy) * region * land
    # --- Lago en su meseta: la meseta se levanta hasta el nivel del lago.
    rl = np.hypot((xx - LAKE[0]) / 1.0, (yy - LAKE[1]) * 1.35)
    lake = (masks["fresh"] & (rl < 80)) | (rl < 50)
    plateau = np.clip((115 - rl) / 50.0, 0, 1)
    base = np.maximum(base, (LAKE_LEVEL + 2.0) * plateau + base * (1 - plateau))
    h = np.where(land, base, h)
    water = np.zeros((N, N), np.float32)
    lake_soft = ndi.binary_dilation(lake, iterations=2)
    h[lake_soft] = LAKE_LEVEL - 4.0 - 2.0 * np.clip(ndi.distance_transform_edt(lake_soft)[lake_soft] / 15.0, 0, 1)
    water[lake_soft] = LAKE_LEVEL
    # --- Ríos: el agua baja siempre del lago al mar; el valle se abre alrededor del cauce.
    for points, top, half in ((RIVER_SOUTH, LAKE_LEVEL - 6.0, RIVER_WIDTH["south"]),
                              (RIVER_WEST, LAKE_LEVEL - 10.0, RIVER_WIDTH["west"])):
        dist, frac = polyline_mask(points, half)
        level = SEA + 0.2 + (top - SEA) * (1.0 - frac) ** 1.15
        bed = dist < half
        valley = np.clip(1.0 - (dist - half) / 38.0, 0, 1) ** 1.5
        target = level + 1.6 + (dist - half) * 0.35
        lower = land & (dist < 45)
        h = np.where(lower, np.minimum(h, h * (1 - valley) + np.maximum(target, level + 1.6) * valley), h)
        h = np.where(bed & land, level - 2.5, h)
        water = np.where(bed & land, np.maximum(water, level), water)
    # --- Otras aguas pintadas dentro de la isla (la cala del norte donde desemboca el río del
    # oeste): agua al nivel del mar (la cubre el plano del mar).
    lagoon = masks["fresh"] & ~lake_soft & (water == 0)
    lagoon = ndi.binary_dilation(lagoon, iterations=2) & (water == 0)
    h = np.where(lagoon, np.minimum(h, SEA - 3.0), h)
    # --- Llanos: caminos un poco suavizados, campos y pueblos aplanados.
    smooth_h = ndi.gaussian_filter(h, 6)
    road = ndi.binary_dilation(masks["road"], iterations=1) & land & (water == 0)
    h = np.where(road, h * 0.4 + smooth_h * 0.6, h)
    for (cx, cy), radius in VILLAGES:
        rv = np.hypot(xx - cx, yy - cy)
        flat = np.clip((radius - rv) / 25.0, 0, 1) * land * (water == 0)
        mean = float(np.median(h[(rv < radius * 0.6) & land]))
        h = h * (1 - flat) + max(mean, SEA + 2.0) * flat
    field = ndi.binary_dilation(cls == FIELD, iterations=2) & land
    h = np.where(field, h * 0.3 + ndi.gaussian_filter(h, 10) * 0.7, h)
    # La costa siempre por encima del agua donde no hay arena (si no, quedarían charcos).
    h = np.where(land & (h < SEA + 0.8), SEA + 0.8, h)
    return h, water


# ------------------------------------------------------------------ superficie y árboles

BL_GRASS, BL_DIRT, BL_STONE, BL_SAND, BL_SNOW, BL_CORRUPT, BL_WHEAT = 1, 2, 3, 4, 5, 10, 12
TREE_BROAD, TREE_PINE, TREE_DEAD = 1, 2, 3


def surface(cls, masks, h, water):
    ocean = masks["ocean"]
    land = ~ocean
    gy, gx = np.gradient(ndi.gaussian_filter(h, 1.5))
    slope = np.hypot(gx, gy)
    top = np.full((N, N), BL_GRASS, np.uint8)
    sub = np.full((N, N), BL_DIRT, np.uint8)
    yy, xx = np.mgrid[0:N, 0:N]
    mountain = np.hypot(xx - PEAK[0], (yy - PEAK[1]) / 1.25) < 230
    # Arena: en el mar (fondo) y en las playas pintadas.
    beach = (cls == SAND) | (land & (h < SEA + 2.2) & (ndi.distance_transform_edt(land) < 10))
    top[ocean | beach] = BL_SAND
    sub[ocean | beach] = BL_SAND
    rock = (cls == ROCK) | (slope > 1.15)
    top[land & rock] = BL_STONE
    sub[land & rock] = BL_STONE
    snow = land & ((cls == SNOW) | (mountain & (h > 150) & (slope < 1.6)))
    top[snow] = BL_SNOW
    sub[snow] = BL_STONE
    corrupt = land & ndi.binary_dilation(masks["corrupt"], iterations=2)
    top[corrupt & ~rock] = BL_CORRUPT
    road = land & (cls == ROAD) & (water == 0) & ~rock
    top[road] = BL_DIRT
    field = land & (cls == FIELD)
    top[field] = np.where((xx[field] >> 1) & 1 == 0, BL_WHEAT, BL_DIRT)
    top[land & (water > 0)] = BL_DIRT  # fondo de ríos y lago (el juego pone grava y arcilla)
    # Árboles: B = tipo * 64 + densidad en milésimas (máx. 63).
    dens = np.zeros((N, N), np.int32)
    kind = np.zeros((N, N), np.int32)
    forest = ndi.gaussian_filter((cls == FOREST).astype(np.float32), 4)
    meadow = (cls == GRASS)
    grassy = land & (top == BL_GRASS) & (water == 0)
    dens[grassy] = (6 + forest[grassy] * 70).astype(np.int32)
    dens[grassy & meadow & (forest < 0.25)] = 4
    kind[grassy] = TREE_BROAD
    high = grassy & ((h > 70) | (mountain & (h > 45)))
    kind[high] = TREE_PINE
    dead = corrupt & ~rock
    kind[dead] = TREE_DEAD
    dens[dead] = 8
    # Sin árboles en caminos, campos, pueblos, playas ni sobre roca o nieve.
    for (cx, cy), radius in VILLAGES:
        dens[np.hypot(xx - cx, yy - cy) < radius] = 0
    dens[road | field | beach | rock | snow | ocean | (water > 0)] = 0
    dens = np.clip(dens, 0, 63)
    trees = (kind * 64 + dens).astype(np.uint8)
    trees[dens == 0] = 0
    return top, sub, trees


def encode16(values):
    v = np.clip(np.round(values * 64.0), 0, 65535).astype(np.uint32)
    out = np.zeros((N, N, 3), np.uint8)
    out[..., 0] = (v >> 8) & 255
    out[..., 1] = v & 255
    return out


def preview(h, water, top, trees):
    colors = {BL_GRASS: (110, 170, 70), BL_DIRT: (150, 110, 70), BL_STONE: (130, 130, 130), BL_SAND: (225, 205, 145),
              BL_SNOW: (240, 242, 245), BL_CORRUPT: (95, 55, 110), BL_WHEAT: (225, 195, 70)}
    img = np.zeros((N, N, 3), np.float32)
    for b, c in colors.items():
        img[top == b] = c
    img[(trees & 63) > 20] *= 0.72  # bosque, más oscuro
    sea = h < SEA
    depth = np.clip((SEA - h) / 20.0, 0, 1)[..., None]
    img[sea] = (np.array([60, 190, 200]) * (1 - depth[sea]) + np.array([15, 50, 120]) * depth[sea])
    img[water > h] = (60, 150, 210)
    gy, gx = np.gradient(h)
    shade = np.clip(1.0 + (-gx - gy) * 0.08, 0.55, 1.35)[..., None]
    img = np.clip(img * shade, 0, 255).astype(np.uint8)
    return img


def main():
    rgb = load_map()
    cls, masks = classify(rgb)
    debug("clases", class_image(cls))
    h, water = relief(cls, masks)
    debug("altura", h)
    print("altura: mín %.1f máx %.1f (mar %.0f); agua dulce en %d px" % (h.min(), h.max(), SEA, int((water > 0).sum())))
    top, sub, trees = surface(cls, masks, h, water)
    os.makedirs(OUT, exist_ok=True)
    if "--sin-guardar" not in sys.argv:
        Image.fromarray(encode16(h)).save(os.path.join(OUT, "height.png"))
        Image.fromarray(encode16(np.where(water > 0, water, 0))).save(os.path.join(OUT, "water.png"))
        Image.fromarray(np.stack([top, sub, trees], -1)).save(os.path.join(OUT, "surface.png"))
        Image.fromarray(class_image(cls)).save(os.path.join(OUT, "biome.png"))
        Image.fromarray(preview(h, water, top, trees)).save(os.path.join(OUT, "preview.png"))
        print("mapas guardados en", OUT)
    debug("preview", preview(h, water, top, trees))
    print("clases:", {k: int((cls == c).sum()) for k, c in
                      [("mar", OCEAN), ("someras", SHALLOW), ("arena", SAND), ("hierba", GRASS), ("bosque", FOREST),
                       ("roca", ROCK), ("nieve", SNOW), ("corrupta", CORRUPT), ("agua", FRESH), ("camino", ROAD), ("campo", FIELD)]})


if __name__ == "__main__":
    main()
