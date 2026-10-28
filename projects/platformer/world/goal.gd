## 终点旗：玩家碰到后放彩带、通知 HUD 显示通关。
extends Area2D

signal reached

var _done := false
var _t := 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _on_body_entered(body: Node2D) -> void:
	if _done or not body is Player:
		return
	_done = true
	for i in 5:
		Fx.sparkle(global_position + Vector2(randf_range(-60, 60), randf_range(-110, -40)),
				Color.from_hsv(randf(), 0.7, 1.0), 14)
	Fx.add_trauma(0.3)
	reached.emit()


func _draw() -> void:
	var outline := Color("#3d2b22")
	draw_rect(Rect2(-12, -8, 24, 8), outline)
	draw_rect(Rect2(-10, -7, 20, 6), Color("#8a8fa3"))
	draw_rect(Rect2(-3, -110, 6, 104), outline)
	draw_rect(Rect2(-1.5, -109, 3, 102), Color("#f2f2f2"))
	draw_circle(Vector2(0, -112), 5.0, Color("#ffc93c"), true, -1.0, true)
	# 方格旗，右边缘随时间飘动
	var cells := 5
	for i in cells:
		for j in 3:
			var x0 := 3.0 + i * 8.0
			var wave := sin(_t * 5.0 - i * 0.8) * 3.0
			var wave2 := sin(_t * 5.0 - (i + 1) * 0.8) * 3.0
			var y0 := -106.0 + j * 9.0
			var quad := PackedVector2Array([Vector2(x0, y0 + wave), Vector2(x0 + 8, y0 + wave2),
					Vector2(x0 + 8, y0 + 9 + wave2), Vector2(x0, y0 + 9 + wave)])
			draw_colored_polygon(quad, Color("#2b2b38") if (i + j) % 2 else Color.WHITE)
