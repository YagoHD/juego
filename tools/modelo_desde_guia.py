#!/usr/bin/env python3
"""Modelo de CAJAS del náufrago (estilo Minecraft Dungeons) sacado de la hoja de vistas de la guía
(docs/estilo/guia_20_naufrago_vistas.png).

Uso:  python3 tools/modelo_desde_guia.py

No usa el formato de skin de Minecraft (6 cajas lisas): el personaje es un esqueleto con huesos en
cuello, mentón, cintura, hombros, codos, muñecas, caderas, rodillas y tobillos, y cada hueso lleva
sus cajas (medidas a mano sobre la hoja, en "píxeles" de 1/32 de la altura). La ropa son cajas un
poco más grandes que el cuerpo (se nota el relieve), y hay orejas, pulgares, pulseras, hombros
redondeados por escalones, manga rota en diagonal, trapo colgando del cinturón, bolsa y suelas.

El dibujo de cada cara se toma solo: la cara de delante de una caja, de su sitio en la vista de
frente; la de detrás, de la vista de espaldas; los lados, de la vista de lado. Así sirve para
cualquier personaje con una hoja de vistas (vecinos, enemigos...).

Salen assets/models/cajas/naufrago.json (huesos, cajas y sus trozos de textura) y naufrago.png.
"""
import json
import math
import os

import numpy as np
from PIL import Image

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
SHEET = os.path.join(ROOT, "docs", "estilo", "guia_20_naufrago_vistas.png")
OUT = os.path.join(ROOT, "assets", "models", "cajas")

S = 23.75        # píxeles de la hoja por píxel del modelo
GROUND = 805     # y de la suela en la hoja
FRONT_X = 322    # x del centro del cuerpo en la vista de frente (la derecha del personaje, a la izquierda)
BACK_X = 1081    # ... en la de espaldas (la derecha del personaje, a la derecha)
SIDE_X = 689     # ... en la de lado (muestra el lado derecho; delante = a la derecha de la imagen)
K = 2            # casillas de textura por píxel del modelo

# Hoja del brazo sin ropa (docs/estilo/guia_24_brazo_vistas.webp): proporciones del brazo y la mano,
# y la piel de sus cajas. Vistas de frente, espalda, lado de fuera y de dentro, el brazo colgando.
ARM_SHEET = os.path.join(ROOT, "docs", "estilo", "guia_24_brazo_vistas.webp")
ARM = {"S": 41.5, "tip_y": 560, "tip": 9.4, "axis": 5.25,  # punta de los dedos: y = 560 en la hoja
       "front": 340, "back": 618, "outer": 912, "inner": 1195}

SKIN = "skin"      # filtro: piel (la mano no debe coger las pulseras de encima)
SHIRT = "shirt"    # filtro: casillas que no son camisa se cambian por la camisa más cercana
BROWN = "brown"    # filtro: cuero / tela marrón


def box(bone, lo, hi, **opts):
    return {"bone": bone, "from": list(lo), "to": list(hi), **opts}


# --- Huesos: id, nombre del nodo, padre, pivote (px desde los pies; derecha del personaje = +X,
# delante = -Z). Los que no tienen padre son las partes que anima PlayerAvatar.
BONES = [
    ("body", "body", None, (0, 13.0, 0)),
    ("body/chest", "chest", "body", (0, 14.6, 0)),             # cintura
    ("head", "head", None, (0, 22.8, 0)),                       # cuello
    ("head/jaw", "jaw", "head", (0, 24.4, 1.0)),                # mentón (bisagra atrás)
    ("leg_right", "leg_right", None, (2.0, 12.8, 0)),           # cadera
    ("leg_right/lower", "lower", "leg_right", (2.0, 8.0, 0)),   # rodilla
    ("leg_right/lower/foot", "foot", "leg_right/lower", (2.0, 3.3, 0)),  # tobillo
    ("arm_right", "arm_right", None, (5.25, 21.2, 0)),          # hombro
    ("arm_right/lower", "lower", "arm_right", (5.25, 17.1, 0)),  # codo
    ("arm_right/lower/wrist", "wrist", "arm_right/lower", (5.25, 13.35, 0)),  # muñeca
    # Dónde se agarra un mango: dentro del puño cerrado, bajo la palma.
    ("arm_right/lower/grip", "grip", "arm_right/lower", (5.05, 10.35, 0.0)),
]

