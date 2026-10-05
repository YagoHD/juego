// Hojas de los árboles: como el material de los prefabs (colores de la paleta), pero con las dos
// caras. Desde dentro de una copa, sin esto, se veía a través de las hojas lo que hay detrás.
// Las caras de espaldas solo se dibujan en los trozos de terreno junto a la cámara (el árbol
// que se está cruzando): en el resto, la cara se aplasta en un punto y no cuesta nada.
shader_type spatial;
render_mode cull_disabled;

uniform sampler2D palette : source_color, filter_nearest;

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;   // esquina del trozo de terreno (8 o 16 m de lado)
	vec3 cam = CAMERA_POSITION_WORLD;
	bool near = all(greaterThan(cam, origin - vec3(3.0))) && all(lessThan(cam, origin + vec3(19.0)));
	if (!near) {
		vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		vec3 world_normal = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
		if (dot(world_normal, cam - world_pos) < 0.0) {
			VERTEX = vec3(0.0);  // de espaldas y lejos: no se dibuja
		}
	}
}

void fragment() {
	ALBEDO = texture(palette, UV).rgb;
	ROUGHNESS = 1.0;
}
