shader_type spatial;
render_mode specular_schlick_ggx;
uniform vec4 shell_color : source_color = vec4(.12,.19,.26,1.0);
uniform vec4 accent : source_color = vec4(.3,.8,1.0,1.0);
uniform int value = 1;
uniform vec4 energy_color : source_color = vec4(.04,1.0,.72,1.0);
uniform float reveal : hint_range(0.0,1.0) = 0.0;
varying vec3 face_normal;
void vertex() { face_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL); }
float hole(vec2 p, vec2 center) { return length(p-center); }
void fragment() {
	vec2 p = UV-.5;
	float d = 1.0;
	if (value == 1 || value == 3 || value == 5) d = min(d,hole(p,vec2(0.0)));
	if (value >= 2) {
		d = min(d,hole(p,vec2(-.265,-.265)));
		d = min(d,hole(p,vec2(.265,.265)));
	}
	if (value >= 4) {
		d = min(d,hole(p,vec2(-.265,.265)));
		d = min(d,hole(p,vec2(.265,-.265)));
	}
	if (value == 6) {
		d = min(d,hole(p,vec2(-.265,0.0)));
		d = min(d,hole(p,vec2(.265,0.0)));
	}
	float aa = max(fwidth(d),.001);
	float well = 1.0-smoothstep(.079-aa,.079+aa,d);
	float pip = 1.0-smoothstep(.052-aa,.052+aa,d);
	float lip = smoothstep(.065,.077,d)*well;
	float top = smoothstep(.75,.98,face_normal.y);
	float brightness = mix(1.0,mix(.55,1.0,top),reveal);
	// Every face keeps its numbered pips throughout flight and rest.
	float liquid = .8+.2*sin(p.y*20.0+p.x*14.0-TIME*4.0);
	vec3 inset = mix(vec3(.018,.027,.04),energy_color.rgb*brightness,pip);
	vec3 body = shell_color.rgb;
	// A thin inset perimeter and engraved index bars stay quieter than the pips.
	float edge = max(abs(p.x),abs(p.y));
	float seam = smoothstep(.455,.463,edge)*(1.0-smoothstep(.466,.473,edge));
	float bars = step(.39,p.y)*step(p.y,.41)*step(abs(p.x),.16);
	ALBEDO = mix(body,inset,well)+lip*.065;
	ALBEDO = mix(ALBEDO,body*.45,seam);
	ALBEDO = mix(ALBEDO,accent.rgb*.4,bars*.5);
	METALLIC = mix(.65,.15,pip);
	ROUGHNESS = mix(.38,.55,well);
	float frame = smoothstep(.456,.462,edge)*(1.0-smoothstep(.473,.480,edge));
	EMISSION = pip*energy_color.rgb*brightness*liquid*4.0 + frame*energy_color.rgb*2.2 + bars*accent.rgb*.25;
}
