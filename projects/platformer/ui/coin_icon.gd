## HUD 上的金币图标（代码绘制）。
extends Control


func _draw() -> void:
	var c := size / 2.0
	draw_circle(c, 11.0, Color("#b8741a"), true, -1.0, true)
	draw_circle(c, 9.5, Color("#ffc93c"), true, -1.0, true)
	draw_circle(c, 6.0, Color("#ffe48a"), true, -1.0, true)
	draw_rect(Rect2(c + Vector2(-1.3, -4.5), Vector2(2.6, 9)), Color("#b8741a"))
