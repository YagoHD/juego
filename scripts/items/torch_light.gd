class_name TorchLight
## Luz y llama de las antorchas (en el suelo y en la mano), con parpadeo.

const COLOR := Color(1.0, 0.68, 0.32)


static func make_light() -> OmniLight3D:
	var light := OmniLight3D.new()
	light.light_color = COLOR
	light.light_energy = 1.6
	light.omni_range = 7.0
	light.omni_attenuation = 1.2
	light.shadow_enabled = false  # muchas antorchas con sombra serían caras
	return light


static func make_flame() -> MeshInstance3D:
	var flame := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.07, 0.11, 0.07)
	flame.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.75, 0.3)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.55, 0.15)
	material.emission_energy_multiplier = 3.0
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flame.material_override = material
	flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return flame


## Parpadeo: la luz sube y baja un poco y la llama baila.
static func flicker(light: OmniLight3D, flame: Node3D, t: float) -> void:
	var f := sin(t * 11.0) * 0.5 + sin(t * 17.3 + 1.7) * 0.3 + sin(t * 5.1) * 0.2
	light.light_energy = 1.6 + f * 0.25
	if flame != null:
		flame.scale = Vector3(1.0 - f * 0.1, 1.0 + f * 0.18, 1.0 - f * 0.1)
		flame.rotation.y = t * 2.0
