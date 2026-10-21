shader_type spatial;
render_mode unshaded,cull_disabled;
uniform sampler2D paper : source_color,filter_nearest;
uniform float wear=0.0;
void fragment(){
 vec4 ink=texture(paper,UV);
 float tear=step(1.0-wear*.28,UV.x)*step(.55,UV.y);
 if(tear>.5)discard;
 float grain=fract(sin(dot(floor(UV*120.0),vec2(12.9898,78.233)))*43758.5453);
 ALBEDO=ink.rgb*(1.0-wear*.2*step(.65,grain));
 ALPHA=ink.a;ALPHA_SCISSOR_THRESHOLD=.5;
}
