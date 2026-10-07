# Análisis de la guía visual (2026-10-07)

> 32 imágenes de ChatGPT en `docs/estilo/` (guía visual y arte que faltaba). Objetivo de Yago:
> **replicar el juego al 100% como en las imágenes**. Primero el análisis; después, por pasos.
> Captura del juego antes de empezar: `docs/estilo/juego_actual_antes.png`.

## 1. Lo que se repite en todas (las reglas del estilo)

**Mundo**
- Bloques de medio metro, cuadrados y limpios, sin redondear ni suavizar.
- **Texturas de 16x16 píxeles** (medido en `guia_10`: 230 px por textura y un "píxel" cada
  14,5 px = 16). Pixel art rico: 4-6 tonos por material, manchas grandes, sin ruido fino.
- Hierba: arriba verde amarillento vivo; el lateral con flecos de hierba que cuelgan sobre la
  tierra. Nieve igual, con flecos azulados. Tierra naranja-marrón con piedrecitas grises.
- Piedra gris con bloques irregulares (no ruido); piedra musgosa con manchas verdes; minerales
  como gemas grandes y brillantes (verde esmeralda, oro naranja).
- Árboles: tronco de 1 bloque (el roble grande, 2x2) con raíces; copa de bloques de hojas con
  textura de hojas grandes y **hojitas sueltas que sobresalen** (cubos pequeños en el borde).
  Pinos por pisos en cono. Palmera curvada.
- Plantas: dibujos planos en cruz, de 16 px (hierba alta, flores, setas, trigo en 3 fases...).
- Agua **transparente turquesa** en la orilla y azul profundo mar adentro, con espuma blanca de
  bloques en la orilla y reflejos del cielo. Cascadas blancas con niebla.

**Objetos y construcciones**
- Hechos de **cajas con textura de píxeles** (como los modelos de Minecraft Dungeons): cofres,
  barriles, cajas, mesa, hoguera, horno, balsa, barco. El "píxel" de la textura es el mismo
  tamaño en todo (1/16 de bloque), aunque en algunas imágenes ChatGPT lo hace más fino.
- Hierro oscuro en esquinas y bisagras; cuerda gruesa marrón clara.
- Edificios: piedra abajo, entramado de madera con yeso arriba, tejados de tejas marrón-rojizas
  en escalera, chimeneas con humo, faroles colgados, flores en las ventanas.

**Personajes**
- Cuerpo de cajas tipo Minecraft, pero **cabeza más grande** (aprox. 1,25 veces) y cuerpo algo
  más bajo y robusto (como Minecraft Dungeons).
- Pelo, cuello de la camisa, cinturón, botas y bordes de la ropa **sobresalen** como cubos
  (una "segunda capa" con volumen). El pelo rizado del náufrago es una masa de cubos.
- Ojos: blanco con pupila oscura de 2 píxeles y cejas marcadas; boca de 1-2 píxeles; mejillas.
- Animales y enemigos con la misma regla (cajas con textura, ojos brillantes en los enemigos).
- En primera persona: **brazo de cajas con manga de camisa rota**, la mano abajo a la derecha;
  los objetos en la mano son los mismos modelos de cajas de los iconos.

**Luz y ambiente (lo que más "vende")**
- Luz de hora dorada muy cálida, sol bajo y cuadrado, sombras suaves, oclusión en las esquinas.
- Bruma en la distancia y rayos de sol; brillo (bloom) en fuego, runas cian y corrupción violeta.
- Cielo con degradado (azul / naranja-rosa / noche estrellada), nubes de bloques, luna cuadrada.
- Partículas: chispas, humo de bloques, hojas cayendo, ceniza violeta, salpicaduras.
- Paleta de 12 colores (`biblia.webp`): verde pradera, verde bosque, arena dorada, tierra
  marrón, piedra gris, nieve fría, madera cálida, roca azulada, mar turquesa, cielo azul,
  naranja atardecer y **púrpura corrupción**.

**Interfaz** (`guia_interfaz.png`, `guia_07`)
- Marco de madera con esquinas de hierro y cuerdas; paneles de pergamino; huecos oscuros.
- Pestañas arriba: Inventario, Fabricación, Diario, Mapa, Ajustes.
- Columna de equipo con el personaje en grande; visor del objeto a la derecha con barras de
  daño, durabilidad y eficacia; barras de vida, hambre, sed y sueño con iconos.
- Barra rápida abajo de 10 huecos numerados con marco de madera; barras de vida y agua con iconos
  de carne y gota a la izquierda.

## 2. Lo que varía entre imágenes (no son reglas)
- El tamaño del personaje respecto a los bloques (entre 1,6 y 2 bloques de alto).
- Cuánto detalle de cubitos llevan los objetos (en `guia_30` el barco es más fino). Regla:
  **nos quedamos con el píxel de 1/16 de bloque**, como los bloques.
- La hoja de plantas salió con el fondo mal (negro con restos magenta): se puede limpiar.
- La interfaz de la guía tiene 10 huecos abajo; el juego usa 9 (decidir).

## 3. Comparación con el juego actual

| Parte | Ahora | Para igualarlo |
|---|---|---|
| Texturas de bloques | 32x32 del arte antiguo, otro dibujo | **Recortar las de `guia_10/11/12`** (son 16x16, encajan directo) |
| Luz y cielo | "Luz realista" ya tiene sombras suaves, bruma y brillo | Ajustar colores (más cálido), sol y luna cuadrados, nubes de bloques |
| Agua | Turquesa con espuma | Ajustar tono y espuma de bloques |
| Plantas | Dibujos antiguos | Recortar `guia_13` (limpiando el fondo) |
| Árboles | Árboles hechos por piezas | Rehacer con las texturas nuevas y las hojitas que sobresalen |
| Personaje 3ª persona | Meshy liso | **Personaje de cajas** según `guia_20/21` con su piel |
| Brazo 1ª persona | Meshy realista | **Brazo de cajas con manga** según `guia_23` |
| Objetos en la mano | Modelos de Meshy | Modelos de cajas según los iconos |
| Iconos | Dibujos antiguos | **Recortar las 5 hojas de iconos** |
| Cofre, barril, hoguera... | Mezcla | Modelos de cajas según `objetos_mundo` |
| Barco naufragado | Piezas de bloques | Retocar con texturas nuevas según `guia_30` |
| Interfaz | Madera de Kenney | Rehacer según `guia_interfaz` |
| Animales, enemigos, vecinos | Bolas de colores | Modelos de cajas según `guia_50/51` y `vecinos` |

## 4. Hasta dónde se puede llegar
- **Igual que en la imagen:** texturas, iconos, plantas, formas de personajes y objetos, colores,
  interfaz. Salen de las imágenes directamente.
- **Muy parecido:** la luz (Godot tiene sombras suaves, bruma con rayos, brillo y oclusión). El
  desenfoque de fondo de las imágenes es de "foto de cine": en juego, como opción.
- **A tener en cuenta:** las imágenes de IA a veces son incoherentes (perspectivas imposibles,
  píxeles de tamaños distintos). Se replica la intención, con una regla fija.

## 5. Orden propuesto
1. Texturas de los bloques (recortadas de las hojas) y plantas.
2. Luz, cielo, nubes, sol y luna, agua: comparar capturas con `guia_01` y `guia_07`.
3. Personaje de cajas y brazo en primera persona; objetos en la mano.
4. Iconos del inventario e interfaz nueva.
5. Árboles, objetos del mundo (cofre, hoguera...), barco.
6. Animales, enemigos y vecinos de cajas.
