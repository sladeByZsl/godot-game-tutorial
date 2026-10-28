## 全屏背景：上下渐变 + 四角压暗，给所有小场景统一的底色。
extends Node2D


func _ready() -> void:
	get_viewport().size_changed.connect(queue_redraw)


func _draw() -> void:
	var r := get_viewport_rect()
	var top := Pal.BG
	var bottom := Pal.BG2
	draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]),
		PackedColorArray([top, top, bottom, bottom]))
	# 中间一团很淡的蓝色光，让画面不那么"平"
	Pal.glow(self, r.get_center() + Vector2(0, 40), r.size.x * 0.55, Color(0.25, 0.4, 0.8, 0.10))
