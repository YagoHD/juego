#!/usr/bin/env python3
"""Saca la skin del náufrago de cajas (64x64, formato Minecraft) y su pelo de cubos de la hoja de
vistas de la guía visual (docs/estilo/guia_20_naufrago_vistas.png).

Uso:  python3 tools/skin_desde_guia.py

Cada cara de cada parte (cabeza, torso, brazos, piernas) se toma de su zona en la vista de frente,
de espaldas o de lado (medidas a mano sobre la hoja) y se reduce a sus píxeles de skin tomando el
color del centro de cada casilla. El pelo rizado, que sobresale mucho de la cabeza, se reconstruye
como un montón de cubos de 1 píxel de skin: hay cubo donde las vistas de frente y de lado ven pelo
(como una silueta en 3D). Salen:
  assets/skins/naufrago/skin.png  (skin al doble, 128x128, brazos de 4 px)
  assets/skins/naufrago/pelo.json (cubos del pelo: posición en píxeles de skin desde el cuello y color)
"""
import json
import os

import numpy as np
from PIL import Image

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
SHEET = os.path.join(ROOT, "docs", "estilo", "guia_20_naufrago_vistas.png")
OUT = os.path.join(ROOT, "assets", "skins", "naufrago")

# Inicio (x) de cada vista en la hoja; todas las medidas de abajo son relativas a su vista.
FRONT, SIDE, BACK = 134, 524, 896  # la vista "izquierda" muestra el lado derecho (mira a la derecha)
S = 23.75  # píxeles de la hoja por píxel de skin (la cabeza de 8 px mide 190)
K = 2  # la skin va al doble de resolución (128x128, misma distribución): la guía tiene ese detalle

# Zonas (x0, y0, x1, y1) de cada parte en cada vista. Frente: la derecha del personaje está a la
# izquierda de la imagen; espalda: al revés.
ZONES = {
    "head": {"front": (97, 75, 287, 265), "back": (100, 75, 290, 265), "side": (75, 75, 265, 265)},
    "body": {"front": (97, 275, 280, 560), "back": (95, 275, 275, 560), "side": (110, 280, 210, 560)},
    "arm_right": {"front": (30, 285, 100, 570), "back": (275, 285, 340, 570), "side": (105, 280, 215, 575)},
    "arm_left": {"front": (277, 285, 340, 570), "back": (30, 285, 95, 570), "side": (105, 280, 215, 575)},
    "leg_right": {"front": (92, 560, 185, 805), "back": (182, 560, 275, 805), "side": (100, 560, 215, 805)},
    "leg_left": {"front": (185, 560, 280, 805), "back": (90, 560, 182, 805), "side": (100, 560, 215, 805)},
}
VIEW_X = {"front": FRONT, "back": BACK, "side": SIDE}

# Origen en la skin (capa base) y tamaño (ancho, alto, fondo) de cada parte, como en SkinModel.PARTS.
PARTS = {
    "head": ((0, 0), (8, 8, 8)),
    "body": ((16, 16), (8, 12, 4)),
    "arm_right": ((40, 16), (4, 12, 4)),
    "arm_left": ((32, 48), (4, 12, 4)),
    "leg_right": ((0, 16), (4, 12, 4)),
    "leg_left": ((16, 48), (4, 12, 4)),
}


# Capa exterior (sobresale un poco): origen en la skin y filas que se copian de la base para que
# abulten como en la guía: mangas y muñequeras, cinturón, rodilleras y botas.
OVERLAY = {
    "body": ((16, 32), [8, 9]),
    "arm_right": ((40, 32), [0, 1, 2, 3, 7, 8]),
    "arm_left": ((48, 48), [0, 1, 2, 3, 7, 8]),
    "leg_right": ((0, 32), [5, 6, 10, 11]),
    "leg_left": ((0, 48), [5, 6, 10, 11]),
}


def face_rects(origin, size):
    """Igual que SkinModel.face_rects: (x, y, ancho, alto) de cada cara en la skin."""
    ox, oy = origin[0] * K, origin[1] * K
    w, h, d = size[0] * K, size[1] * K, size[2] * K
    return {
        "top": (ox + d, oy, w, d), "bottom": (ox + d + w, oy, w, d),
        "right": (ox, oy + d, d, h), "front": (ox + d, oy + d, w, h),
        "left": (ox + d + w, oy + d, d, h), "back": (ox + 2 * d + w, oy + d, w, h),
    }


def sample(sheet, view, zone, cols, rows, mirror=False):
    """Colores (rows x cols) de una zona de una vista: la mediana del centro de cada casilla."""
    x0, y0, x1, y1 = zone
    x0 += VIEW_X[view]
    x1 += VIEW_X[view]
    out = np.zeros((rows, cols, 3))
    for j in range(rows):
        for i in range(cols):
            cx0, cx1 = x0 + (i + 0.3) * (x1 - x0) / cols, x0 + (i + 0.7) * (x1 - x0) / cols
            cy0, cy1 = y0 + (j + 0.3) * (y1 - y0) / rows, y0 + (j + 0.7) * (y1 - y0) / rows
            cell = sheet[int(cy0):int(cy1) + 1, int(cx0):int(cx1) + 1].reshape(-1, 3)
            out[j, i] = np.median(cell, axis=0)
    # Casillas que cayeron en el fondo de la hoja (crema): el color de la casilla buena más cercana.
    bg = (out[..., 2] > 215) & (out[..., 0] > 240)
    good = np.argwhere(~bg)
    for j, i in np.argwhere(bg):
        if len(good):
            k = np.argmin(np.abs(good - [j, i]).sum(1) + np.abs(good[:, 0] - j) * 0.5)  # mejor en la misma fila
            out[j, i] = out[tuple(good[k])]
    return out[:, ::-1] if mirror else out


