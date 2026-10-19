shader_type spatial;
render_mode cull_disabled;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform sampler2D orm_tex : filter_linear_mipmap;
uniform bool has_orm = false;
uniform bool visible_part = true;
uniform vec4 colour : source_color = vec4(1.0);
uniform bool textured = false;
uniform float roughness = 0.8;
uniform float metallic = 0.0;
void vertex() {
 vec4 p = MODELVIEW_MATRIX * vec4(VERTEX,1.0);
 p.xyz *= 0.1;
 POSITION = PROJECTION_MATRIX * p;
}
void fragment() {
 if (!visible_part) { discard; }
 ALBEDO = colour.rgb * (textured ? texture(albedo_tex,UV).rgb : vec3(1.0));
 ROUGHNESS = has_orm ? texture(orm_tex,UV).g * roughness : roughness;
 METALLIC = has_orm ? texture(orm_tex,UV).b * metallic : metallic;
}
