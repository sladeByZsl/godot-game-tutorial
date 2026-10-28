## 星空的一层：在 size 大小的区域里随机画一些星星。
## 它放在 Parallax2D 下面；Parallax2D 负责自动滚动和无缝重复（repeat_size）。
@tool
extends Node2D

@export var size := Vector2(960, 540)
@export var count := 80
@export var radius := Vector2(0.6, 1.4)       ## 星星半径范围
@export var color := Color(0.7, 0.8, 1.0, 0.8)
@export var streak := 0.0                     ## > 0 时画成竖线（速度感）
@export var seed_value := 1


func _draw() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value                      # 固定种子：每次画出来的星星位置都一样
	for i in count:
		var p := Vector2(rng.randf() * size.x, rng.randf() * size.y)
		var r := rng.randf_range(radius.x, radius.y)
		var c := Color(color, color.a * rng.randf_range(0.4, 1.0))
		if streak > 0.0:
			draw_line(p, p + Vector2(0, streak * r), c, r)
		else:
			draw_circle(p, r, c)
