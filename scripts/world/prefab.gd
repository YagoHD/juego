extends Resource
class_name Prefab
## Un modelo (palmera, roca...) ya convertido en cubitos y troceado en bloques del mundo. Cada
## pieza es un bloque con su propia malla (en el espacio de un bloque, 0..1) y su tipo:
## "wood" (tronco: se tala, da madera), "leaves" (hojas), "rock" (roca: da piedras),
## "mushroom" (setas). Lo genera tools/bake_prefabs.gd; lo usa PrefabLibrary.

@export var prefab_name := ""
@export var cells: Array[Vector3i] = []      # posición de cada pieza respecto a la base (en bloques)
@export var meshes: Array[ArrayMesh] = []    # malla de cada pieza (espacio 0..1 del bloque)
@export var kinds: PackedStringArray = []    # tipo de cada pieza
@export var colors: PackedColorArray = []    # color medio de cada pieza (partículas, mapa)
