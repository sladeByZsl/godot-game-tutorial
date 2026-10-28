// 受伤闪白：flash = 1 时整张图变成 flash_color，保留透明度。
shader_type canvas_item;

uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
	COLOR.rgb = mix(COLOR.rgb, flash_color.rgb, flash);
}
