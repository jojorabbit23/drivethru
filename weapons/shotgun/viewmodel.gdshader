shader_type spatial;
render_mode cull_disabled;
uniform sampler2D albedo_tex : source_color, filter_nearest_mipmap;
uniform vec4 colour : source_color = vec4(1.0);
uniform bool textured = false;
void vertex() {
 vec4 p=MODELVIEW_MATRIX*vec4(VERTEX,1.0);
 p.xyz*=0.1; // exactly the same viewmodel depth as arms_viewmodel.gdshader
 POSITION=PROJECTION_MATRIX*p;
}
void fragment() {
 ALBEDO=colour.rgb*(textured?texture(albedo_tex,UV).rgb:vec3(1.0));
 ROUGHNESS=0.85;
 METALLIC=0.0;
}
