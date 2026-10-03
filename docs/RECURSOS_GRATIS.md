# Recursos gratis que podemos usar (investigado el 3 de octubre de 2026)

Regla: preferimos **CC0** (dominio público: se puede usar, modificar y vender sin pedir permiso
ni citar). CC-BY también vale, pero hay que citar al autor en los créditos. Nada de "resource
packs" de Minecraft (tienen copyright aunque se descarguen gratis).

## Lo más útil para nosotros, por orden

### 1. Sonido (lo que más se notaría ya)

| Recurso | Licencia | Qué tiene | Para qué lo usaríamos |
|---|---|---|---|
| [Kenney Impact Sounds / RPG Audio / UI Audio / Interface Sounds](https://kenney.nl/assets/rpg-audio) | CC0 | golpes, pasos, foley, clics | romper, colocar, pasos por material, clics del menú, recoger |
| [Sonniss GameAudioGDC](https://gdc.sonniss.com/) (paquete anual y archivo de años anteriores) | gratis, sin royalties ni citar (prohibido usarlo para entrenar IA) | sonidos profesionales grabados | **olas, viento, fuego, lluvia, pájaros, madera crujiendo** (la caída del árbol) |
| [Freesound.org](https://freesound.org) filtrando por **CC0** | CC0 | de todo | huecos concretos (cangrejo, gaviota, insecto) |

### 2. Interfaz

| Recurso | Licencia | Qué tiene | Uso |
|---|---|---|---|
| [Kenney UI Pack (RPG Expansion)](https://kenney.nl/assets/ui-pack-rpg-expansion) | CC0 | paneles de madera y pergamino, botones, barras | inventario, menús, diario: encaja con "tela y madera de barco" |
| [Kenney UI Pack](https://kenney.nl/assets/ui-pack) | CC0 | botones, sliders, casillas | opciones |
| [Kenney Input Prompts](https://kenney.nl/assets) | CC0 | dibujos de teclas y ratón | ayuda F1 y avisos ("Mantén ⓇR") |

### 3. Texturas de bloques (para cuando toque lo estético)

| Recurso | Licencia | Notas |
|---|---|---|
| [16x16 Block Texture Set](https://opengameart.org/content/16x16-block-texture-set) | CC0 | bloques y plantas, paleta Comfy52, estilo coherente |
| [CC0 Minecraft Inspired Textures](https://opengameart.org/content/cc0-minecraft-inspired-textures) | CC0 | 16x16, hoja y sueltas |
| [16*16 Block Textures](https://opengameart.org/content/1616-block-textures) | CC0 | 16x16 |
| [Kenney Voxel Pack](https://kenney.nl/assets/voxel-pack) | CC0 | 190 texturas para sandbox de supervivencia (más grandes: habría que reducirlas) |

Nuestro juego carga texturas propias si se dejan como PNG en `assets/textures/blocks/` con el
nombre de la cara (`grass_top.png`, `log_side.png`...): cambiar de aspecto es copiar archivos.

### 4. Modelos 3D pequeños (decoración, herramientas, animales)

| Recurso | Licencia | Qué tiene | Uso |
|---|---|---|---|
| [Kenney Survival Kit](https://kenney.nl/assets/survival-kit) | CC0 | 80 modelos (glTF): hoguera, tienda, herramientas, banco de trabajo, estructuras de madera | referencia o modelos directos para hoguera, refugio, herramientas |
| [Kenney Nature Kit](https://kenney.nl/assets/nature-kit) | CC0 | rocas, plantas, setas, troncos | decoración del suelo que no es cubo |
| [Quaternius: animales animados, peces, granja](https://quaternius.itch.io/lowpoly-animated-animals) | CC0 | animales low poly con animaciones | gaviotas, cangrejos, peces, jabalí... (fauna de la isla) |
| [Quaternius Ultimate Nature / Survival Pack](https://quaternius.com/) | CC0 | árboles, cultivos, objetos de supervivencia | ideas y piezas |

Ojo de estilo: son "low poly" lisos; quedan bien en una mezcla tipo Hytale/Cube World si se usan
con colores planos, pero hay que probarlos al lado de los bloques.

### 5. Personaje y animaciones (para "un personaje vivo")

| Recurso | Licencia | Qué tiene | Notas |
|---|---|---|---|
| [Quaternius Universal Animation Library](https://quaternius.com/packs/universalanimationlibrary.html) (+ [v2](https://quaternius.com/packs/universalanimationlibrary2.html)) | CC0 | 120+ animaciones (andar, correr, saltar, nadar, coger, sentarse, emotes...) en glTF/FBX, esqueleto humano estándar, preparadas para Godot | la mejor opción: CC0 y listas para reasignar a otro esqueleto |
| [Quaternius Universal Base Characters](https://quaternius.com/packs/universalbasecharacters.html) | CC0 | 6 personajes base con ese esqueleto | referencia de proporciones |
| [Mixamo](https://www.mixamo.com) (Adobe) | gratis para juegos (cuenta de Adobe); no se pueden redistribuir los archivos sueltos | miles de animaciones | útil, pero Quaternius cubre casi lo mismo sin condiciones |

Para usarlas, nuestro personaje tendría que pasar de "cajas animadas por código" a un modelo con
esqueleto (Skeleton3D) con las mismas proporciones de bloque; Godot puede reasignar animaciones
entre esqueletos humanos. Es un cambio grande: lo dejaría para la fase de "personaje vivo".

### 6. Música

| Recurso | Licencia | Estilo |
|---|---|---|
| [Exploration Theme](https://opengameart.org/content/exploration-theme) | CC0 | piano/sintetizador ambiental, con aire marino, en bucle |
| [Exploration](https://opengameart.org/content/exploration-0) | CC0 | guitarra acústica, aventura |
| [Feel Good Island Loop](https://opengameart.org/content/feel-good-island-loop) | mirar licencia (probablemente CC-BY) | isla alegre, en bucle |

### Lo que no nos sirve tanto

- **ambientCG y Poly Haven**: CC0 y de mucha calidad, pero realistas (fotos, PBR): chocan con el
  estilo de bloques. Quizá algún cielo (HDRI), poco más.

## Propuesta de uso

1. **Ya**: sonidos de Kenney + ambiente de Sonniss (olas, fuego, viento, pájaros, madera que
   cruje). Mejora enorme sin tocar nada más.
2. **Ya o pronto**: Kenney UI Pack RPG para inventario, menús y botones.
3. **Fase estética**: texturas 16x16 CC0 y decoración del suelo inspirada en el Nature Kit.
4. **Fase "personaje vivo"**: personaje con esqueleto + animaciones de Quaternius.
5. **Fauna**: animales de Quaternius.

Para descargar, Claude necesita tu permiso para cada paquete (nombre, origen y tamaño).
