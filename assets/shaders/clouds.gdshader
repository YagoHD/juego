// Nubes de bloques: color plano (lo fija DayNight según la hora) con caras más oscuras abajo y a
// los lados, para que se lean en 3D. Sin iluminación propia: así el color de cada hora manda.
shader_type spatial;
render_mode unshaded, cull_back;

uniform vec3 cloud_color : source_color = vec3(1.0);

varying float shade;

void vertex() {
	shade = NORMAL.y > 0.5 ? 1.0 : (NORMAL.y < -0.5 ? 0.74 : 0.87);
}

void fragment() {
	ALBEDO = cloud_color * shade;
}
