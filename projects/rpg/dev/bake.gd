## 开发用工具脚本：根据 art/*.png 和 dev/map.txt 生成
##   world/tileset.tres      瓦片集（图集 + 碰撞多边形 + Y 排序原点）
##   art/*_frames.tres       角色动画（SpriteFrames）
##   world/world.tscn        地图场景（三个 TileMapLayer + 摆好的角色、宝箱）
## 用法（先运行 python3 dev/make_art.py 并 --import 一次）：
##   Godot --headless --path projects/rpg -s res://dev/bake.gd
## 生成后的文件和手工在编辑器里做出来的完全一样，可以直接打开继续编辑。
extends SceneTree

const T := 16
const SRC := 0                     # 图集在 TileSet 里的 source id

# 图集坐标（见 dev/make_art.py 的 build_tiles）
const GRASS := [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)]
const FLOWER_RED := Vector2i(4, 0)
const FLOWER_YELLOW := Vector2i(5, 0)
const TUFT := Vector2i(6, 0)
const PEBBLES := Vector2i(7, 0)
const BRIDGE := Vector2i(0, 7)
const ROCK := Vector2i(1, 7)
const BUSH := Vector2i(2, 7)
const STUMP := Vector2i(3, 7)
const SIGN := Vector2i(4, 7)
const TREE := Vector2i(0, 8)
const PINE := Vector2i(1, 8)
const HOUSE := Vector2i(4, 8)

const PHYS_WORLD := 0              # TileSet 的物理层 0 → 碰撞层 1 "world"
const PHYS_WATER := 1              # TileSet 的物理层 1 → 碰撞层 2 "water"


func _initialize() -> void:
	_make_frames()
	var ts := _make_tileset()
	ResourceSaver.save(ts, "res://world/tileset.tres")
	_make_world(load("res://world/tileset.tres"))
	print("bake 完成")
	quit()



func _path(mask: int) -> Vector2i:
	return Vector2i(mask % 8, 1 + mask / 8)


func _water(mask: int) -> Vector2i:
	return Vector2i(mask % 8, 3 + mask / 8)


func _fence(mask: int) -> Vector2i:
	return Vector2i(mask % 8, 5 + mask / 8)


func _rect(x0: float, y0: float, x1: float, y1: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1)])


#region tileset
func _make_tileset() -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(T, T)
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(PHYS_WORLD, 1)     # 第 1 层 world
	ts.set_physics_layer_collision_mask(PHYS_WORLD, 0)
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(PHYS_WATER, 2)     # 第 2 层 water（蝙蝠不检测这一层）
	ts.set_physics_layer_collision_mask(PHYS_WATER, 0)

	var src := TileSetAtlasSource.new()
	src.texture = load("res://art/tiles.png")
	src.texture_region_size = Vector2i(T, T)
	ts.add_source(src, SRC)

	for c in GRASS + [FLOWER_RED, FLOWER_YELLOW, TUFT, PEBBLES, BRIDGE]:
		src.create_tile(c)
	for m in 16:
		src.create_tile(_path(m))
		src.create_tile(_water(m))
		_solid(src, _water(m), PHYS_WATER, _rect(-8, -8, 8, 8))
		src.create_tile(_fence(m))
		var fence: Array[PackedVector2Array] = [_rect(-3, -3, 3, 5)]
		if m & 8: fence.append(_rect(-8, -1, -3, 4))
		if m & 2: fence.append(_rect(3, -1, 8, 4))
		if m & 1: fence.append(_rect(-1, -8, 1, -3))
		if m & 4: fence.append(_rect(-1, 5, 1, 8))
		for poly in fence:
			_solid(src, _fence(m), PHYS_WORLD, poly)
		src.get_tile_data(_fence(m), 0).y_sort_origin = 4
	_obstacle(src, ROCK, Vector2i.ONE, Vector2i.ZERO, _rect(-5, -1, 5, 5), 4)
	_obstacle(src, BUSH, Vector2i.ONE, Vector2i.ZERO, _rect(-7, -3, 7, 5), 4)
	_obstacle(src, STUMP, Vector2i.ONE, Vector2i.ZERO, _rect(-5, -1, 4, 4), 3)
	_obstacle(src, SIGN, Vector2i.ONE, Vector2i.ZERO, _rect(-6, -3, 6, 3), 5)
	# 16×32 的树：图集里占 1×2 格，texture_origin 往上抬 8 像素，让树根落在格子里
	_obstacle(src, TREE, Vector2i(1, 2), Vector2i(0, 8), _rect(-3, 0, 3, 6), 5)
	_obstacle(src, PINE, Vector2i(1, 2), Vector2i(0, 8), _rect(-3, 0, 3, 6), 5)
	# 64×64 的房子：锚点是底边从左数第 2 格
	_obstacle(src, HOUSE, Vector2i(4, 4), Vector2i(-8, 24), _rect(-20, -22, 35, 6), 6)
	return ts


