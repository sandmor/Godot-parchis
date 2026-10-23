shader_type spatial;
uniform vec4 energy_color : source_color = vec4(.04,1.0,.72,1.0);
uniform float flare = 0.0;
void fragment() {
	float flow = .82+.18*sin(UV.y*24.0-TIME*5.0+sin(UV.y*11.0+TIME*2.0));
	ALBEDO = energy_color.rgb*.35;
	METALLIC = .25;
	ROUGHNESS = .28;
	EMISSION = energy_color.rgb*flow*(3.2+flare*2.0);
}
