// Isla lejana: malla simplificada coloreada por vértice. Cerca de la cámara se recorta
// (discard) porque ahí ya se dibujan los voxels con todo el detalle.
shader_type spatial;
render_mode cull_disabled;

uniform float hide_radius = 145.0;  // metros alrededor de la cámara donde no se dibuja

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	if (distance(world_pos.xz, CAMERA_POSITION_WORLD.xz) < hide_radius) {
		discard;
	}
	// Los colores de vértice vienen en sRGB, como los de los bloques: pasarlos a lineal.
	ALBEDO = pow(COLOR.rgb, vec3(2.2));
	ROUGHNESS = 0.92;
	SPECULAR = 0.2;
}