func _solid(src: TileSetAtlasSource, coords: Vector2i, layer: int, poly: PackedVector2Array) -> void:
	var data := src.get_tile_data(coords, 0)
	var i := data.get_collision_polygons_count(layer)
	data.add_collision_polygon(layer)
	data.set_collision_polygon_points(layer, i, poly)


func _obstacle(src: TileSetAtlasSource, coords: Vector2i, size: Vector2i, origin: Vector2i,
		poly: PackedVector2Array, y_sort: int) -> void:
	src.create_tile(coords, size)
	var data := src.get_tile_data(coords, 0)
	data.texture_origin = origin        # 图片相对格子中心的偏移
	data.y_sort_origin = y_sort         # 排序时用的"脚底"位置（相对格子中心）
	_solid(src, coords, PHYS_WORLD, poly)
#endregion


func _make_frames() -> void:
	var player := _new_frames()
	var tex: Texture2D = load("res://art/player.png")
	for dir: Array in [["down", 0], ["up", 1], ["side", 2]]:
		_add_anim(player, "idle_" + dir[0], tex, [Vector2i(0, dir[1])], 1.0, true)
		_add_anim(player, "walk_" + dir[0], tex, [Vector2i(0, dir[1]), Vector2i(1, dir[1]), Vector2i(2, dir[1]), Vector2i(3, dir[1])], 8.0, true)
		_add_anim(player, "attack_" + dir[0], tex, [Vector2i(4, dir[1])], 1.0, false)
	ResourceSaver.save(player, "res://art/player_frames.tres")
	var four := [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)]
	var slime := _new_frames()
	_add_anim(slime, "idle", load("res://art/slime.png"), four, 6.0, true)
	ResourceSaver.save(slime, "res://art/slime_frames.tres")
	var bat := _new_frames()
	_add_anim(bat, "fly", load("res://art/bat.png"), four, 10.0, true)
	ResourceSaver.save(bat, "res://art/bat_frames.tres")
	var npcs: Texture2D = load("res://art/npcs.png")
	for row: Array in [["chief", 0], ["villager", 1]]:
		var f := _new_frames()
		_add_anim(f, "idle", npcs, [Vector2i(0, row[1]), Vector2i(1, row[1])], 2.0, true)
		ResourceSaver.save(f, "res://art/%s_frames.tres" % row[0])


func _new_frames() -> SpriteFrames:
	var f := SpriteFrames.new()
	f.remove_animation(&"default")
	return f


func _add_anim(f: SpriteFrames, anim: StringName, tex: Texture2D, cells: Array, fps: float, loop: bool) -> void:
	f.add_animation(anim)
	f.set_animation_speed(anim, fps)
	f.set_animation_loop(anim, loop)
	for c: Vector2i in cells:
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(c.x * T, c.y * T, T, T)
		f.add_frame(anim, at)


