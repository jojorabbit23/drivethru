// Shared first-person arms. Same viewmodel depth squeeze as the other weapon
// shaders (arms_viewmodel.gdshader, shotgun viewmodel.gdshader), so the arms
// never clip into walls and sort consistently with every gun.
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap;
uniform sampler2D roughness_tex : filter_linear_mipmap; // glTF metal/rough: roughness in G
uniform bool use_normal = true;
uniform vec4 albedo_color : source_color = vec4(1.0); // untextured parts (the SMG's gun body, wood, rounds)
void vertex() {
 vec4 view_pos = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
 view_pos.xyz *= 0.1;
 POSITION = PROJECTION_MATRIX * view_pos;
}
void fragment() {
 ALBEDO = texture(albedo_tex, UV).rgb * albedo_color.rgb;
 ROUGHNESS = clamp(texture(roughness_tex, UV).g, 0.55, 1.0);
 METALLIC = 0.0;
 if (use_normal) {
  NORMAL_MAP = texture(normal_tex, UV).rgb;
  NORMAL_MAP_DEPTH = 0.6;
 }
}
