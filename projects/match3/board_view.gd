## 棋盘的"画面"：负责网格坐标和像素坐标的换算，并画出棋盘底板。
## 原点在棋盘左上角，宝石、选中框、特效都是它的子节点，共用这一套坐标。
class_name BoardView
extends Node2D

var cols := 8
var rows := 8
var cell_size := 56.0

@onready var gem_layer: Control = $GemLayer


func configure(w: int, h: int, size_px: float) -> void:
	cols = w
	rows = h
	cell_size = size_px
	# GemLayer 打开了 clip_contents：从棋盘上方掉进来的新宝石，在进入棋盘之前是看不见的
	gem_layer.size = Vector2(w, h) * size_px
	queue_redraw()


#region coords
## 格子 → 像素：格子中心点。
func cell_to_pixel(c: Vector2i) -> Vector2:
	return (Vector2(c) + Vector2(0.5, 0.5)) * cell_size


## 像素 → 格子：除以格子大小再向下取整。负数也要向下取整，所以用 floori 而不是 int()。
func pixel_to_cell(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / cell_size), floori(p.y / cell_size))
#endregion


func _draw() -> void:
	var size_px := Vector2(cols, rows) * cell_size
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.09, 0.1, 0.19, 0.92)
	panel.set_corner_radius_all(int(cell_size * 0.32))
	panel.shadow_color = Color(0, 0, 0, 0.45)
	panel.shadow_size = 18
	panel.shadow_offset = Vector2(0, 6)
	panel.border_color = Color(1, 1, 1, 0.08)
	panel.set_border_width_all(2)
	panel.anti_aliasing = true
	draw_style_box(panel, Rect2(Vector2.ZERO, size_px).grow(cell_size * 0.16))
	# 棋盘格：相邻格子明暗交替，读者更容易数格子
	for y in rows:
		for x in cols:
			var r := Rect2(Vector2(x, y) * cell_size, Vector2.ONE * cell_size).grow(-1.5)
			var light := (x + y) % 2 == 0
			draw_rect(r, Color(1, 1, 1, 0.065 if light else 0.03))
