shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform sampler2D roughness_tex : filter_linear_mipmap;
uniform bool regions = true;
uniform bool watch_face = false;
uniform vec4 tint : source_color = vec4(1.0);
void vertex() {
 vec4 view_pos = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
 view_pos.xyz *= 0.1;
 POSITION = PROJECTION_MATRIX * view_pos;
}
void fragment() {
 vec2 uv = UV;
 if (regions) {
  float kind = floor(UV2.x + 0.5);
  // Mesh regions: sleeve / cuff / glove / skin. HD atlas: glove / sleeve / cuff / skin.
  float tile = kind < 0.5 ? 1.0 : (kind < 1.5 ? 2.0 : (kind < 2.5 ? 0.0 : 3.0));
  vec2 within_tile = vec2(0.006) + fract(UV * 16.0) * 0.988;
  uv = (vec2(tile, 0.0) + within_tile) / vec2(4.0, 2.0);
 } else if (watch_face) {
  uv = vec2(0.75, 0.5) + UV * vec2(0.25, 0.5);
 }
 bool textured = regions || watch_face;
 vec3 base = textured ? texture(albedo_tex, uv).rgb : vec3(1.0);
 ALBEDO = base * COLOR.rgb * tint.rgb;
 ROUGHNESS = textured ? texture(roughness_tex, uv).r : 0.88;
 METALLIC = 0.0;
}
