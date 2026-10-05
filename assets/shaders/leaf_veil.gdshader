// Velo de hojas: cuando la cámara está dentro de la copa de un árbol se ve todo verde (sin esto,
// desde dentro de un trozo de hojas se veía a través de él lo que hay detrás del árbol). Es un
// plano pegado a la cámara, a medio metro: las manos, más cerca, se ven por delante.
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	// Manchas de hojas en cuadros grandes (como los cubitos de las copas), que se mueven un poco.
	vec2 cell = floor(FRAGCOORD.xy / 28.0 + vec2(TIME * 0.15, 0.0));
	float n = hash(cell);
	vec3 col = n < 0.45 ? vec3(0.10, 0.25, 0.07) : (n < 0.85 ? vec3(0.18, 0.38, 0.10) : vec3(0.32, 0.55, 0.14));
	vec2 uv = SCREEN_UV - 0.5;
	col *= 1.0 - dot(uv, uv) * 0.9;   // más oscuro por los bordes
	ALBEDO = pow(col, vec3(2.2));     // los colores van en sRGB
	ALPHA = 1.0;  // todo verde: nada de lo de detrás del árbol
}
