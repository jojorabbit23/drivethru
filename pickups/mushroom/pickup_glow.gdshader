// Soft orange halo for pickups: an additive fresnel shell drawn just outside
// the mesh. Used as the next_pass of the pickup material.
shader_type spatial;
render_mode blend_add, unshaded, cull_back, depth_draw_never, shadows_disabled;

uniform vec4 glow_color : source_color = vec4(0.953, 0.639, 0.302, 1.0); // AMBER_GLOW
uniform float strength = 0.7;
uniform float pulse = 1.0;   // driven by the pickup script
uniform float inflate = 0.008;

void vertex() {
	VERTEX += NORMAL * inflate;
}

void fragment() {
	float rim = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	ALBEDO = glow_color.rgb * pow(rim, 2.2) * strength * pulse;
}
