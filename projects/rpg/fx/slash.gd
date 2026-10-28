## 挥剑时的白色弧光，0.18 秒内淡出。画在剑枢轴的局部坐标里（剑尖朝 -Y）。
extends Node2D

const LIFE := 0.18
var _t := LIFE


func play() -> void:
	_t = 0.0
	queue_redraw()


func _process(delta: float) -> void:
	if _t < LIFE:
		_t += delta
		queue_redraw()


func _draw() -> void:
	if _t >= LIFE:
		return
	var k := _t / LIFE
	var sweep := lerpf(-1.2, 1.2, minf(k * 1.6, 1.0))
	var a := 1.0 - k
	draw_arc(Vector2.ZERO, 15.0, -PI / 2 - 1.2, -PI / 2 + sweep, 16, Color(1, 1, 1, 0.85 * a), 3.0)
	draw_arc(Vector2.ZERO, 11.0, -PI / 2 - 1.0, -PI / 2 + sweep, 12, Color(0.75, 0.9, 1, 0.5 * a), 2.0)
