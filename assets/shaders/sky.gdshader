// Cielo del ciclo día/noche: degradado (los colores los fija DayNight según la hora), disco y
// halo del sol (luz 0), disco de la luna (luz 1) y estrellas por la noche.
shader_type sky;

uniform vec3 top_color : source_color = vec3(0.22, 0.48, 0.88);
uniform vec3 horizon_color : source_color = vec3(0.68, 0.82, 0.95);
uniform vec3 ground_color : source_color = vec3(0.20, 0.35, 0.55);
uniform vec3 sun_glow_color : source_color = vec3(1.0, 0.9, 0.7);
uniform float sun_glow = 0.35;
uniform float stars = 0.0;  // 0 de día, 1 en plena noche

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

void sky() {
	vec3 dir = EYEDIR;
	float up = dir.y;
	vec3 col;
	if (up >= 0.0) {
		col = mix(horizon_color, top_color, pow(clamp(up, 0.0, 1.0), 0.55));
	} else {
		col = mix(horizon_color, ground_color, clamp(-up * 4.0, 0.0, 1.0));
	}

	// Sol: disco nítido y un halo que tiñe el cielo a su alrededor.
	if (LIGHT0_ENABLED) {
		float d = dot(dir, LIGHT0_DIRECTION);
		col += LIGHT0_COLOR * smoothstep(0.99955, 0.99975, d) * 6.0;
		col += sun_glow_color * pow(max(d, 0.0), 10.0) * sun_glow;
	}
	// Luna: disco blanco azulado con un halo muy suave.
	if (LIGHT1_ENABLED) {
		float d = dot(dir, LIGHT1_DIRECTION);
		col += vec3(0.85, 0.9, 1.0) * smoothstep(0.99935, 0.99955, d) * 1.6;
		col += vec3(0.3, 0.38, 0.55) * pow(max(d, 0.0), 30.0) * 0.25;
	}
	// Estrellas: puntos en una cuadrícula de direcciones, solo por encima del horizonte.
	if (stars > 0.0 && up > 0.0) {
		vec3 p = dir * 220.0;
		vec3 cell = floor(p);
		float h = hash(cell);
		if (h > 0.9965) {
			float dist = length(fract(p) - 0.5);
			float twinkle = 0.7 + 0.3 * sin(TIME * (1.5 + h * 4.0) + h * 40.0);
			col += vec3(1.0, 0.97, 0.9) * smoothstep(0.35, 0.0, dist) * stars * twinkle
				* smoothstep(0.0, 0.25, up);
		}
	}
	COLOR = col;
}