def is_hair(c):
    r, g, b = c[..., 0], c[..., 1], c[..., 2]
    return (r < 175) & (r > 35) & (g < r * 0.8) & (b < g * 1.05) & (r + g + b < 380)


# La cara, a 8x8 se pierde al reducirla (los ojos quedan en medio de dos casillas): se dibuja con
# el mismo diseño que la de la guía (flequillo, cejas, ojos de blanco y pupila, nariz y boca) y
# sus colores. H pelo, h pelo o piel (lo que salga de la hoja), B ceja, W blanco del ojo, P pupila,
# S piel, N nariz, M boca.
FACE = [
    "HHHHHHHH",
    "HHHHHHHH",
    "HHhHhhHH",
    "HBBSSBBH",
    "SWPSSPWS",
    "SWPSSPWS",
    "SSSNNSSS",
    "SSSMMSSS",
]
FACE_COLORS = {"B": (58, 36, 25), "W": (240, 228, 212), "P": (34, 27, 23), "S": (250, 172, 108),
               "N": (232, 150, 92), "M": (196, 112, 70)}


def face_front(sampled):
    out = sampled.copy()
    for j, row in enumerate(FACE):
        for i, key in enumerate(row):
            if key in FACE_COLORS:
                out[j, i] = FACE_COLORS[key]
            elif key == "h" and not is_hair(sampled[j, i]):
                out[j, i] = FACE_COLORS["S"]
            elif key == "H" and not is_hair(sampled[j, i]):
                out[j, i] = sampled[0, i] if is_hair(sampled[0, i]) else (90, 52, 32)
    return out