# Mano: palma y dedos con sus falanges. Los dedos van uno detrás de otro de delante (índice, -Z) a
# atrás (meñique), pegados al lado de la palma (-X en la mano derecha, hacia el cuerpo), y se
# doblan hacia ese lado. Cada falange es un hueso: nudillo, articulación del medio y la de la punta.
# Medidas de la hoja del brazo (guia_24): la palma es más ancha (2,4) que gruesa (1,5) y los dedos,
# más finos que la palma, miden 1,6 en total.
PALM_BOTTOM = 11.0
FINGER_X = (4.5, 5.9)                       # grosor de los dedos
FINGERS = [  # (z0, z1, largos de las 3 falanges)
    (-1.2, -0.63, (0.65, 0.5, 0.45)),       # índice
    (-0.59, -0.02, (0.7, 0.55, 0.45)),      # corazón
    (0.02, 0.59, (0.65, 0.5, 0.45)),        # anular
    (0.63, 1.15, (0.55, 0.42, 0.38)),       # meñique
]
THUMB = {"base": (4.35, 12.55, -1.25), "size": (0.8, 0.8), "lengths": (0.9, 0.7)}


def hand_bones_and_boxes():
    """Huesos y cajas de la mano derecha (falanges y pulgar)."""
    bones, boxes = [], []
    cx = (FINGER_X[0] + FINGER_X[1]) / 2
    for f, (z0, z1, lengths) in enumerate(FINGERS):
        parent = "arm_right/lower/wrist"
        y = PALM_BOTTOM
        for j, length in enumerate(lengths):
            bid = "arm_right/lower/wrist/f%d%s" % (f, "abc"[j]) if j == 0 else parent + "/f%d%s" % (f, "abc"[j])
            bones.append((bid, "f%d%s" % (f, "abc"[j]), parent, (cx, y, (z0 + z1) / 2)))
            boxes.append(box(bid, (FINGER_X[0], y - length - 0.05, z0), (FINGER_X[1], y + 0.05, z1), name="dedo", filter=SKIN, sheet="arm"))
            parent = bid
            y -= length
    # Pulgar: sale del lado de delante de la palma, hacia abajo.
    bx, by, bz = THUMB["base"]
    w, d = THUMB["size"]
    parent = "arm_right/lower/wrist"
    for j, length in enumerate(THUMB["lengths"]):
        bid = parent + "/t" + "ab"[j]
        bones.append((bid, "t" + "ab"[j], parent, (bx, by, bz)))
        boxes.append(box(bid, (bx - w / 2, by - length - 0.05, bz - d / 2), (bx + w / 2, by + 0.05, bz + d / 2),
                         name="pulgar", sample_from=None, filter=SKIN, sheet="arm"))
        parent = bid
        by -= length
    return bones, boxes


HAND_BONES, HAND_BOXES = hand_bones_and_boxes()
BONES += HAND_BONES



