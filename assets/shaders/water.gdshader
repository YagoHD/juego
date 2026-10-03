// Agua de ríos, lagos y la que corre: translúcida, de color liso (como el resto del estilo) y
// con ondas claras que se mueven en el sentido de la corriente (flow_map, sacado del mapa del
// agua). Por los lados (cascadas, agua que cae) las ondas bajan.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;

uniform vec4 water_color : source_color = vec4(0.12, 0.45, 0.70, 0.74);
uniform vec4 foam_color : source_color = vec4(0.62, 0.84, 0.95, 1.0);
uniform sampler2D flow_map : filter_linear, repeat_disable;
uniform float map_half = 512.0;
uniform float voxel_size = 0.5;

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
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float ripples(vec2 p) {
	return noise(p) * 0.6 + noise(p * 2.3 + 7.0) * 0.4;
}

void fragment() {
	vec2 p;
	vec2 flow;
	float speed;
	if (world_normal.y > 0.5) {
		// Arriba: según la corriente del río (en los lagos, apenas se mueve).
		vec2 muv = (world_pos.xz / voxel_size + map_half) / (2.0 * map_half);
		vec3 f = texture(flow_map, muv).rgb;
		flow = (f.rg * 2.0 - 1.0) * f.b;
		speed = 0.25 + f.b;
		p = world_pos.xz * 1.6;
	} else {
		// Los lados: el agua baja.
		flow = vec2(0.0, -1.0);
		speed = 2.0;
		p = vec2(world_pos.x + world_pos.z, world_pos.y) * 1.6;
	}
	// Dos capas desfasadas que se van turnando (así la textura no se estira sin fin).
	float t = TIME * 0.35;
	float ph0 = fract(t);
	float ph1 = fract(t + 0.5);
	vec2 drift = vec2(TIME * 0.03, TIME * 0.02);  // el agua quieta también se mueve un poco
	float r0 = ripples(p + drift - flow * ph0 * speed * 3.0);
	float r1 = ripples(p + drift - flow * ph1 * speed * 3.0 + 3.7);
	float r = mix(r0, r1, abs(1.0 - 2.0 * ph0));
	float foam = smoothstep(0.6, 0.78, r);
	ALBEDO = mix(water_color.rgb, foam_color.rgb, foam * 0.55);
	ALPHA = clamp(water_color.a + foam * 0.12, 0.0, 1.0);
	ROUGHNESS = 0.3;
	SPECULAR = 0.35;
}
