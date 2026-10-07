#!/usr/bin/env python3
"""Recorta las hojas de la guía visual (docs/estilo) en texturas e iconos para el juego.

Uso (en la nube o en un PC con Python y Pillow):  python3 tools/cortar_hojas.py [bloques|iconos|plantas|todo]

Las hojas de ChatGPT son rejillas: cada casilla es un cuadro (textura o icono) con su nombre
debajo. Se buscan los cuadros por el contraste con el fondo crema, se recortan y se reducen:
  - texturas de bloque: a 16x16 píxeles (las de ChatGPT son pixel art de 16x16 ampliado);
  - iconos: a 64x64 con el fondo quitado (transparente).
"""
import os
import sys

import numpy as np
from PIL import Image

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
STYLE = os.path.join(ROOT, "docs", "estilo")
BLOCKS = os.path.join(ROOT, "assets", "textures", "blocks")
BLOCKS_NEW = os.path.join(ROOT, "assets", "textures", "blocks_extra")
ICONS = os.path.join(ROOT, "assets", "textures", "items")
DECOR = os.path.join(ROOT, "assets", "textures", "decor")


def _runs(profile, threshold, min_len):
    runs, start = [], None
    for i, on in enumerate(profile > threshold):
        if on and start is None:
            start = i
        if not on and start is not None:
            runs.append((start, i))
            start = None
    if start is not None:
        runs.append((start, len(profile)))
    return [r for r in runs if r[1] - r[0] >= min_len]


def _background(img):
    corners = [img[2, 2], img[2, -3], img[-3, 2], img[-3, -3]]
    return np.median(np.array(corners), axis=0)


def texture_tiles(path, cols=4, rows=4):
    """Cuadros de textura (cuadrados) de una hoja, de izquierda a derecha y de arriba abajo.

    Las columnas salen del contraste con el fondo; las filas, de juntar las de todas las columnas
    (una textura clara, como la arena o la nieve, se confunde a veces con el fondo crema)."""
    img = np.asarray(Image.open(path).convert("RGB")).astype(int)
    mask = np.abs(img - _background(img)).sum(2) > 40
    h, w = mask.shape
    xs = _runs(mask.sum(0), h * 0.2, 80)[:cols]
    size = int(np.median([x1 - x0 for x0, x1 in xs]))
    starts, heights = [], []
    for x0, x1 in xs:
        for y0, y1 in _runs(mask[:, x0:x1].sum(1), (x1 - x0) * 0.6, size * 0.6):
            starts.append(y0)
            heights.append(y1 - y0)
    height = int(np.median(heights))  # las casillas no siempre son cuadradas del todo
    starts.sort()
    row_starts = []
    for y in starts:
        if not row_starts or y - row_starts[-1][-1] > size * 0.5:
            row_starts.append([y])
        else:
            row_starts[-1].append(y)
    ys = [int(np.median(group)) for group in row_starts][:rows]
    pil = Image.open(path).convert("RGB")
    return [pil.crop((x0, y0, x0 + size, y0 + height)) for y0 in ys for x0, x1 in xs]


def to_pixels(tile, size=16):
    """Reduce un cuadro de pixel art ampliado a su tamaño real tomando el color central de cada píxel."""
    w, h = tile.size
    margin = 6  # los bordes del cuadro a veces llevan sombra o línea
    tile = tile.crop((margin, margin, w - margin, h - margin))
    w, h = tile.size
    arr = np.asarray(tile).astype(float)
    out = np.zeros((size, size, 3))
    for j in range(size):
        for i in range(size):
            cx0, cx1 = int((i + 0.3) * w / size), int((i + 0.7) * w / size)
            cy0, cy1 = int((j + 0.3) * h / size), int((j + 0.7) * h / size)
            out[j, i] = np.median(arr[cy0:cy1 + 1, cx0:cx1 + 1].reshape(-1, 3), axis=0)
    # Si un borde salió del color del fondo de la hoja (crema), se repite la fila o columna vecina.
    cream = np.array([240.0, 232.0, 220.0])

    def stray(edge, inner):  # borde claro como el fondo y distinto de lo de dentro
        return np.abs(edge - cream).sum(-1).mean() < 140 and np.abs(edge - inner).sum(-1).mean() > 60

    for _ in range(2):
        if stray(out[-1], out[-2]):
            out[-1] = out[-2]
        if stray(out[0], out[1]):
            out[0] = out[1]
        if stray(out[:, -1], out[:, -2]):
            out[:, -1] = out[:, -2]
        if stray(out[:, 0], out[:, 1]):
            out[:, 0] = out[:, 1]
    return Image.fromarray(out.clip(0, 255).astype(np.uint8))


