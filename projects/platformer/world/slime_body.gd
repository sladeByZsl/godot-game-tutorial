## 史莱姆的外观：半个果冻 + 生气的眉毛。原点在底边中点，缩放时贴着地面变形。
extends Node2D

var facing := -1.0:
	set(v):
		if v != facing:
			facing = v
			queue_redraw()


func _draw() -> void:
	var outline := Color("#3b2560")
	var pts := PackedVector2Array()
	for i in 21:
		var a := PI + PI * i / 20.0
		pts.append(Vector2(cos(a) * 15.0, minf(sin(a) * 20.0, 0.0)))
	draw_colored_polygon(pts, Color("#9a6cf0"))
	var closed := pts.duplicate()
	closed.append(pts[0])
	draw_polyline(closed, outline, 2.0, true)
	draw_circle(Vector2(-6, -12), 3.0, Color(1, 1, 1, 0.45), true, -1.0, true)
	var f := facing * 2.0
	for x: float in [-5.0, 5.0]:
		draw_circle(Vector2(x + f, -8), 3.2, Color.WHITE, true, -1.0, true)
		draw_circle(Vector2(x + f * 1.4, -7.5), 1.7, outline, true, -1.0, true)
		draw_line(Vector2(x + f - 3.5 * signf(x) * -1.0, -13.5), Vector2(x + f + 3.0 * signf(x) * -1.0, -11.5), outline, 1.8, true)
