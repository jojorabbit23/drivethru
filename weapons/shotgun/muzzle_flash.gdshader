shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform sampler2D flash_tex : filter_nearest;
uniform vec4 colour : source_color;
void vertex() {
 vec4 p=MODELVIEW_MATRIX*vec4(VERTEX,1.0);
 p.xyz*=0.1;
 POSITION=PROJECTION_MATRIX*p;
}
void fragment() {
 vec4 tex=texture(flash_tex,UV);
 ALBEDO=colour.rgb;
 ALPHA=tex.a*colour.a;
}