# Hoja -> nombres de las texturas del juego, en orden (None: no se usa aún; "extra:" para bloques futuros).
BLOCK_SHEETS = {
    "guia_10_bloques_suelo.png": [
        ["grass_top"], ["grass_side"], ["grass_top_flowers"], ["dirt", "dirt_side"],
        ["sand", "sand_side"], ["wet_sand", "wet_sand_side"], ["gravel", "gravel_side"], ["clay", "clay_side"],
        ["mud", "mud_side"], ["snow"], ["snow_side"], ["stone", "stone_side"],
        ["mossy_stone", "mossy_side"], ["ore", "ore_side"], ["extra:gold_ore"], ["corrupt_top", "corrupt_side"],
    ],
    "guia_11_bloques_madera.png": [
        ["log_side", "rot:log_side_h"], ["log_top"], ["dead_log_side", "rot:dead_log_side_h"], ["dead_log_top"],
        ["driftwood", "driftwood_side"], ["planks", "planks_side"], ["leaves"], ["pine_leaves"],
        ["chest_side"], ["chest_back"], ["chest_top"], ["workbench_top"],
        ["workbench_side"], ["cloth", "cloth_side"], ["extra:straw"], ["rope"],
    ],
    "guia_12_bloques_construccion.png": [
        ["extra:cobblestone"], ["extra:stone_bricks"], ["extra:cracked_stone_bricks"], ["extra:ruin_runes"],
        ["extra:timber_wall"], ["extra:roof_tiles"], ["extra:thatch"], ["extra:window"],
        ["extra:door_top"], ["extra:door_bottom"], ["extra:iron_block"], ["extra:gold_block"],
        ["extra:glass"], ["extra:wool"], ["extra:tower_stone"], ["extra:violet_crystal"],
    ],
}


def cut_blocks():
    os.makedirs(BLOCKS, exist_ok=True)
    os.makedirs(BLOCKS_NEW, exist_ok=True)
    for sheet, names in BLOCK_SHEETS.items():
        tiles = texture_tiles(os.path.join(STYLE, sheet))
        if len(tiles) != len(names):
            print(f"{sheet}: encontrados {len(tiles)} cuadros (se esperaban {len(names)})")
        for tile, outs in zip(tiles, names):
            pixels = to_pixels(tile)
            for name in outs:
                image = pixels
                if name.startswith("rot:"):
                    name = name[4:]
                    image = pixels.rotate(90)
                if name.startswith("extra:"):
                    image.save(os.path.join(BLOCKS_NEW, name[6:] + ".png"))
                else:
                    image.save(os.path.join(BLOCKS, name + ".png"))
        print(f"{sheet}: {len(tiles)} texturas")


PLANTS = ["tall_grass", "flower_red", "flower_yellow", "extra:pebbles", "extra:sticks", "extra:shell",
	"extra:wheat_1", "extra:wheat_2", "extra:wheat_3", "extra:mushrooms_red", "extra:mushrooms_brown",
	"extra:berry_bush", "extra:small_bush", "extra:fern", "extra:sapling", "extra:dawn_plant"]


