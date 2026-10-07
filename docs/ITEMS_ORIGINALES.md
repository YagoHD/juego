# Modelos originales de Meshy y agarre en primera persona

`tools/import_items.gd` conserva todos los triángulos, materiales, tangentes y píxeles de los GLB de `assets/models_raw/meshy/items`. Solo centra y normaliza el tamaño de las mallas y separa objetos que vienen juntos. No volver a aplicar reducción a 4000 triángulos ni texturas WebP reducidas si se quiere mantener esta versión.

Los GLB de `spear`, `arrow` y `stone_axe` contienen dos copias: la primera se usa en el juego y la segunda se guarda como `<id>_variant.res`. El GLB de `stone_axe` contiene cabezas de piedra sin mango; se conserva como hacha de mano. El archivo de recursos se separa en `log_bundle`, `rock` y `flint`. No se han añadido mecánicas para las armas que todavía no están en ItemDB.

`HeldBlock` dibuja el brazo y el objeto en una vista transparente con profundidad propia. Usa las manos originales de Meshy de `docs/mano`: masculina en la carpeta raíz y femenina en `femeninai`. `tools/import_view_hands.gd` las guarda en `assets/models/hands/hombre.scn` y `mujer.scn`, conservando sus mallas, materiales, esqueletos y pesos. El masculino tiene 29 huesos y el femenino 28. `meshy_view_hand.gd` identifica sus articulaciones, normaliza la orientación y anima los dedos mediante rotaciones de huesos. La selección sigue `Settings.body`.

No deformar los vértices del antebrazo para cerrar la mano ni alargarlo con una pieza independiente. Las longitudes y escalas de los huesos originales permanecen constantes en todas las poses. `first_person_hand.gd` se conserva como alternativa si falta un modelo importado. El personaje en tercera persona conserva su modelo.

`first_person_items.gd` define la longitud, inclinación, punto de agarre y pose de cada herramienta. `ItemMesh.make_held` aplica una escala uniforme y evita los multiplicadores genéricos del resto de vistas. El pico mide 0,55 en la vista, el cuchillo 0,32 y la lanza 1,05, con puntos de agarre independientes. Los objetos sin perfil reciben tamaños por categoría. Los modelos originales y sus texturas se conservan.

La capa 20 es exclusiva de esta vista; la cámara del jugador y la de fabricación la excluyen para que no se dibuje dos veces. Tiene iluminación propia suave que sigue la luz ambiente. Al cambiar a tercera persona o a otra cámara se oculta la vista.

Verificación: `tools/check_original_items.gd` compara la suma de triángulos y los píxeles de las texturas contra cada GLB original. `tools/test_first_person_grip.gd` comprueba cinco poses sin estirar los huesos, la longitud visual y la escala uniforme de todos los perfiles 3D. `tools/preview_grips.gd` permite revisar las siete herramientas y recursos disponibles, la mano vacía y un bloque; guarda las imágenes en `.godot/grip_previews/`.

Estos originales son mucho más pesados que las versiones simplificadas. Si se optimizan más adelante, guardar la alternativa por separado y comparar el resultado visual antes de sustituirlos.