def boxes_right_side():
    """Cajas del brazo y la pierna DERECHOS (los izquierdos son su reflejo)."""
    b = []
    # Pierna: muslo y espinilla (piel, los tapa el pantalón), pantalón con volumen, bota con vuelta.
    b.append(box("leg_right", (0.25, 8.0, -1.8), (3.85, 13.2, 1.8)))
    b.append(box("leg_right", (0.0, 7.6, -2.1), (4.1, 12.9, 2.1), name="pantalon"))
    b.append(box("leg_right/lower", (0.3, 4.2, -1.75), (3.8, 8.2, 1.75)))
    b.append(box("leg_right/lower", (0.05, 5.8, -2.05), (4.05, 8.1, 2.05), name="pantalon"))
    b.append(box("leg_right/lower", (-0.25, 4.3, -2.35), (4.35, 6.3, 2.35), name="vuelta_bota"))
    b.append(box("leg_right/lower/foot", (0.1, 0.5, -2.9), (4.0, 4.4, 2.1), name="bota"))
    b.append(box("leg_right/lower/foot", (0.0, 0.0, -3.2), (4.1, 0.55, 2.3), name="suela",
                 color=(52, 38, 30)))
    # Brazo (medidas de guia_24): hombro ancho redondeado con escalones, brazo, codo más estrecho,
    # antebrazo que se afina hacia la muñeca. La piel sale de la hoja del brazo.
    arm = {"sheet": "arm", "filter": SKIN}
    b.append(box("arm_right", (4.4, 21.75, -0.9), (6.1, 22.3, 0.9), name="hombro", **arm))
    b.append(box("arm_right", (3.75, 20.1, -1.5), (6.75, 21.6, 1.5), name="hombro", **arm))
    b.append(box("arm_right", (4.0, 19.7, -1.25), (6.5, 21.95, 1.25), name="hombro", **arm))
    b.append(box("arm_right", (4.15, 17.3, -1.0), (6.35, 20.0, 1.0), name="brazo", **arm))
    b.append(box("arm_right/lower", (4.3, 16.8, -0.9), (6.2, 17.5, 0.9), name="codo", **arm))
    b.append(box("arm_right/lower", (4.2, 13.8, -0.95), (6.3, 16.9, 0.95), name="antebrazo", **arm))
    b.append(box("arm_right/lower", (4.35, 13.2, -0.85), (6.15, 13.9, 0.85), name="muneca", **arm))
    # Manga con volumen: tres tiras de delante a atrás, cada una más larga (corte en diagonal), y
    # la hombrera por encima.
    for z0, z1, bottom in [(-1.75, -0.58, 18.7), (-0.58, 0.58, 18.1), (0.58, 1.75, 17.5)]:
        b.append(box("arm_right", (3.5, bottom, z0), (7.0, 21.75, z1), name="manga", filter=SHIRT))
    b.append(box("arm_right", (3.9, 21.7, -1.45), (6.6, 22.45, 1.45), name="manga", filter=SHIRT))
    # Dos pulseras de cuero con relieve (y un remache delante).
    for y0 in (13.5, 14.5):
        b.append(box("arm_right/lower", (3.95, y0, -1.2), (6.55, y0 + 0.7, 1.2), name="pulsera", filter=BROWN))
        b.append(box("arm_right/lower", (4.95, y0 + 0.15, -1.45), (5.55, y0 + 0.55, -1.2), name="remache",
                     color=(150, 120, 90)))
    # Mano: palma más ancha que gruesa; dedos y pulgar en HAND_BOXES.
    b.append(box("arm_right/lower/wrist", (4.25, PALM_BOTTOM, -1.25), (6.25, 13.45, 1.25), name="palma", **arm))
    b += HAND_BOXES
    return b


def boxes_center():
    b = []
    # Cadera y torso (piel), camisa con volumen y bajo roto, cinturón, trapo colgando, bolsa.
    b.append(box("body", (-3.9, 11.9, -1.9), (3.9, 14.7, 1.9)))
    b.append(box("body", (-4.1, 11.6, -2.15), (4.1, 13.2, 2.15), name="pantalon"))
    b.append(box("body/chest", (-3.9, 14.6, -1.9), (3.9, 22.0, 1.9)))
    b.append(box("body/chest", (-4.15, 15.2, -2.2), (4.15, 22.1, 2.2), name="camisa"))
    for x0, x1, bottom in [(-4.15, -2.0, 14.5), (-2.0, 0.3, 14.9), (0.3, 2.4, 14.4), (2.4, 4.15, 14.8)]:
        b.append(box("body/chest", (x0, bottom, -2.2), (x1, 15.3, 2.2), name="bajo_camisa", filter=SHIRT))
    b.append(box("body", (-4.35, 12.7, -2.4), (4.35, 14.3, 2.4), name="cinturon", filter=BROWN))
    b.append(box("body", (-1.6, 13.0, -2.65), (-0.4, 13.9, -2.35), name="hebilla", color=(118, 82, 52)))
    b.append(box("body", (-0.9, 9.4, -2.75), (0.5, 13.1, -2.45), name="trapo", sample_from=(-0.6, 9.4, 0.8, 13.1)))
    b.append(box("body", (1.9, 10.9, 2.1), (4.4, 13.7, 3.1), name="bolsa", filter=BROWN))
    # Cuello y cabeza (con el mentón aparte), orejas.
    b.append(box("body/chest", (-1.55, 21.9, -1.4), (1.55, 23.3, 1.4), name="cuello"))
    b.append(box("head", (-4.0, 24.4, -4.0), (4.0, 30.8, 4.0), name="cabeza"))
    b.append(box("head", (-4.0, 22.8, -0.5), (4.0, 24.4, 4.0), name="nuca"))
    b.append(box("head/jaw", (-4.0, 22.8, -4.0), (4.0, 24.4, -0.5), name="menton"))
    for sx in (1, -1):
        x0, x1 = sorted((sx * 4.0, sx * 4.7))
        b.append(box("head", (x0, 25.3, -0.6), (x1, 27.2, 0.7), name="oreja",
                     sample_from=(sx * 4.9, 25.3, sx * 4.2, 27.2)))
    return b


