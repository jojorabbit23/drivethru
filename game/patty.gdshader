// A mushroom on the grill: the cap in its kind's colour, gills and stalk pale,
// the pickup texture only as speckle. `cook` browns it (0 raw .. 1 seared),
// `burnt` chars it. Model space is the pickup mesh: cap above y = -0.095.
shader_type spatial;
render_mode cull_disabled;

uniform vec4 cap_colour : source_color = vec4(0.52, 0.31, 0.18, 1.0);
uniform vec4 under_colour : source_color = vec4(0.914, 0.882, 0.820, 1.0); // WARM_CHALK
uniform float cook = 0.0;
uniform float burnt = 0.0;
uniform sampler2D detail : source_color, filter_nearest;

varying vec3 lp;
varying float ny;

void vertex() {
	lp = VERTEX;
	ny = NORMAL.y;
}

void fragment() {
	float is_cap = step(-0.095, lp.y) * smoothstep(-0.35, 0.05, ny);
	// gills and stalk: pale, tinted a little with the kind's colour
	vec3 under = mix(under_colour.rgb * 0.92, cap_colour.rgb, 0.22);
	float r = length(lp.xz);
	float gills = step(0.105, r) * (1.0 - is_cap);
	under *= 1.0 - 0.13 * gills * step(0.5, fract(atan(lp.z, lp.x) * 7.0));  // radial gill lines
	vec3 c = mix(under, cap_colour.rgb, is_cap);
	float d = dot(texture(detail, UV).rgb, vec3(0.333));
	c *= 0.82 + 0.36 * d;                        // speckle from the pickup's texture
	vec3 seared = mix(vec3(0.34, 0.16, 0.055), cap_colour.rgb * 0.48, is_cap * 0.35);  // darker, a touch warmer: still its own colour
	c = mix(c, seared, smoothstep(0.0, 0.7, cook));
	float stripes = 1.0 - step(0.13, abs(fract(lp.x * 18.0 + lp.z * 4.0) - 0.5));
	c *= 1.0 - stripes * smoothstep(0.3, 0.8, cook) * 0.55;
	c = mix(c, vec3(0.085, 0.07, 0.065), burnt);  // charred
	ALBEDO = c;
	ROUGHNESS = mix(0.8, 0.55, cook * (1.0 - burnt)); // a seared sheen
}
