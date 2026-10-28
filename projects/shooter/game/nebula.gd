## 星云：几团加法混合的彩色光晕，放在最慢的一层视差里。
@tool
extends Node2D

const GLOW := preload("res://art/glow.png")

@export var size := Vector2(960, 540)


func _draw() -> void:
	var blobs := [
		[Vector2(0.2, 0.25), 520.0, Color(0.35, 0.08, 0.45, 0.35)],
		[Vector2(0.85, 0.6), 600.0, Color(0.05, 0.2, 0.45, 0.22)],
		[Vector2(0.4, 0.9), 420.0, Color(0.4, 0.05, 0.25, 0.25)],
	]
	for b: Array in blobs:
		var center: Vector2 = b[0] * size
		var d: float = b[1]
		draw_texture_rect(GLOW, Rect2(center - Vector2(d, d) / 2, Vector2(d, d)), false, b[2])