#region paint
func _make_world(ts: TileSet) -> void:
	var rows := FileAccess.get_file_as_string("res://dev/map.txt").strip_edges().split("\n")
	var world := Node2D.new()
	world.name = "World"
	world.y_sort_enabled = true
	world.set_script(load("res://world/world.gd"))
	var ground := _layer(world, "Ground", ts)
	ground.z_index = -2                       # 地面永远在最下面
	var decor := _layer(world, "Decor", ts)
	decor.z_index = -1                        # 花草装饰压在地面上、角色下
	var obstacles := _layer(world, "Obstacles", ts)
	obstacles.y_sort_enabled = true           # 树、栅栏、房子和角色一起按 y 排序

	var h := rows.size()
	var w := rows[0].length()
	var at := func(x: int, y: int) -> String:
		if x < 0 or y < 0 or x >= w or y >= h:
			return ""
		return rows[y][x]
	var counts := {}
	for y in h:
		for x in w:
			var c := Vector2i(x, y)
			var ch: String = rows[y][x]
			var r := absi(hash(c)) % 100
			match ch:
				"=":
					ground.set_cell(c, SRC, _path(_mask(at, x, y, "=#", true)))
				"~":
					ground.set_cell(c, SRC, _water(_mask(at, x, y, "~#", true)))
				"#":
					ground.set_cell(c, SRC, BRIDGE)
				_:
					ground.set_cell(c, SRC, GRASS[0 if r < 45 else (1 if r < 80 else (2 if r < 93 else 3))])
			match ch:
				"T":
					obstacles.set_cell(c, SRC, PINE if (x >= 20 and y <= 10) == (r < 80) else TREE)
				"f":
					obstacles.set_cell(c, SRC, _fence(_mask(at, x, y, "f", false)))
				"r":
					obstacles.set_cell(c, SRC, ROCK)
				"b":
					obstacles.set_cell(c, SRC, BUSH)
				"t":
					obstacles.set_cell(c, SRC, STUMP)
				"s":
					obstacles.set_cell(c, SRC, SIGN)
				"H":
					obstacles.set_cell(c, SRC, HOUSE)
				"*":
					decor.set_cell(c, SRC, FLOWER_RED if r % 2 == 0 else FLOWER_YELLOW)
				"'":
					decor.set_cell(c, SRC, TUFT)
				".":
					if r < 4:
						decor.set_cell(c, SRC, PEBBLES)
					elif r < 9:
						decor.set_cell(c, SRC, TUFT)
				"P", "C", "V", "S", "B", "X":
					_spawn(world, ch, ground.map_to_local(c) + Vector2(0, 6), counts)
	var ps := PackedScene.new()
	ps.pack(world)
	ResourceSaver.save(ps, "res://world/world.tscn")
	world.free()


## 4 位掩码：上 1、右 2、下 4、左 8，邻居属于 kinds 时置位。出界当作同类。
func _mask(at: Callable, x: int, y: int, kinds: String, edge_same: bool) -> int:
	var m := 0
	for d: Array in [[0, -1, 1], [1, 0, 2], [0, 1, 4], [-1, 0, 8]]:
		var n: String = at.call(x + d[0], y + d[1])
		if (n == "" and edge_same) or (n != "" and kinds.contains(n)):
			m |= d[2]
	return m
#endregion


func _layer(world: Node2D, layer_name: String, ts: TileSet) -> TileMapLayer:
	var l := TileMapLayer.new()
	l.name = layer_name
	l.tile_set = ts
	world.add_child(l)
	l.owner = world
	return l


func _spawn(world: Node2D, ch: String, pos: Vector2, counts: Dictionary) -> void:
	var scenes := {"P": "res://player/player.tscn", "C": "res://npc/chief.tscn", "V": "res://npc/villager.tscn",
		"S": "res://enemies/slime.tscn", "B": "res://enemies/bat.tscn", "X": "res://items/chest.tscn"}
	var names := {"P": "Player", "C": "Chief", "V": "Villager", "S": "Slime", "B": "Bat", "X": "Chest"}
	counts[ch] = counts.get(ch, 0) + 1
	var node: Node2D = load(scenes[ch]).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	node.name = names[ch] if ch in "PCV" else "%s%d" % [names[ch], counts[ch]]
	node.position = pos
	if ch == "X":
		var loot: Array[ItemData] = []
		if counts[ch] == 1:       # 森林里的宝箱
			loot = [load("res://items/potion.tres"), load("res://items/key.tres")]
			node.coins = 10
		else:                     # 草地上的宝箱
			loot = [load("res://items/apple.tres"), load("res://items/apple.tres")]
			node.coins = 5
		node.contents = loot
	world.add_child(node)
	node.owner = world
