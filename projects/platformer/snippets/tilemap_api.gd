## 第 8 章：TileMapLayer 常用 API，以及和旧 TileMap 写法的对照。不在游戏里运行，只用来展示（能通过编译检查）。
extends Node2D

@onready var ground: TileMapLayer = $Ground

#region layer_api
func api_example() -> void:
	var cell := ground.local_to_map(ground.get_local_mouse_position())  # 本地坐标 → 格子坐标
	ground.set_cell(cell, 0, Vector2i(1, 0))      # 放一块：图集源 0 里 (1, 0) 那块瓦片
	var center := ground.map_to_local(cell)       # 格子坐标 → 这一格中心的本地坐标
	var data := ground.get_cell_tile_data(cell)   # 空格子返回 null，用之前要判断
	if data:
		print(data.get_custom_data("hazard"))
	print(ground.get_cell_source_id(cell))        # 空格子返回 -1
	print(ground.get_used_rect(), center)         # 用到的格子范围（以格子为单位）
	ground.erase_cell(cell)                       # 清除一格
#endregion


#region migrate
## 旧写法（Godot 4.0–4.2 的 TileMap 节点，已废弃）都多一个"图层编号"参数：
##     tile_map.set_cell(0, cell, 0, Vector2i(1, 0))
##     tile_map.get_cell_tile_data(0, cell)
##     tile_map.set_cells_terrain_connect(0, cells, 0, 0)
## Godot 3 的写法：tile_map.set_cell(x, y, tile_id)、tile_map.world_to_map(pos)
## 换成 TileMapLayer 后，每个图层就是一个独立节点，去掉第一个参数即可：
func migrated(cells: Array[Vector2i]) -> void:
	ground.set_cells_terrain_connect(cells, 0, 0)
#endregion
