shader_type canvas_item;

uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform float softness : hint_range(0.1, 1.0) = 0.5;
uniform vec4 color : source_color = vec4(0.04, 0.02, 0.08, 1.0);
uniform bool spotlight_enabled = false;
uniform vec2 viewport_size = vec2(1280.0, 720.0);
uniform vec2 spotlight_center_px = vec2(640.0, 360.0);
uniform float spotlight_radius_px = 180.0;
uniform float spotlight_feather_px = 120.0;
uniform float spotlight_strength : hint_range(0.0, 1.0) = 0.88;

void fragment() {
	vec2 uv = UV - 0.5;
	float dist = length(uv) * 2.0;
	float vignette = smoothstep(1.0 - softness, 1.0, dist);
	float overlay_alpha = vignette * intensity;

	if (spotlight_enabled) {
		vec2 pixel_pos = UV * viewport_size;
		float spotlight_dist = distance(pixel_pos, spotlight_center_px);
		float spot = smoothstep(spotlight_radius_px, spotlight_radius_px + spotlight_feather_px, spotlight_dist);
		overlay_alpha = max(overlay_alpha, spot * spotlight_strength);
	}

	COLOR = vec4(color.rgb, clamp(overlay_alpha, 0.0, 1.0));
}
