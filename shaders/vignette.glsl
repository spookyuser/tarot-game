vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords) {
  vec2 uv = screen_coords / vec2(1280.0, 720.0);
  float vig = smoothstep(0.95, 0.35, distance(uv, vec2(0.5)));
  vec4 px = Texel(tex, texture_coords) * color;
  px.rgb *= mix(0.65, 1.0, vig);
  return px;
}
