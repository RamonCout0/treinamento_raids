// perigo.gdshader
// Brilho/pulso para os cubos de perigo (placeholder). Usa a cor do ColorRect (COLOR),
// então cada perigo pulsa na SUA cor. Preserva o alpha do telegrafo (piscar).
shader_type canvas_item;

uniform float pulse_speed = 6.0;   // velocidade do pulso
uniform float glow = 0.5;          // intensidade do brilho geral
uniform float edge_glow = 0.6;     // brilho extra nas bordas
uniform float scan_speed = 1.5;    // faixa de energia correndo

void fragment() {
	vec4 base = COLOR;

	float p = 0.5 + 0.5 * sin(TIME * pulse_speed);
	vec3 col = base.rgb * (1.0 + glow * p);

	vec2 uv = UV;
	float e = smoothstep(0.0, 0.18, uv.x) * smoothstep(0.0, 0.18, 1.0 - uv.x)
			* smoothstep(0.0, 0.18, uv.y) * smoothstep(0.0, 0.18, 1.0 - uv.y);
	col += base.rgb * (1.0 - e) * edge_glow;

	float scan = 0.5 + 0.5 * sin((uv.x + uv.y) * 8.0 - TIME * scan_speed * 6.0);
	col += base.rgb * scan * 0.12;

	COLOR = vec4(col, base.a);
}
