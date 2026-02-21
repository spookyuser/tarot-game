shader_type canvas_item;

uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform float softness : hint_range(0.1, 1.0) = 0.5;
uniform vec4 color : source_color = vec4(0.04, 0.02, 0.08, 1.0);

void fragment() {
	vec2 uv = UV - 0.5;
	float dist = length(uv) * 2.0;
	float vignette = smoothstep(1.0 - softness, 1.0, dist);
	COLOR = vec4(color.rgb, vignette * intensity);
}