def mirror(bx):
    """Reflejo de una caja (o hueso) del lado derecho al izquierdo."""
    out = dict(bx)
    out["bone"] = bx["bone"].replace("right", "left")
    out["from"] = [-bx["to"][0], bx["from"][1], bx["from"][2]]
    out["to"] = [-bx["from"][0], bx["to"][1], bx["to"][2]]
    if "sample_from" in bx:
        sf = bx["sample_from"]
        if sf is None:
            return out
        out["sample_from"] = (-sf[0], sf[1], -sf[2], sf[3])
    return out


def all_bones():
    bones = []
    for bid, name, parent, pivot in BONES:
        bones.append({"id": bid, "name": name, "parent": parent, "pivot": list(pivot)})
        if "right" in bid:
            bones.append({"id": bid.replace("right", "left"), "name": name.replace("right", "left"),
                          "parent": parent.replace("right", "left") if parent else None,
                          "pivot": [-pivot[0], pivot[1], pivot[2]]})
    return bones


def all_boxes():
    right = boxes_right_side()
    return boxes_center() + right + [mirror(b) for b in right]


# --- Muestreo de la hoja ---

def is_bg(c):
    # El crema del fondo y los bordes claros y grises que deja el dibujo al mezclarse con él.
    return ((c[..., 2] > 215) & (c[..., 0] > 240)) | \
        ((c[..., 0] > 205) & (c[..., 1] > 195) & (c[..., 2] > 180) & (c[..., 0] - c[..., 2] < 45))


def is_shirt(c):
    return (c[..., 0] > 165) & (c[..., 0] - c[..., 2] < 100)


def is_skin(c):
    return (c[..., 0] > 195) & (c[..., 0] - c[..., 2] > 85) & (c[..., 1] > 110)


def is_brown(c):
    return (c[..., 0] < 175) & (c[..., 0] > 40) & (c[..., 1] < c[..., 0] * 0.85)


def is_hair(c):
    r, g, b = c[..., 0], c[..., 1], c[..., 2]
    return (r < 175) & (r > 35) & (g < r * 0.8) & (b < g * 1.05) & (r + g + b < 380)


def sample_strip(sheet, xa, xb, ya, yb, cols, rows):
    """Colores (rows x cols) de la zona de la hoja de (xa, ya) a (xb, yb) (xa > xb = al revés)."""
    out = np.zeros((rows, cols, 3))
    h, w = sheet.shape[:2]
    for j in range(rows):
        for i in range(cols):
            fx0, fx1 = (i + 0.3) / cols, (i + 0.7) / cols
            fy0, fy1 = (j + 0.3) / rows, (j + 0.7) / rows
            x0, x1 = sorted((xa + (xb - xa) * fx0, xa + (xb - xa) * fx1))
            y0, y1 = sorted((ya + (yb - ya) * fy0, ya + (yb - ya) * fy1))
            x0, x1 = int(np.clip(x0, 0, w - 1)), int(np.clip(x1, 0, w - 1))
            y0, y1 = int(np.clip(y0, 0, h - 1)), int(np.clip(y1, 0, h - 1))
            out[j, i] = np.median(sheet[y0:y1 + 1, x0:x1 + 1].reshape(-1, 3), axis=0)
    return out


