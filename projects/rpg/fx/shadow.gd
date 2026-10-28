## 角色脚下的椭圆阴影。
extends Node2D

@export var radius := Vector2(6, 2.5)
@export var color := Color(0.08, 0.12, 0.1, 0.35)


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, radius.y / radius.x))
	draw_circle(Vector2.ZERO, radius.x, color)
