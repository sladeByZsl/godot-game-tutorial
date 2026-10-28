## 把地面层每个格子的碰撞多边形画出来：实心为蓝色，单向平台为橙色，危险格子为红色。
## 演示怎样从 TileMapLayer 读出格子里的 TileData（碰撞形状、自定义数据）。
extends Node2D

@onready var ground: TileMapLayer = get_parent().get_node("Ground")


#region draw
func _draw() -> void:
	for cell in ground.get_used_cells():
		var data := ground.get_cell_tile_data(cell)
		var center := ground.map_to_local(cell)
		if data.get_custom_data("hazard"):
			draw_rect(Rect2(center - Vector2(16, 16), Vector2(32, 32)), Color(1, 0.2, 0.2, 0.35))
			draw_rect(Rect2(center - Vector2(16, 16), Vector2(32, 32)), Color(1, 0.2, 0.2), false, 2.0)
		for i in data.get_collision_polygons_count(0):
			var pts := data.get_collision_polygon_points(0, i)
			var one_way := data.is_collision_polygon_one_way(0, i)
			var col := Color(1.0, 0.6, 0.1) if one_way else Color(0.25, 0.6, 1.0)
			var poly := PackedVector2Array()
			for p in pts:
				poly.append(center + p)
			draw_colored_polygon(poly, Color(col, 0.25))
			poly.append(poly[0])
			draw_polyline(poly, col, 1.5)
#endregion