def fix(cells, keep):
    """Casillas de fondo (o que no pasan el filtro) -> el color bueno más cercano."""
    bad = is_bg(cells)
    if keep is not None:
        bad |= ~keep(cells)
    good = np.argwhere(~bad)
    if len(good) == 0:
        if keep is is_skin:
            return np.tile(np.array([236.0, 156.0, 98.0]), cells.shape[:2] + (1,))
        return cells
    out = cells.copy()
    for j, i in np.argwhere(bad):
        k = np.argmin(np.abs(good - [j, i]).sum(1))
        out[j, i] = cells[tuple(good[k])]
    return out


def ncells(length):
    return max(1, int(round(length * K)))


def arm_face_pixels(bx, face):
    """Una cara de una caja del brazo, de la hoja del brazo (guia_24): x respecto al eje del brazo."""
    sheet = _arm_sheet()
    x0, y0, z0 = bx["from"]
    x1, y1, z1 = bx["to"]
    if x0 + x1 < 0:  # brazo izquierdo: se mira como el derecho (la piel es simétrica)
        x0, x1 = -x1, -x0
        face = {"right": "left", "left": "right"}.get(face, face)
    a = ARM
    to_y = lambda y: a["tip_y"] - (y - a["tip"]) * a["S"]
    ya, yb = to_y(y1), to_y(y0)
    if face == "front":
        xa, xb = a["front"] - (x1 - a["axis"]) * a["S"], a["front"] - (x0 - a["axis"]) * a["S"]
    elif face == "back":
        xa, xb = a["back"] + (x0 - a["axis"]) * a["S"], a["back"] + (x1 - a["axis"]) * a["S"]
    elif face == "right":
        xa, xb = a["outer"] - z1 * a["S"], a["outer"] - z0 * a["S"]
    elif face == "left":
        xa, xb = a["inner"] + z0 * a["S"], a["inner"] + z1 * a["S"]
    else:
        y = y1 if face == "top" else y0
        yy = to_y(y) + (a["S"] * 0.3 if face == "top" else -a["S"] * 0.3)
        cols, rows = ncells(x1 - x0), ncells(z1 - z0)
        row = sample_strip(sheet, a["front"] - (x1 - a["axis"]) * a["S"], a["front"] - (x0 - a["axis"]) * a["S"],
                           yy - 3, yy + 3, cols, 1)[0]
        return fix(np.repeat(row[None], rows, axis=0), is_skin)
    cols = ncells((x1 - x0) if face in ("front", "back") else (z1 - z0))
    return fix(sample_strip(sheet, xa, xb, ya, yb, cols, ncells(y1 - y0)), is_skin)


_ARM_SHEET = None


def _arm_sheet():
    global _ARM_SHEET
    if _ARM_SHEET is None:
        _ARM_SHEET = np.asarray(Image.open(ARM_SHEET).convert("RGB")).astype(float)
    return _ARM_SHEET


