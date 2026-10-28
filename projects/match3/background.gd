## 背景：竖向渐变 + 几个缓慢漂动的柔光圆。
extends Node2D

var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var r := get_viewport_rect()
	var top := Color("#232a52")
	var bottom := Color("#120f24")
	draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]),
			PackedColorArray([top, top, bottom, bottom]))
	var blobs := [[0.15, 0.25, 0.22, Color("#6b5bff")], [0.85, 0.7, 0.28, Color("#ff5f9e")], [0.55, 0.1, 0.18, Color("#3fd0ff")]]
	for b in blobs:
		var center := Vector2(r.size.x * b[0], r.size.y * b[1]) + Vector2(sin(_t * 0.3 + b[2] * 10.0), cos(_t * 0.25 + b[0] * 7.0)) * 20.0
		var rad: float = r.size.length() * b[2]
		for i in 6:
			draw_circle(center, rad * (1.0 - i * 0.15), Color(b[3], 0.025), true)