def build_skin(sheet):
    skin = np.zeros((64 * K, 64 * K, 4), dtype=np.uint8)
    for part, (origin, size) in PARTS.items():
        w, h, d = size[0] * K, size[1] * K, size[2] * K
        rects = face_rects(origin, size)
        zones = ZONES[part]
        faces = {
            "front": sample(sheet, "front", zones["front"], w, h),
            "back": sample(sheet, "back", zones["back"], w, h),
            "right": sample(sheet, "side", zones["side"], d, h),
            "left": sample(sheet, "side", zones["side"], d, h, mirror=True),
        }
        if part == "body":  # el lado del torso no se ve (lo tapa el brazo): su borde de delante y detrás
            front, back = faces["front"], faces["back"]
            side = np.stack([back[:, 0]] * (d // 2) + [front[:, -1]] * (d - d // 2), axis=1)
            faces["right"] = side
            faces["left"] = side[:, ::-1]
        # Tapas: arriba, la primera fila de delante y detrás; abajo, la última.
        top_row = (faces["front"][0] + faces["back"][0][::-1]) / 2
        bottom_row = (faces["front"][-1] + faces["back"][-1][::-1]) / 2
        faces["top"] = np.repeat(top_row[None], d, axis=0)
        faces["bottom"] = np.repeat(bottom_row[None], d, axis=0)
        if part == "head":  # arriba, pelo (de la vista de espaldas); abajo, el cuello
            hair = sample(sheet, "back", (100, 20, 290, 90), w, d)
            faces["top"] = hair
            faces["bottom"] = np.repeat(faces["front"][-1:].mean(axis=1, keepdims=True), d, axis=0).repeat(w, 1)
        for name, (x, y, fw, fh) in rects.items():
            skin[y:y + fh, x:x + fw, :3] = faces[name].clip(0, 255).astype(np.uint8)
            skin[y:y + fh, x:x + fw, 3] = 255
        if part in OVERLAY:
            over_origin, rows = OVERLAY[part]
            over = face_rects(over_origin, size)
            for name in ("front", "back", "right", "left"):
                bx, by = rects[name][:2]
                ox, oy, fw, fh = over[name]
                for r in [k * K + i for k in rows for i in range(K)]:
                    skin[oy + r, ox:ox + fw] = skin[by + r, bx:bx + fw]
            if 0 in rows:  # la manga se cierra por arriba
                bx, by, fw, fh = rects["top"]
                ox, oy = over["top"][:2]
                skin[oy:oy + fh, ox:ox + fw] = skin[by:by + fh, bx:bx + fw]
    return skin


def build_hair(sheet):
    """Cubos del pelo: donde las vistas de frente y de lado ven pelo, fuera de la caja de la cabeza."""
    head_f, head_s, head_b = ZONES["head"]["front"], ZONES["head"]["side"], ZONES["head"]["back"]
    cf = (head_f[0] + head_f[2]) / 2 + FRONT  # centro de la cabeza en cada vista
    cs = (head_s[0] + head_s[2]) / 2 + SIDE
    cb = (head_b[0] + head_b[2]) / 2 + BACK
    neck_y = head_f[3]
    h, w = sheet.shape[:2]

    def color_at(x, y):
        x, y = int(x), int(y)
        if not (0 <= x < w and 0 <= y < h):
            return None
        return np.median(sheet[max(y - 5, 0):y + 6, max(x - 5, 0):x + 6].reshape(-1, 3), axis=0)

    def tone_at(x, y):
        # Tono de la cara del cubo, no de las rendijas oscuras entre cubos: de los más claros
        # que sean pelo.
        x, y = int(x), int(y)
        win = sheet[max(y - 8, 0):y + 9, max(x - 8, 0):x + 9].reshape(-1, 3)
        win = win[is_hair(win)]
        return np.percentile(win, 70, axis=0) if len(win) else None

    cubes = []
    for yy in range(0, 13):
        for xx in range(-7, 7):
            for zz in range(-6, 7):
                X, Y, Z = xx + 0.5, yy + 0.5, zz + 0.5
                inside = abs(X) < 4 and Y < 8 and abs(Z) < 4
                if inside:
                    continue
                py = neck_y - Y * S
                front = color_at(cf - X * S, py)
                side = color_at(cs - Z * S, py)
                if front is None or side is None or not is_hair(front) or not is_hair(side):
                    continue
                # Solo pelo que toque la cabeza o a otro cubo (nada flotando) y no delante de la cara.
                if Z < -4 and Y < 6.5:
                    continue
                back = color_at(cb + X * S, py)
                if Z > 4 and (back is None or not is_hair(back)):
                    continue
                # Color de la vista desde la que más se ve ese cubo.
                if Z < -4:
                    col = tone_at(cf - X * S, py)
                elif Z > 4:
                    col = tone_at(cb + X * S, py)
                elif abs(X) >= 4:
                    col = tone_at(cs - Z * S, py)
                else:
                    col = tone_at(cb + X * S, py) if Z > 0 else tone_at(cf - X * S, py)
                if col is None:
                    col = front
                cubes.append([xx, yy, zz, "#%02x%02x%02x" % tuple(int(v) for v in col.clip(0, 255))])
    # Copa redondeada y con bultos, como los rizos de la guía: sobre la cabeza se apila una capa
    # más (no en todas las columnas) y se quitan las esquinas del ala, que la dejan como un sombrero.
    cells = {(c[0], c[1], c[2]): c[3] for c in cubes}
    top = {}
    for (x, y, z) in cells:
        top[(x, z)] = max(top.get((x, z), -1), y)
    for (x, z), y in top.items():
        r = (x + 0.5) ** 2 + (z + 0.5) ** 2
        if y >= 8 and r < 22 and (x * 7 + z * 13) % 5 != 0:
            cubes.append([x, y + 1, z, cells[(x, y, z)]])
            if r < 8 and (x * 3 + z * 5) % 3 == 0:
                cubes.append([x, y + 2, z, cells[(x, y, z)]])
    cubes = [c for c in cubes if not (c[1] >= 8 and (c[0] + 0.5) ** 2 + (c[2] + 0.5) ** 2 > 38)]

    # Rellenar huecos: una casilla vacía rodeada de pelo por 4 o más lados también es pelo (los
    # rizos de la guía forman una masa llena, sin agujeros).
    for _ in range(2):
        cells = {(c[0], c[1], c[2]): c[3] for c in cubes}
        added = []
        for (x, y, z) in list(cells):
            for dx, dy, dz in ((1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0), (0, 0, 1), (0, 0, -1)):
                n = (x + dx, y + dy, z + dz)
                if n in cells or (abs(n[0] + 0.5) < 4 and n[1] < 8 and abs(n[2] + 0.5) < 4) or n[1] < 0:
                    continue
                around = [cells[(n[0] + a, n[1] + b, n[2] + c)] for a, b, c in
                          ((1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0), (0, 0, 1), (0, 0, -1))
                          if (n[0] + a, n[1] + b, n[2] + c) in cells]
                if len(around) >= 4 and not (n[2] < -4 and n[1] < 6.5):
                    added.append([n[0], n[1], n[2], around[0]])
        seen = set()
        for c in added:
            if (c[0], c[1], c[2]) not in seen:
                seen.add((c[0], c[1], c[2]))
                cubes.append(c)
    return cubes


def main():
    sheet = np.asarray(Image.open(SHEET).convert("RGB")).astype(float)
    os.makedirs(OUT, exist_ok=True)
    skin = build_skin(sheet)
    Image.fromarray(skin, "RGBA").save(os.path.join(OUT, "skin.png"))
    hair = build_hair(sheet)
    with open(os.path.join(OUT, "pelo.json"), "w") as f:
        json.dump({"cubos": hair}, f)
    print("skin: %s; pelo: %d cubos" % (os.path.join(OUT, "skin.png"), len(hair)))


if __name__ == "__main__":
    main()
