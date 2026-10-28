// 远景层的"空气透视"：把颜色往天空色混合，看起来更远、更淡。
shader_type canvas_item;

uniform vec4 haze : source_color = vec4(0.64, 0.77, 0.92, 1.0);
uniform float amount : hint_range(0.0, 1.0) = 0.55;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	COLOR = vec4(mix(c.rgb, haze.rgb, amount), c.a);
}
