## 特效：粒子、飘分数字、直线炸弹的光束和范围炸弹的冲击环。
class_name BoardFx
extends Node2D

var _effects: Array[Dictionary] = []    # 光束和冲击环：{type, a, b, t, dur, color}
var _dot: Texture2D


func _ready() -> void:
	# 粒子用的小圆点贴图：用代码生成一张 16×16 的柔边圆
	var img := Image.create_empty(16, 16, false, Image.FORMAT_RGBA8)
	for y in 16:
		for x in 16:
			var d := Vector2(x - 7.5, y - 7.5).length() / 8.0
			img.set_pixel(x, y, Color(1, 1, 1, clampf(1.0 - d, 0.0, 1.0) ** 1.5))
	_dot = ImageTexture.create_from_image(img)


#region burst
## 一次性爆开的粒子。one_shot + explosiveness=1：所有粒子同一时刻发射。
func burst(pos: Vector2, color: Color, size_px: float) -> void:
	var p := CPUParticles2D.new()
	p.position = pos
	p.texture = _dot
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 12
	p.lifetime = 0.55
	p.spread = 180.0
	p.initial_velocity_min = size_px * 1.6
	p.initial_velocity_max = size_px * 4.2
	p.gravity = Vector2(0, size_px * 9.0)
	p.damping_min = size_px * 1.5
	p.damping_max = size_px * 3.0
	p.scale_amount_min = size_px / 90.0
	p.scale_amount_max = size_px / 40.0
	var ramp := Gradient.new()
	ramp.set_color(0, color.lightened(0.35))
	ramp.set_color(1, Color(color, 0.0))
	p.color_ramp = ramp
	p.finished.connect(p.queue_free)
	add_child(p)
	p.emitting = true
#endregion


#region float_text
## 飘出的分数：Label 往上飘 + 淡出，结束后自己删掉。
func float_text(pos: Vector2, text: String, color: Color, font_size: int) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.12))
	l.add_theme_constant_override("outline_size", maxi(4, font_size / 4))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	l.size = l.get_minimum_size()
	l.position = pos - l.size * 0.5
	l.pivot_offset = l.size * 0.5
	l.scale = Vector2(0.4, 0.4)
	var tw := l.create_tween().set_parallel(true)
	tw.tween_property(l, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "position:y", l.position.y - font_size * 2.2, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.35).set_delay(0.6)
	tw.finished.connect(l.queue_free)
#endregion


func beam(a: Vector2, b: Vector2, color: Color, width: float) -> void:
	_effects.append({"type": "beam", "a": a, "b": b, "t": 0.0, "dur": 0.35, "color": color, "w": width})


func ring(pos: Vector2, radius: float, color: Color) -> void:
	_effects.append({"type": "ring", "a": pos, "b": Vector2(radius, 0), "t": 0.0, "dur": 0.4, "color": color, "w": radius * 0.18})


func _process(delta: float) -> void:
	for e in _effects:
		e.t += delta
	_effects = _effects.filter(func(e: Dictionary) -> bool: return e.t < e.dur)
	queue_redraw()


func _draw() -> void:
	for e in _effects:
		var k: float = e.t / e.dur
		var c: Color = e.color
		if e.type == "beam":
			draw_line(e.a, e.b, Color(c, 0.5 * (1.0 - k)), e.w * (1.0 + k), true)
			draw_line(e.a, e.b, Color(1, 1, 1, 1.0 - k), e.w * 0.35, true)
		else:
			draw_arc(e.a, e.b.x * (0.4 + 1.2 * k), 0, TAU, 48, Color(c, 1.0 - k), e.w * (1.0 - k) + 1.0, true)
