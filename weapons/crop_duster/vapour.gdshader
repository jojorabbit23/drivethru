shader_type spatial;
render_mode cull_disabled, blend_mix, depth_draw_never;
uniform vec4 colour : source_color;
void vertex() {
 vec4 p = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
 p.xyz *= 0.1;
 POSITION = PROJECTION_MATRIX * p;
}
void fragment() {
 ALBEDO=colour.rgb;
 ALPHA=colour.a;
 ROUGHNESS=1.0;
}
