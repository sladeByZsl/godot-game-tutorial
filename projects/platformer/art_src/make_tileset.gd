## 用代码生成 level/tileset.tres（和在编辑器 TileSet 面板里手动配置的结果完全一样）。
## 用法（在工程根目录）：Godot --headless --path . -s res://art_src/make_tileset.gd
## 平时不需要运行它：tileset.tres 已经生成好了。改了 tiles.png 的布局时再跑一次。
extends SceneTree

const TILE := 32
const GROUND := 0     # 地形编号（都在地形集 0 里）
const WOOD := 1


func _initialize() -> void:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE, TILE)

	# 物理层 0：碰撞层 1（"world"）
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, 1)
	ts.set_physics_layer_collision_mask(0, 0)

	# 地形集 0：只匹配四条边（16 种组合）
	ts.add_terrain_set()
	ts.set_terrain_set_mode(0, TileSet.TERRAIN_MODE_MATCH_SIDES)
	ts.add_terrain(0)
	ts.set_terrain_name(0, GROUND, "地面")
	ts.set_terrain_color(0, GROUND, Color("#6cc04a"))
	ts.add_terrain(0)
	ts.set_terrain_name(0, WOOD, "木平台")
	ts.set_terrain_color(0, WOOD, Color("#c98c52"))

	# 自定义数据层
	ts.add_custom_data_layer()
	ts.set_custom_data_layer_name(0, "hazard")
	ts.set_custom_data_layer_type(0, TYPE_BOOL)
	ts.add_custom_data_layer()
	ts.set_custom_data_layer_name(1, "dust_color")
	ts.set_custom_data_layer_type(1, TYPE_COLOR)

	var src := TileSetAtlasSource.new()
	src.texture = load("res://art/tiles.png")
	src.texture_region_size = Vector2i(TILE, TILE)
	ts.add_source(src, 0)

	var h := TILE / 2.0
	var full := PackedVector2Array([Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h)])
	var plank := PackedVector2Array([Vector2(-h, -h), Vector2(h, -h), Vector2(h, -h + 10), Vector2(-h, -h + 10)])

	# 地面：序号 m 的四个二进制位 = 上、右、下、左是否与地面相连
	for m in 16:
		var coords := Vector2i(m % 4, m / 4)
		src.create_tile(coords)
		var td := src.get_tile_data(coords, 0)
		td.terrain_set = 0
		td.terrain = GROUND
		var sides := [TileSet.CELL_NEIGHBOR_TOP_SIDE, TileSet.CELL_NEIGHBOR_RIGHT_SIDE,
				TileSet.CELL_NEIGHBOR_BOTTOM_SIDE, TileSet.CELL_NEIGHBOR_LEFT_SIDE]
		for i in 4:
			td.set_terrain_peering_bit(sides[i], GROUND if (m >> i) & 1 else -1)
		td.add_collision_polygon(0)
		td.set_collision_polygon_points(0, 0, full)
		td.set_custom_data("dust_color", Color("#d9e6b8"))

	# 单向木平台：单块 / 左端 / 中间 / 右端
	var wood_lr := [[false, false], [false, true], [true, true], [true, false]]
	for i in 4:
		var coords := Vector2i(i, 4)
		src.create_tile(coords)
		var td := src.get_tile_data(coords, 0)
		td.terrain_set = 0
		td.terrain = WOOD
		td.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_LEFT_SIDE, WOOD if wood_lr[i][0] else -1)
		td.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_RIGHT_SIDE, WOOD if wood_lr[i][1] else -1)
		td.add_collision_polygon(0)
		td.set_collision_polygon_points(0, 0, plank)
		td.set_collision_polygon_one_way(0, 0, true)
		td.set_custom_data("dust_color", Color("#f0cf9c"))

	# 尖刺：没有碰撞形状，只靠自定义数据 hazard 判断伤害
	src.create_tile(Vector2i(4, 4))
	src.get_tile_data(Vector2i(4, 4), 0).set_custom_data("hazard", true)

	# 装饰：纯显示
	for i in 8:
		src.create_tile(Vector2i(i, 5))

	var err := ResourceSaver.save(ts, "res://level/tileset.tres")
	print("tileset.tres 保存结果：", error_string(err))
	quit()