def face_pixels(sheet, bx, face):
    if bx.get("sheet") == "arm":
        return arm_face_pixels(bx, face)
    x0, y0, z0 = bx["from"]
    x1, y1, z1 = bx["to"]
    if bx.get("sample_from"):  # zona propia en la vista de frente/lado (x o z, y): orejas, trapo
        sx0, sy0, sx1, sy1 = bx["sample_from"]
    keep = {SHIRT: is_shirt, BROWN: is_brown, SKIN: is_skin}.get(bx.get("filter"))
    ya, yb = GROUND - y1 * S, GROUND - y0 * S
    if face in ("front", "back"):
        cols, rows = ncells(x1 - x0), ncells(y1 - y0)
        if face == "front":
            xa, xb = FRONT_X - x1 * S, FRONT_X - x0 * S
            if bx.get("sample_from") and bx["name"] == "trapo":
                xa, xb = FRONT_X - sx1 * S, FRONT_X - sx0 * S
        else:
            xa, xb = BACK_X + x0 * S, BACK_X + x1 * S
    elif face in ("right", "left"):
        cols, rows = ncells(z1 - z0), ncells(y1 - y0)
        if bx.get("sample_from") and bx["name"] == "oreja":  # la oreja se ve de frente: su zona allí
            xa, xb = FRONT_X - sx0 * S, FRONT_X - sx1 * S
        elif face == "right":
            xa, xb = SIDE_X - z1 * S, SIDE_X - z0 * S
        else:
            xa, xb = SIDE_X - z0 * S, SIDE_X - z1 * S
    else:  # arriba / abajo: la fila de arriba (o abajo) de delante y de detrás
        cols, rows = ncells(x1 - x0), ncells(z1 - z0)
        y = y1 if face == "top" else y0
        yy = GROUND - y * S + (S * 0.3 if face == "top" else -S * 0.3)
        front = sample_strip(sheet, FRONT_X - x1 * S, FRONT_X - x0 * S, yy - 3, yy + 3, cols, 1)[0]
        back = sample_strip(sheet, BACK_X + x1 * S, BACK_X + x0 * S, yy - 3, yy + 3, cols, 1)[0]
        cells = np.zeros((rows, cols, 3))
        for j in range(rows):
            t = (j + 0.5) / rows  # arriba: de atrás (0) a delante (1); abajo: de delante a atrás
            if face == "bottom":
                t = 1 - t
            cells[j] = back * (1 - t) + front * t
        return fix(cells, keep)
    cells = sample_strip(sheet, xa, xb, ya, yb, cols, rows)
    if bx["bone"].startswith("body") and face in ("right", "left") and bx.get("name") != "bolsa":
        # El lado del torso lo tapa el brazo en la vista de lado: sus bordes de delante y detrás.
        fr = sample_strip(sheet, FRONT_X - x1 * S, FRONT_X - x0 * S, ya, yb, ncells(x1 - x0), rows)
        bk = sample_strip(sheet, BACK_X + x0 * S, BACK_X + x1 * S, ya, yb, ncells(x1 - x0), rows)
        edge_f = fr[:, 0] if face == "right" else fr[:, -1]
        edge_b = bk[:, -1] if face == "right" else bk[:, 0]
        for i in range(cols):
            t = (i + 0.5) / cols  # derecha: de atrás a delante; izquierda: de delante a atrás
            if face == "left":
                t = 1 - t
            cells[:, i] = edge_b * (1 - t) + edge_f * t
    return fix(cells, keep)


FACES = ("front", "back", "right", "left", "top", "bottom")


def build_atlas(sheet, boxes):
    """Empaqueta todas las caras en una imagen (filas de alturas parecidas)."""
    images = []
    for n, bx in enumerate(boxes):
        for face in FACES:
            if "color" in bx:
                c = np.array(bx["color"], dtype=float)
                x0, y0, z0 = bx["from"]
                x1, y1, z1 = bx["to"]
                w = {"front": x1 - x0, "back": x1 - x0, "top": x1 - x0, "bottom": x1 - x0}.get(face, z1 - z0)
                hgt = {"top": z1 - z0, "bottom": z1 - z0}.get(face, y1 - y0)
                px = np.tile(c, (ncells(hgt), ncells(w), 1))
                # Relieve: el borde de arriba un poco más claro y el de abajo más oscuro.
                px[0] = np.minimum(px[0] * 1.12, 255)
                px[-1] = px[-1] * 0.85
            else:
                px = face_pixels(sheet, bx, face)
            images.append((n, face, px))
    size = 256
    while True:
        atlas = np.zeros((size, size, 4), dtype=np.uint8)
        x = y = row_h = 0
        ok = True
        rects = {}
        for n, face, px in sorted(images, key=lambda t: -t[2].shape[0]):
            h, w = px.shape[:2]
            if x + w > size:
                x, y, row_h = 0, y + row_h + 1, 0
            if y + h > size:
                ok = False
                break
            atlas[y:y + h, x:x + w, :3] = px.clip(0, 255).astype(np.uint8)
            atlas[y:y + h, x:x + w, 3] = 255
            rects[(n, face)] = [x, y, w, h]
            x += w + 1
            row_h = max(row_h, h)
        if ok:
            return atlas, rects
        size *= 2


