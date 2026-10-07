"""Exporta copias para Paint; no modifica los mapas que generan la isla."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'docs' / 'mapa_isla'
OUT.mkdir(parents=True, exist_ok=True)
terrain = Image.open(ROOT / 'assets/island/preview.png').convert('RGB').resize((2048, 2048), Image.Resampling.LANCZOS)
terrain.save(OUT / 'isla_limpia_paint.png')
fontpath = 'C:/Windows/Fonts/arial.ttf'
def font(size): return ImageFont.truetype(fontpath, size)
canvas = Image.new('RGB', (2700, 2300), '#f6f2e7')
canvas.paste(terrain, (80, 150))
d = ImageDraw.Draw(canvas)
d.text((80, 35), 'ISLA BETA · MAPA PARA DISEÑAR HISTORIAS Y MECÁNICAS', font=font(38), fill='#24332e')
d.text((80, 90), 'Norte arriba (−Z) · Este a la derecha (+X) · Terreno base actual · 512 × 512 m', font=font(25), fill='#52615b')
for i in range(9):
    p = 80 + i * 256
    q = 150 + i * 256
    d.line((p,150,p,2198), fill='#829c9b', width=1)
    d.line((80,q,2128,q), fill='#829c9b', width=1)
    if i < 8:
        d.text((p+118,120), chr(65+i), font=font(23), fill='#24332e')
        d.text((44,q+115), str(i+1), font=font(23), fill='#24332e')

raw = np.asarray(Image.open(ROOT/'assets/island/height.png').convert('RGB')).astype(np.float64)
heights = (raw[:,:,0]*256 + raw[:,:,1])/64
def height(x,z):
    return heights[round((z+512)*1023/1024),round((x+512)*1023/1024)]
village=np.array([-280.,303.]); bay=np.array([-309.,393.])
direction=(bay-village)/np.linalg.norm(bay-village)
shore=village.copy()
for step in range(400):
    p=village+direction*step
    if height(int(p[0]),int(p[1])) <= 24:
        shore=p; break
ship=shore+direction*2
points=[
    ('Naufragio / playa inicial',ship/2,'Estructura actual'),
    ('Ruinas del noroeste',np.array([-137.,-172.5]),'Muros y cofre actuales'),
    ('Torre / campamentos',np.array([96.,-176.]),'Fases 1–4 implementadas'),
    ('Lago de montaña',np.array([105.,-65.]),'Referencia del terreno'),
    ('Montaña nevada',np.array([145.,-5.]),'Referencia del terreno'),
    ('Zona del futuro pueblo',np.array([-140.,151.5]),'Llano reservado; sin pueblo construido'),
    ('Campos',np.array([-80.,90.]),'Referencia del terreno'),
]
def pixel(point): return (80+(point[0]+256)/512*2048,150+(point[1]+256)/512*2048)
d.text((2180,155), 'PUNTOS DE REFERENCIA', font=font(26), fill='#24332e')
rows=[]
for i,(name,point,status) in enumerate(points,1):
    x,y=pixel(point)
    d.ellipse((x-23,y-23,x+23,y+23),fill='#fff7dc',outline='#233b38',width=3)
    d.text((x,y),str(i),anchor='mm',font=font(27),fill='#233b38')
    yy=215+(i-1)*160
    col=min(7,max(0,int((point[0]+256)/64))); row=min(7,max(0,int((point[1]+256)/64)))
    grid=f'{chr(65+col)}{row+1}'
    d.text((2180,yy),f'{i:02} · {name}',font=font(22),fill='#24332e')
    d.text((2180,yy+35),f'{grid} · X {point[0]:.0f} / Z {point[1]:.0f} m',font=font(20),fill='#52615b')
    # Keep long status text within the side column.
    words=status.split(); lines=['']
    for word in words:
        trial=(lines[-1]+' '+word).strip()
        if d.textlength(trial,font=font(19))>470: lines.append(word)
        else: lines[-1]=trial
    d.multiline_text((2180,yy+67),'\n'.join(lines),font=font(19),fill='#52615b',spacing=5)
    rows.append(f'| {i:02} | {name} | {grid} | {point[0]:.0f}, {point[1]:.0f} | {status} |')
d.multiline_text((2180,1450),'TUS MARCAS EN PAINT\n\nRojo: enemigos / peligro\nAzul: historia / personajes\nAmarillo: botín / recursos\nBlanco: rutas / caminos\n\nNumera los nuevos lugares\ndesde 08 y apunta su casilla.\n\nCada casilla mide 64 × 64 m.\n\nLos caminos todavía\nno están construidos.',font=font(23),fill='#24332e',spacing=12)
d.text((80,2225),'Escala: 100 m',font=font(22),fill='#24332e')
d.line((285,2240,685,2240),fill='#24332e',width=5)
canvas.save(OUT/'isla_referencias_paint.png')
preview=canvas.copy();preview.thumbnail((1400,1400));preview.save(OUT/'vista_previa.png')
intro='''# Lugares, lore y mecánicas de la isla

Abre `isla_limpia_paint.png` o `isla_referencias_paint.png` en Paint y guarda tus marcas como una copia. Estos archivos son documentos de diseño: pintarlos no cambia el terreno del juego.

La vista representa el terreno base horneado, no las construcciones o excavaciones de tu partida. Las referencias del lago, montaña y campos son aproximadas; naufragio, ruinas y torre se sitúan a partir del código. El llano del pueblo es una reserva de terreno, no un pueblo construido. Norte = −Z, este = +X. Coordenadas en metros; cuadrícula de 64 m.

| Nº | Lugar | Casilla | X, Z (m) | Estado |
|---|---|---|---|---|
'''
template='''

## Ficha de lugar (copia una por cada marca nueva)

- Número y nombre:
- Casilla / coordenadas:
- Estado: idea / aprobado / programado / probado
- Historia: qué pasó aquí y quién vivía aquí:
- Qué descubre el jugador y cómo lo descubre:
- Personajes, animales y enemigos:
- Mecánicas que hay que programar:
- Cuándo se activa: día, misión, objeto o condición:
- Recompensas y recursos:
- Conexiones y caminos a otros lugares:
- Cambios tras visitarlo o completar su objetivo:
- Modelos, sonidos y animaciones pendientes:

Las historias nuevas quedan abiertas para que las decidamos juntos. Puedes enviar el PNG marcado y estas fichas para convertir cada lugar en tareas concretas de programación.
'''
(OUT/'LUGARES_Y_LORE.md').write_text(intro+'\n'.join(rows)+template,encoding='utf-8')
print('Mapas exportados:',OUT)
