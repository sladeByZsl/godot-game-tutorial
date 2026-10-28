## 检查点：一根旗杆。玩家经过时升旗、换颜色，并把复活点设到这里。
extends Area2D

signal reached

var active := false
var flag_height := 0.25:      ## 旗子升到旗杆的哪个位置（0 底部 ~ 1 顶部），Tween 会改它
	set(v):
		flag_height = v
		queue_redraw()


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if active or not body is Player:
		return
	active = true
	body.set_checkpoint(global_position)
	Fx.sparkle(global_position + Vector2(0, -50), Color("#7ed957"), 16)
	var tw := create_tween()
	tw.tween_property(self, "flag_height", 1.0, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	reached.emit()


func _draw() -> void:
	var outline := Color("#3d2b22")
	draw_rect(Rect2(-9, -6, 18, 6), outline)
	draw_rect(Rect2(-7, -5, 14, 4), Color("#8a8fa3"))
	draw_rect(Rect2(-2.5, -62, 5, 58), outline)
	draw_rect(Rect2(-1.2, -61, 2.4, 56), Color("#d8dce8"))
	draw_circle(Vector2(0, -63), 3.5, Color("#ffc93c"), true, -1.0, true)
	var y := lerpf(-14.0, -58.0, flag_height)
	var col := Color("#5cc85c") if active else Color("#c9c4b8")
	var pts := PackedVector2Array([Vector2(2, y), Vector2(24, y + 7), Vector2(2, y + 14)])
	draw_colored_polygon(pts, col)
	pts.append(pts[0])
	draw_polyline(pts, outline, 1.5, true)