def build_hair(sheet):
    """Pelo rizado en 3D: rizos (cubos de distintos tamaños, cada uno con su tono) por la superficie
    de una bola alrededor de la cabeza, con la cara al aire. En px desde el cuello."""
    hair = sheet[40:240, BACK_X - 85:BACK_X + 105].reshape(-1, 3)
    hair = hair[is_hair(hair)]
    tones = [np.percentile(hair, q, axis=0) for q in (30, 50, 65, 78, 88)]
    rng = np.random.default_rng(7)
    curls = []
    center = np.array([0.0, 5.6, 0.5])
    radii = np.array([5.3, 4.4, 5.6])
    n = 0
    # Puntos repartidos por la bola (espiral de Fibonacci), de dentro afuera en dos capas.
    for layer, count, scale in ((0, 150, 0.92), (1, 230, 1.0)):
        for i in range(count):
            t = (i + 0.5) / count
            phi = math.acos(1 - 2 * t)
            theta = math.pi * (1 + 5 ** 0.5) * i
            d = np.array([math.sin(phi) * math.cos(theta), math.cos(phi), math.sin(phi) * math.sin(theta)])
            p = center + d * radii * scale * (1.0 + rng.uniform(-0.05, 0.1))
            x, y, z = p
            if z < -2.4 and y < 5.4:
                continue  # la cara
            if y < 1.6 and z < 2.5:
                continue  # por debajo de la mandíbula, solo detrás
            if y < 4.9 and z < 1.6:
                continue  # las orejas y las mejillas, al aire (el pelo baja solo por detrás)
            if abs(x) < 3.6 and y < 7.4 and abs(z) < 3.6:
                continue  # dentro de la cabeza
            size = rng.uniform(1.1, 1.7) if layer else rng.uniform(1.3, 1.9)
            tone = tones[int(rng.integers(0, len(tones)))] * (0.85 if layer == 0 else 1.0)
            curls.append([round(x, 2), round(y, 2), round(z, 2), round(size, 2),
                          "#%02x%02x%02x" % tuple(int(v) for v in tone.clip(0, 255))])
            n += 1
    # Flequillo: rizos sobre la frente.
    for x in np.arange(-3.4, 3.6, 1.15):
        y = 6.6 + rng.uniform(-0.3, 0.4)
        tone = tones[int(rng.integers(1, len(tones)))]
        curls.append([round(float(x), 2), round(y, 2), -4.0, round(rng.uniform(1.1, 1.5), 2),
                      "#%02x%02x%02x" % tuple(int(v) for v in tone.clip(0, 255))])
    return curls


def main():
    sheet = np.asarray(Image.open(SHEET).convert("RGB")).astype(float)
    boxes = all_boxes()
    atlas, rects = build_atlas(sheet, boxes)
    os.makedirs(OUT, exist_ok=True)
    Image.fromarray(atlas, "RGBA").save(os.path.join(OUT, "naufrago.png"))
    out_boxes = []
    for n, bx in enumerate(boxes):
        out_boxes.append({"bone": bx["bone"], "from": bx["from"], "to": bx["to"],
                          "faces": {f: rects[(n, f)] for f in FACES}})
    lids = []  # párpados (para parpadear): delante de los ojos, color de la piel
    for x0, x1 in ((1.0, 2.9), (-2.9, -1.0)):
        lids.append({"from": [x0, 24.8, -4.08], "to": [x1, 26.5, -4.02]})
    model = {"atlas": "naufrago.png", "size": atlas.shape[0], "bones": all_bones(), "boxes": out_boxes,
             "lids": lids, "lid_color": [250, 172, 108], "hair": build_hair(sheet)}
    with open(os.path.join(OUT, "naufrago.json"), "w") as f:
        json.dump(model, f)
    print("modelo: %d cajas, %d rizos, textura %dx%d" % (len(out_boxes), len(model["hair"]),
                                                          atlas.shape[1], atlas.shape[0]))


if __name__ == "__main__":
    main()
