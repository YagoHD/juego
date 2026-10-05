extends Resource
class_name VoxelModelData
## Un modelo ya pasado a cubitos (tools/voxelize_character.gd): Vector3i -> Color, con los pies en
## y = 0 y centrado en x y z. Lo usa CastawayModel para montar el personaje.

@export var cells := {}
@export var size := Vector3i.ZERO
