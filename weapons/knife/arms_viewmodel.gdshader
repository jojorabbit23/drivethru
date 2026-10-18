shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;
uniform sampler2D albedo_tex : source_color, filter_nearest_mipmap;
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
  uv = (vec2(kind * 64.0 + 1.0, 129.0) + fract(UV * 16.0) * 62.0) / 512.0;
 } else if (watch_face) {
  uv = (vec2(256.0,128.0) + UV * vec2(128.0,64.0)) / 512.0;
 }
 vec3 base = (!regions && !watch_face) ? vec3(1.0) : texture(albedo_tex, uv).rgb;
 ALBEDO = base * COLOR.rgb * tint.rgb;
 ROUGHNESS = 0.88;
 METALLIC = 0.0;
}
