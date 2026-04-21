shader_type canvas_item;

uniform float factor: hint_range(0.0, 1.0);
// intensity of the color on 0.5 value of factor
uniform float color_middle: hint_range(0.0, 1.0, 0.1) = 0.5;
uniform vec3 hue_shift = vec3(1.5,0.815,2.895);

void fragment() {
	vec3 inverted_color = 1. - COLOR.rgb;
	vec3 orig_color = COLOR.rgb;
	
	// distance from factor to center value (0.5)
	float dist = (distance(factor,0.5) - 0.5) * color_middle;
	
	// shift hue by values in hue shift
	vec3 factor_v = vec3(factor + dist / hue_shift.r, factor + dist / 
	hue_shift.g, factor + dist / hue_shift.b);
	
	COLOR.rgb = mix(orig_color, inverted_color, factor_v);
}