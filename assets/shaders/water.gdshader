// Agua de bloques (la orilla del mar, ríos, lagos y la que corre), con el mismo aspecto que el
// mar (sea.gdshader): se ve el fondo deformado por las ondas, turquesa poco profunda y azul
// profunda, refleja el cielo al mirarla de lado. Las ondas se mueven en el sentido de la
// corriente (flow_map, sacado del mapa del agua); por los lados (cascadas) bajan.
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, specular_schlick_ggx;

uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform vec4 water_color : source_color = vec4(0.12, 0.45, 0.70, 0.74);  // (se mantiene por compatibilidad)
uniform vec4 foam_color : source_color = vec4(0.62, 0.84, 0.95, 1.0);
uniform vec3 shallow_color : source_color = vec3(0.20, 0.82, 0.80);
uniform vec3 deep_color : source_color = vec3(0.02, 0.22, 0.45);
uniform sampler2D flow_map : filter_linear, repeat_disable;
uniform float map_half = 512.0;
uniform float voxel_size = 0.5;
uniform float depth_to_deep = 9.0;
uniform float clear_depth = 1.4;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);  // suave: sin facetas en las ondas
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float waves(vec2 p, vec2 flow) {
	return noise(p * 0.9 + vec2(TIME * 0.35, TIME * 0.12) - flow * TIME) * 0.6
		+ noise(p * 2.1 - vec2(TIME * 0.18, -TIME * 0.4) - flow * TIME * 1.3) * 0.4;
}

void fragment() {
	vec2 p;
	vec2 flow;
	if (world_normal.y > 0.5) {
		vec2 muv = (world_pos.xz / voxel_size + map_half) / (2.0 * map_half);
		vec3 f = texture(flow_map, muv).rgb;
		flow = (f.rg * 2.0 - 1.0) * f.b * 1.5;
		p = world_pos.xz;
	} else {
		flow = vec2(0.0, -3.0);  // los lados: el agua baja
		p = vec2(world_pos.x + world_pos.z, world_pos.y);
	}
	float e = 0.08;
	float h = waves(p, flow);
	vec2 slope = vec2(waves(p + vec2(e, 0.0), flow) - h, waves(p + vec2(0.0, e), flow) - h) / e;
	slope *= clamp(1.0 - length(VERTEX) / 70.0, 0.08, 1.0);
	vec3 n = world_normal.y > 0.5 ? normalize(vec3(-slope.x * 0.1, 1.0, -slope.y * 0.1)) : world_normal;
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);

	float raw_depth = texture(depth_texture, SCREEN_UV).r;
	vec4 behind = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, raw_depth, 1.0);
	behind.xyz /= behind.w;
	float depth = max(VERTEX.z - behind.z, 0.0);
	vec2 uv = SCREEN_UV + slope * 0.025 * clamp(depth, 0.0, 1.0);
	float raw2 = texture(depth_texture, uv).r;
	vec4 behind2 = INV_PROJECTION_MATRIX * vec4(uv * 2.0 - 1.0, raw2, 1.0);
	behind2.xyz /= behind2.w;
	if (behind2.z > VERTEX.z) {
		uv = SCREEN_UV;
	}
	vec3 bottom = textureLod(screen_texture, uv, 0.0).rgb;

	float deep = clamp(depth / depth_to_deep, 0.0, 1.0);
	vec3 water = mix(shallow_color, deep_color, deep);
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	float m = clamp(clamp(depth / clear_depth, 0.0, 1.0) * 0.85 + deep * 0.15 + fresnel * 0.75, 0.0, 1.0);
	// Espuma blanca donde el agua corre deprisa o cae (cascadas).
	float speed = length(flow);
	float foam = step(0.7, noise(p * 3.0 - flow * TIME * 2.0) + speed * 0.15) * clamp(speed, 0.0, 1.0);
	vec3 sky_tint = mix(water, vec3(0.62, 0.78, 0.9), fresnel * 0.6);
	ALBEDO = mix(sky_tint * m, foam_color.rgb, foam * 0.7);
	EMISSION = bottom * mix(vec3(1.0), shallow_color, 0.65) * (1.0 - m) * (1.0 - foam * 0.7);
	ALPHA = 1.0;
	ROUGHNESS = 0.2;
	SPECULAR = 0.55;
}
