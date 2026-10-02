// Mar: turquesa donde hay poca profundidad, azul profundo donde hay mucha.
// Calcula la profundidad comparando la superficie del agua con el fondo (buffer de profundidad).
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, specular_schlick_ggx;

uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;
uniform vec3 shallow_color : source_color = vec3(0.30, 0.86, 0.82);
uniform vec3 deep_color : source_color = vec3(0.03, 0.20, 0.48);
uniform float depth_to_deep = 7.0;   // metros hasta alcanzar el color profundo
uniform float shore_alpha = 0.45;
uniform float deep_alpha = 0.93;

void fragment() {
	float raw_depth = texture(depth_texture, SCREEN_UV).r;
	vec4 behind = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, raw_depth, 1.0);
	behind.xyz /= behind.w;
	float water_depth = clamp((VERTEX.z - behind.z) / depth_to_deep, 0.0, 1.0);

	ALBEDO = mix(shallow_color, deep_color, water_depth);
	ALPHA = mix(shore_alpha, deep_alpha, water_depth);
	ROUGHNESS = 0.06;
	SPECULAR = 0.6;
}
