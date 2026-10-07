#!/usr/bin/env python3
"""Objetos de CUBITOS (estilo Minecraft Dungeons) sacados de una hoja de vistas de la guía:
una fila por objeto y en cada fila sus vistas de FRENTE, LADO y ARRIBA (docs/TEXTURAS.md, punto 10).

Uso:  python3 tools/objetos_desde_vistas.py docs/estilo/objetos_vistas_1.png stone_pick torch raw_fish berries

Cada vista se separa del fondo y se reduce a su rejilla de cubitos (el objeto mide como mucho
CUBES cubitos). Hay cubito donde las tres vistas ven objeto (como recortar un bloque con las tres
siluetas) y cada cara toma su color de la vista desde la que se ve: delante y detrás, de la vista
de frente; los lados, de la de lado; arriba y abajo, de la de arriba.

Sale assets/models/objetos/<id>.json para cada objeto (lo construye ItemMesh en el juego).
"""
import json
import os
import sys

import numpy as np
from PIL import Image

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
OUT = os.path.join(ROOT, "assets", "models", "objetos")
CUBES = 16  # cubitos en el lado más largo del objeto (como un objeto de 16x16 píxeles)


def object_mask(arr):
    """Lo que no es fondo (blanco o crema, y su sombra gris)."""
    bg = np.median(np.concatenate([arr[:3].reshape(-1, 3), arr[-3:].reshape(-1, 3)]), axis=0)
    dist = np.abs(arr - bg).sum(2)
    chroma = np.abs((arr[..., 0] - arr[..., 1]) - (bg[0] - bg[1])) + np.abs((arr[..., 1] - arr[..., 2]) - (bg[1] - bg[2]))
    return ~((dist < 40) | ((chroma < 16) & (arr.sum(2) > 3 * 185)))


def runs(profile, min_len, gap):
    """Tramos donde profile > 0, juntando los separados por menos de 'gap'."""
    out, start, last = [], None, None
    for i, on in enumerate(profile > 0):
        if on:
            if start is None:
                start = i
            elif i - last > gap:
                out.append((start, last + 1))
                start = i
            last = i
    if start is not None:
        out.append((start, last + 1))
    return [r for r in out if r[1] - r[0] >= min_len]


def find_views(arr, mask, rows):
    """Para cada fila de objetos: las cajas (x0, y0, x1, y1) de sus vistas de frente, lado y arriba."""
    h, w = mask.shape
    left = int(w * 0.2)  # a la izquierda van los nombres
    ys = runs(mask[:, left:].sum(1), h // 40, h // 60)
    # Fuera la fila de títulos de arriba (FRONT / SIDE / TOP): la más baja.
    ys = sorted(ys, key=lambda r: r[1] - r[0], reverse=True)[:rows]
    ys.sort()
    views = []
    for y0, y1 in ys:
        band = mask[y0:y1, left:]
        xs = runs(band.sum(0), 4, w // 60)
        xs = sorted(xs, key=lambda r: r[1] - r[0], reverse=True)[:3]
        xs.sort()
        boxes = []
        for x0, x1 in xs:
            sub = mask[y0:y1, left + x0:left + x1]
            yy = np.where(sub.any(1))[0]
            boxes.append((left + x0, y0 + yy.min(), left + x1, y0 + yy.max() + 1))
        views.append(boxes)
    return views


def grid(arr, mask, box, cols, rows):
    """Rejilla (rows x cols) de una vista: si hay objeto y su color en cada casilla."""
    x0, y0, x1, y1 = box
    on = np.zeros((rows, cols), bool)
    col = np.zeros((rows, cols, 3))
    for j in range(rows):
        for i in range(cols):
            cx0, cx1 = x0 + (i + 0.25) * (x1 - x0) / cols, x0 + (i + 0.75) * (x1 - x0) / cols
            cy0, cy1 = y0 + (j + 0.25) * (y1 - y0) / rows, y0 + (j + 0.75) * (y1 - y0) / rows
            m = mask[int(cy0):int(cy1) + 1, int(cx0):int(cx1) + 1]
            c = arr[int(cy0):int(cy1) + 1, int(cx0):int(cx1) + 1]
            if m.mean() > 0.5:
                on[j, i] = True
                col[j, i] = np.median(c[m], axis=0)
    return on, col


def carve(arr, mask, boxes):
    front, side, top = boxes
    fw, fh = front[2] - front[0], front[3] - front[1]
    sw = side[2] - side[0]
    tw, th = top[2] - top[0], top[3] - top[1]
    # Un mismo tamaño de cubito para las tres vistas (las tres están a la misma escala).
    extent = max(fw, fh, sw, tw, th)
    cube = extent / CUBES
    nx = max(1, round(fw / cube))
    ny = max(1, round(fh / cube))
    nz = max(1, round(max(sw, th) / cube))
    f_on, f_col = grid(arr, mask, front, nx, ny)       # [y desde arriba, x]
    s_on, s_col = grid(arr, mask, side, nz, ny)        # [y desde arriba, z] (delante a la derecha)
    t_on, t_col = grid(arr, mask, top, nx, nz)         # [z desde atrás, x] (delante abajo)
    voxels = []
    for y in range(ny):
        for x in range(nx):
            for z in range(nz):
                # z = 0 es delante. En la vista de lado, delante está a la derecha; en la de arriba, abajo.
                zs, zt = nz - 1 - z, nz - 1 - z
                if f_on[y, x] and s_on[y, zs] and t_on[zt, x]:
                    voxels.append([x, ny - 1 - y, z,
                                   "#%02x%02x%02x" % tuple(int(v) for v in f_col[y, x]),
                                   "#%02x%02x%02x" % tuple(int(v) for v in s_col[y, zs]),
                                   "#%02x%02x%02x" % tuple(int(v) for v in t_col[zt, x])])
    return {"size": [nx, ny, nz], "voxels": voxels}


def main():
    if len(sys.argv) < 3:
        print(__doc__)
        return
    sheet, ids = sys.argv[1], sys.argv[2:]
    arr = np.asarray(Image.open(sheet).convert("RGB")).astype(float)
    mask = object_mask(arr)
    views = find_views(arr, mask, len(ids))
    os.makedirs(OUT, exist_ok=True)
    for id_, boxes in zip(ids, views):
        if len(boxes) != 3:
            print("%s: no encuentro sus 3 vistas (%d)" % (id_, len(boxes)))
            continue
        model = carve(arr, mask, boxes)
        with open(os.path.join(OUT, id_ + ".json"), "w") as f:
            json.dump(model, f)
        print("%s: %s cubitos, %d puestos" % (id_, model["size"], len(model["voxels"])))


if __name__ == "__main__":
    main()