def _sprite(cell, size):
    """Dibujo de una casilla con fondo (negro, blanco o magenta) quitado, encuadrado y reducido."""
    arr = np.asarray(cell.convert("RGB")).astype(int)
    total = arr.sum(2)
    r, g, b = arr[..., 0], arr[..., 1], arr[..., 2]
    background = (total < 70) | (total > 700) | ((r > 200) & (g < 90) & (b > 200)) \
        | ((r > 230) & (g > 230) & (b < 90)) | ((g > 220) & (r < 120) & (b < 120))  # halos amarillos y verdes
    ys, xs = np.where(~background)
    if len(xs) == 0:
        return None
    x0, x1, y0, y1 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
    side = max(x1 - x0, y1 - y0)
    cx, by = (x0 + x1) // 2, y1  # centrado y apoyado abajo (las plantas salen del suelo)
    box = (cx - side // 2, by - side, cx - side // 2 + side, by)
    rgba = np.zeros((size, size, 4), dtype=np.uint8)
    for j in range(size):
        for i in range(size):
            px = int(box[0] + (i + 0.5) * side / size)
            py = int(box[1] + (j + 0.5) * side / size)
            if 0 <= px < arr.shape[1] and 0 <= py < arr.shape[0] and not background[py, px]:
                rgba[j, i, :3] = arr[py, px]
                rgba[j, i, 3] = 255
    # Quitar puntitos sueltos (restos del fondo de la hoja): píxeles con casi nada alrededor.
    for _ in range(2):
        alpha = rgba[..., 3] > 0
        padded = np.pad(alpha, 1)
        neighbours = sum(np.roll(np.roll(padded, dy, 0), dx, 1) for dy in (-1, 0, 1) for dx in (-1, 0, 1)
                         if (dy, dx) != (0, 0))[1:-1, 1:-1]
        rgba[alpha & (neighbours <= 2)] = 0
    return Image.fromarray(rgba, "RGBA")


def cut_plants():
    os.makedirs(DECOR, exist_ok=True)
    extra = os.path.join(DECOR, "extra")
    os.makedirs(extra, exist_ok=True)
    sheet = Image.open(os.path.join(STYLE, "guia_13_plantas.png"))
    w, h = sheet.size
    for k, name in enumerate(PLANTS):
        cx, cy = k % 4, k // 4
        cell = sheet.crop((int((cx + 0.04) * w / 4), int((cy + 0.03) * h / 4),
                           int((cx + 0.96) * w / 4), int((cy + 0.80) * h / 4)))  # sin el nombre de abajo
        sprite = _sprite(cell, 16)
        if sprite is None:
            continue
        sprite = sprite.resize((32, 32), Image.NEAREST)
        if name.startswith("extra:"):
            sprite.save(os.path.join(extra, name[6:] + ".png"))
        else:
            sprite.save(os.path.join(DECOR, name + ".png"))
    print("plantas: %d" % len(PLANTS))


# Hojas de iconos (4x4, el nombre debajo de cada uno) -> id del objeto en el juego. Varios ids
# pueden compartir dibujo (las notas). None: casilla vacía.
ICON_SHEETS = {
    "guia_40_iconos_1.png": ["rope", "fiber", "sticks", "rock", "flint", "sharp_rock", "resin", "seeds",
                             "stone_knife", "stone_axe", "stone_pick", "spear", "torch", "board", "raw_fish",
                             "cooked_fish"],
    "iconos_2_herramientas.png": ["bow", "arrow", "wooden_shield", "campfire", "bedroll", "raft", "furnace",
                                  "captain_journal", ["note_belt", "note_backpack", "note_pick"], "rough_backpack",
                                  "backpack", "gold_nugget", "gold_coin", "green_ore", "shell", "leaf"],
    "iconos_3_comida.png": ["berries", "roasted_berries", "mushroom", "roasted_mushroom", "insect", "roasted_insect",
                            "roasted_seeds", "raw_crab", "cooked_crab", "wheat", "flatbread", "raw_meat",
                            "cooked_meat", "raw_poultry", "cooked_poultry", "dawn_bean"],
    "iconos_4_botin.png": ["hide", "bone", "tusk", "feather", "venom_gland", "iron_scrap", "arcane_dust",
                           "enemy_orders", "anchor_shard", "pine_needles", "bark", "flower_red", "flower_yellow",
                           "shirt", "pants", "belt"],
    "iconos_5_equipo.png": ["hide_cap", "hide_vest", "hide_trousers", "hide_boots", "hide_gloves", "sail_cloak",
                            "bone_necklace", "tusk_ring", "shell_amulet", "ancient_helm", "ancient_cuirass",
                            "ancient_greaves", "ancient_boots", "ancient_gauntlets", None, None],
}
ICON_SIZE = 32
ICONS_OLD = os.path.join(ROOT, "assets", "textures", "items_antiguos")


def _icon(cell):
    """Dibujo de una casilla de icono sin el fondo (ni su sombra), encuadrado y reducido."""
    arr = np.asarray(cell.convert("RGB")).astype(int)
    h, w = arr.shape[:2]
    border = np.concatenate([arr[:4].reshape(-1, 3), arr[-4:].reshape(-1, 3), arr[:, :4].reshape(-1, 3),
                             arr[:, -4:].reshape(-1, 3)])
    bg = np.median(border, axis=0)
    diff = arr - bg
    dist = np.abs(diff).sum(2)
    # Fondo: casi el color del fondo, o su sombra (más oscura pero del mismo tono y sin color propio).
    chroma = np.abs((arr[..., 0] - arr[..., 1]) - (bg[0] - bg[1])) + np.abs((arr[..., 1] - arr[..., 2]) - (bg[1] - bg[2]))
    like_bg = (dist < 45) | ((chroma < 20) & (arr.sum(2) > 3 * 125))
    # Solo cuenta como fondo lo que está unido al borde (no se come lo claro de dentro del dibujo).
    from collections import deque
    bgmask = np.zeros((h, w), bool)
    q = deque()
    for x in range(w):
        for y in (0, h - 1):
            if like_bg[y, x] and not bgmask[y, x]:
                bgmask[y, x] = True
                q.append((y, x))
    for y in range(h):
        for x in (0, w - 1):
            if like_bg[y, x] and not bgmask[y, x]:
                bgmask[y, x] = True
                q.append((y, x))
    while q:
        y, x = q.popleft()
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            ny, nx = y + dy, x + dx
            if 0 <= ny < h and 0 <= nx < w and like_bg[ny, nx] and not bgmask[ny, nx]:
                bgmask[ny, nx] = True
                q.append((ny, nx))
    ys, xs = np.where(~bgmask)
    if len(xs) < 50:
        return None
    x0, x1, y0, y1 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
    side = int(max(x1 - x0, y1 - y0) * 1.04)
    cx, cy = (x0 + x1) // 2, (y0 + y1) // 2
    rgba = np.zeros((h, w, 4), np.uint8)
    rgba[..., :3] = arr.clip(0, 255)
    rgba[..., 3] = np.where(bgmask, 0, 255)
    img = Image.fromarray(rgba, "RGBA").crop((cx - side // 2, cy - side // 2, cx - side // 2 + side, cy - side // 2 + side))
    # Reducir: color medio de lo que no es fondo; transparente si la casilla es casi toda fondo.
    big = np.asarray(img).astype(float)
    out = np.zeros((ICON_SIZE, ICON_SIZE, 4), np.uint8)
    step = side / ICON_SIZE
    for j in range(ICON_SIZE):
        for i in range(ICON_SIZE):
            block = big[int(j * step):max(int((j + 1) * step), int(j * step) + 1),
                        int(i * step):max(int((i + 1) * step), int(i * step) + 1)].reshape(-1, 4)
            solid = block[block[:, 3] > 0]
            if len(solid) >= len(block) * 0.45:
                out[j, i, :3] = np.median(solid[:, :3], axis=0)
                out[j, i, 3] = 255
    return Image.fromarray(out, "RGBA")


def cut_icons():
    os.makedirs(ICONS, exist_ok=True)
    os.makedirs(ICONS_OLD, exist_ok=True)
    gdignore = os.path.join(ICONS_OLD, ".gdignore")
    if not os.path.exists(gdignore):
        open(gdignore, "w").close()
    done = 0
    for sheet, names in ICON_SHEETS.items():
        img = Image.open(os.path.join(STYLE, sheet)).convert("RGB")
        w, h = img.size
        for k, name in enumerate(names):
            if name is None:
                continue
            cx, cy = k % 4, k // 4
            # Casilla sin el nombre de abajo (ni las rayas de la rejilla, si las hay).
            cell = img.crop((int((cx + 0.03) * w / 4), int((cy + 0.02) * h / 4),
                             int((cx + 0.97) * w / 4), int((cy + 0.78) * h / 4)))
            icon = _icon(cell)
            if icon is None:
                print("  sin dibujo:", sheet, k)
                continue
            for id_ in (name if isinstance(name, list) else [name]):
                path = os.path.join(ICONS, id_ + ".png")
                old = os.path.join(ICONS_OLD, id_ + ".png")
                if os.path.exists(path) and not os.path.exists(old):
                    os.replace(path, old)  # el dibujo antiguo se guarda aparte
                icon.save(path)
                done += 1
    print("iconos: %d" % done)


if __name__ == "__main__":
    what = sys.argv[1] if len(sys.argv) > 1 else "todo"
    if what in ("bloques", "todo"):
        cut_blocks()
    if what in ("plantas", "todo"):
        cut_plants()
    if what in ("iconos", "todo"):
        cut_icons()
