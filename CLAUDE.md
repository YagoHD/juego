# Isla del Naufragio — instrucciones para Claude

## Con quién trabajas
- **Yago** es el autor de las ideas y **no programa**: Claude escribe todo el código. Habla en
  **español** informal (con erratas); responde siempre en español, en lenguaje no técnico, con
  pasos concretos.
- Verifica tú todo lo posible (pruebas sin ventana, capturas) antes de pedirle que pruebe.
- Puede dejarte trabajando solo: primero sus encargos, luego mejoras de valor y poco riesgo;
  **commit por cada paso** y un resumen claro al volver. No borres su mundo guardado ni tomes
  decisiones de diseño grandes sin él: propónlas.
- **Mecánicas clave (fabricación, combate, etc.) se diseñan con él**; no copiar Minecraft.
- **Reparto**: ChatGPT hace el arte (hojas de la guía visual: texturas, iconos, hojas de vistas);
  Claude el código, los modelos de cajas sacados de esas hojas, los objetos y las mecánicas. Todo lo
  nuevo que necesite arte se apunta en `docs/TEXTURAS.md` con su prompt.
- **Estilo**: Minecraft Dungeons en primera/tercera persona (`docs/ANALISIS_ESTILO.md`). **Meshy NO
  se usa** (decidido por Yago, 2026-10-07): sus modelos lisos no encajan; todo se rehace con el
  sistema nuevo (modelos de cajas con esqueleto desde hojas de vistas: `tools/modelo_desde_guia.py`).

## El proyecto
- Godot **4.7.2 de Zylann con godot_voxel 1.7 integrado** (el Godot normal no sirve). Todo en
  GDScript.
- Estado y arquitectura: `docs/STATUS.md`. Diseño: `docs/DESIGN.md`. Leerlos al empezar.
- **Relevo pendiente**: `docs/CONTINUAR.md` dice por dónde seguir (lo hecho en la nube y el encargo del personaje de "personaje beta"). Leerlo primero.
- La isla y el naufragio son **solo la Beta** (tutorial hecho a mano). El juego final es un
  **mundo medieval grande, a poder ser procedural**: prioriza sistemas generales que sirvan ahí.

## Probar
- Pruebas sin ventana: `bash tools/run_tests.sh` (o `bash tools/run_tests.sh nombre ...`).
- **En el PC de Yago (Windows)**: el Godot está en `C:\Users\yagor\Desktop\godot.windows.editor.x86_64.exe`;
  capturas con `powershell -File tools/capture.ps1 -Out foto.png -Showroom` (la sala de muestras
  carga en ~15 s; la isla tarda minutos). `Sala de muestras.bat` la abre para Yago.
- **En la nube (Linux, sin tarjeta gráfica)**: `tools/setup_cloud.sh` (se lanza solo al empezar)
  descarga el Godot de Linux en `./godot` e importa el proyecto. Las pruebas sin ventana
  funcionan. **Capturas**: sin GPU, pero sí con dibujo por software (lento):
  `LIBGL_ALWAYS_SOFTWARE=1 xvfb-run -a -s "-screen 0 1280x720x24" ./godot --rendering-driver opengl3 --path . --script res://tools/preview_grips.gd --resolution 1280x720`
  (deja las imágenes en `.godot/grip_previews/`). Sirve para escenas pequeñas; la isla, mejor en el PC de Yago.
- **No lanzar dos pruebas a la vez**: comparten el mundo de pruebas y se corrompen.
- Si creas un `class_name` nuevo, ejecuta `godot --headless --path . --import` antes de probar.
