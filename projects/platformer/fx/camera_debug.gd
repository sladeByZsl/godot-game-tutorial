## 调试叠加层：把相机的死区（drag margin）和前瞻目标画在屏幕上。
## 放在 CanvasLayer 里，所以这里的坐标就是屏幕坐标。
extends Control

const COL_ZONE := Color(1.0, 0.85, 0.2, 0.9)
const COL_TARGET := Color(1.0, 0.35, 0.35, 0.95)
const COL_PLAYER := Color(0.3, 0.85, 1.0, 0.95)


func _process(_delta: float) -> void:
	var cam := Fx.camera
	visible = cam != null and cam.show_debug
	if visible:
		queue_redraw()


func _draw() -> void:
	var cam := Fx.camera
	var size_px := get_viewport_rect().size
	var center := size_px / 2.0
	var half := size_px / 2.0
	var font := get_theme_default_font()
	# 死区：画面中心周围的矩形。目标点在框里移动时，画面不动
	var zone := Rect2(
		center - half * Vector2(cam.drag_left_margin if cam.drag_horizontal_enabled else 0.0,
				cam.drag_top_margin if cam.drag_vertical_enabled else 0.0),
		Vector2.ZERO)
	zone.end = center + half * Vector2(cam.drag_right_margin if cam.drag_horizontal_enabled else 0.0,
			cam.drag_bottom_margin if cam.drag_vertical_enabled else 0.0)
	draw_rect(zone, Color(COL_ZONE, 0.12))
	draw_rect(zone, COL_ZONE, false, 2.0)
	_label(font, zone.position + Vector2(4, -6), "死区 drag margin", COL_ZONE)
	draw_line(center + Vector2(-8, 0), center + Vector2(8, 0), Color(1, 1, 1, 0.7), 1.5)
	draw_line(center + Vector2(0, -8), center + Vector2(0, 8), Color(1, 1, 1, 0.7), 1.5)
	# 世界坐标 → 屏幕坐标：乘上视口的画布变换
	var xf := get_viewport().get_canvas_transform()
	var p := xf * (cam.player.global_position + Vector2(0, -14))
	var t := xf * cam.global_position
	draw_circle(p, 5.0, COL_PLAYER)
	draw_line(p, t, COL_TARGET, 2.0, true)
	draw_circle(t, 6.0, COL_TARGET, false, 2.0, true)
	_label(font, t + Vector2(10, -10), "相机目标（含前瞻）", COL_TARGET)


func _label(font: Font, pos: Vector2, text: String, col: Color) -> void:
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 5, Color(0.08, 0.08, 0.15, 0.85))
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, col)
