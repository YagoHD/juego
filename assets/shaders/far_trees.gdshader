// Árboles sencillos de lo lejos (FarTrees): colores por vértice por el tono de cada árbol. Los que
// están dentro de la zona de detalle se esconden (ahí están los árboles de verdad): sus vértices
// se juntan en un punto y no se dibuja nada.
shader_type spatial;
render_mode cull_back;

uniform float hide_radius = 120.0;

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	if (distance(origin.xz, CAMERA_POSITION_WORLD.xz) < hide_radius) {
		VERTEX = vec3(0.0);
	}
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 1.0;
	SPECULAR = 0.1;
}
