## 关卡：用字符画描述地形，运行时（以及在编辑器里，因为是 @tool）生成到几个 TileMapLayer 上。
## 改关卡只要改下面的 MAP。每个字符是一格（32x32 像素）：
##   #  地面（地形自动连接）       =  单向木平台（地形自动连接）
##   B  背景层的远景土块（无碰撞） ^  尖刺（自定义数据 hazard = true）
##   o  金币   E  史莱姆   K  检查点   G  终点旗   P  起点   s  路牌
##   M  水平移动平台   V  竖直移动平台
@tool
class_name Level
extends Node2D

const TILE := 32
const SOURCE := 0                     # TileSet 里图集源的编号
const TERRAIN_SET := 0
const T_GROUND := 0                   # 地形编号：地面
const T_WOOD := 1                     # 地形编号：木平台
const SPIKE := Vector2i(4, 4)         # 尖刺在图集里的坐标
const DECOR_GRASS: Array[Vector2i] = [Vector2i(0, 5), Vector2i(1, 5)]
const DECOR_RARE: Array[Vector2i] = [Vector2i(2, 5), Vector2i(3, 5), Vector2i(4, 5), Vector2i(5, 5), Vector2i(6, 5)]
const SIGN := Vector2i(7, 5)

const COIN := preload("res://world/coin.tscn")
const SLIME := preload("res://world/slime.tscn")
const CHECKPOINT := preload("res://world/checkpoint.tscn")
const GOAL := preload("res://world/goal.tscn")
const PLATFORM := preload("res://world/moving_platform.tscn")

#region map
const MAP: Array[String] = [
	"....................................................................................................................................................##",
	"....................................................................................................................................................##",
	"....................................................................................................................................................##",
	"....................................................................................................................................................##",
	"....................................................................................................................................................##",
	"....................................................................................................................................................##",
	"##........................................................................................................................................BBBBB.....##",
	"##........................................................................................................................................BBBBB.....##",
	"##.......................................................................o..........E...^.................................................BBBBB.....##",
	"##......................................................................===....############...oo.......................................oo.BBBBB.G...##",
	"##...BBB.....................oo................................................############..====......K......BBB...................##################",
	"##...BBB....................====.............................................o.############.........#########.BBB...................##################",
	"##..BBBBB..................................BBB..............................===############.........#########BBBBB..............o...##################",
	"##..BBBBB...............oo......BBB........BBB...............o.o.o.o...........############.........#########BBBBB..................##################",
	"##..BBBBB.oo......o....====.....BBB...o....BBB....E......................o.....############.........#########BBBBB.......oo.....o...##################",
	"##..BBBBBo.......o.o............BBB..===...BBB#######...................===....############.........#########BBBBB...oo.............##################",
	"##..BBBBB...#####...............BBB........BBB#######.......M..................############.........#########BBBBB..................##################",
	"##P.BBBBB.s.#####...........E...BBB........BBB#######..K.......................############.........#########BBBBB.E...E.^^....V....##################",
	"#################...###############.......#################...........#####################.........##################################################",
	"#################...###############^^^^^^^#################...........#####################.........##################################################",
	"#################...#######################################...........#####################^^^^^^^^^##################################################",
	"#################...#######################################...........################################################################################",
]
#endregion

@export var show_collision := false:   ## 显示碰撞形状和危险格子（调试用）
	set(v):
		show_collision = v
		if is_node_ready():
			$CollisionDebug.visible = v
			$CollisionDebug.queue_redraw()

var player_start := Vector2.ZERO
var coin_total := 0

@onready var back: TileMapLayer = $Back
@onready var ground: TileMapLayer = $Ground
@onready var decor: TileMapLayer = $Decor
@onready var entities: Node2D = $Entities


func _ready() -> void:
	build()
	if not Engine.is_editor_hint():
		Tuning.bind(self, "level", ["show_collision"])
		show_collision = show_collision


#region build
func build() -> void:
	for layer: TileMapLayer in [back, ground, decor]:
		layer.clear()
	var dirt: Array[Vector2i] = []
	var wood: Array[Vector2i] = []
	var far: Array[Vector2i] = []
	var spikes: Array[Vector2i] = []
	for y in MAP.size():
		for x in MAP[y].length():
			var cell := Vector2i(x, y)
			match MAP[y][x]:
				"#": dirt.append(cell)
				"=": wood.append(cell)
				"B": far.append(cell)
				"^": spikes.append(cell)
				"s": decor.set_cell(cell, SOURCE, SIGN)
				".": pass
				var ch: _spawn(ch, cell)
	# 地形自动连接：只告诉它"这些格子是地面"，用哪块瓦片由 TileSet 里的地形位决定
	ground.set_cells_terrain_connect(dirt, TERRAIN_SET, T_GROUND, false)
	ground.set_cells_terrain_connect(wood, TERRAIN_SET, T_WOOD, false)
	back.set_cells_terrain_connect(far, TERRAIN_SET, T_GROUND, false)
	for cell in spikes:
		ground.set_cell(cell, SOURCE, SPIKE)
	_decorate(dirt)
#endregion


## 在露出草皮的地面上随机撒草丛和花（固定随机种子，每次生成都一样）。
func _decorate(dirt: Array[Vector2i]) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for cell in dirt:
		var above := cell + Vector2i.UP
		if above.y < 0 or MAP[above.y][above.x] != ".":
			continue
		var r := rng.randf()
		if r < 0.3:
			decor.set_cell(above, SOURCE, DECOR_GRASS[rng.randi() % DECOR_GRASS.size()])
		elif r < 0.45:
			decor.set_cell(above, SOURCE, DECOR_RARE[rng.randi() % DECOR_RARE.size()])


#region spawn
func _spawn(ch: String, cell: Vector2i) -> void:
	var center := ground.map_to_local(cell)        # 格子中心（TileMapLayer 的本地坐标）
	var feet := center + Vector2(0, TILE / 2.0)    # 格子底边：角色和旗子的"脚"踩在这里
	if ch == "P":
		player_start = ground.to_global(feet)
		return
	if Engine.is_editor_hint():
		return                                      # 编辑器里只显示瓦片，不生成会动的东西
	var node: Node2D
	match ch:
		"o":
			node = COIN.instantiate()
			node.position = center
			coin_total += 1
		"E":
			node = SLIME.instantiate()
			node.position = feet
			node.level = self
		"K":
			node = CHECKPOINT.instantiate()
			node.position = feet
		"G":
			node = GOAL.instantiate()
			node.position = feet
		"M", "V":
			node = PLATFORM.instantiate()
			node.position = center - Vector2(TILE, TILE) / 2.0
			node.travel = Vector2(5 * TILE, 0) if ch == "M" else Vector2(0, -7 * TILE)
		_:
			push_warning("关卡里有不认识的字符：%s" % ch)
			return
	entities.add_child(node)
#endregion


func get_bounds() -> Rect2:
	return Rect2(Vector2.ZERO, Vector2(MAP[0].length(), MAP.size()) * TILE)


#region query
## 世界坐标 → 地面层的格子 → 这一格的 TileData（空格子返回 null）。
func tile_data_at(world_pos: Vector2) -> TileData:
	var cell := ground.local_to_map(ground.to_local(world_pos))
	return ground.get_cell_tile_data(cell)


func is_hazard(world_pos: Vector2) -> bool:
	var data := tile_data_at(world_pos)
	return data != null and data.get_custom_data("hazard")


func is_solid(world_pos: Vector2) -> bool:
	var data := tile_data_at(world_pos)
	return data != null and data.get_collision_polygons_count(0) > 0
#endregion


func dust_color_at(world_pos: Vector2) -> Color:
	var data := tile_data_at(world_pos)
	if data == null:
		return Color(1, 1, 1, 0.8)
	return data.get_custom_data("dust_color")


#region paint
## 在游戏里用鼠标改地形：左键放地面，右键清除。邻居格子的瓦片会自动重新匹配。
func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed:
		return
	var cell := ground.local_to_map(ground.get_local_mouse_position())
	if mb.button_index == MOUSE_BUTTON_LEFT and ground.get_cell_source_id(cell) == -1:
		ground.set_cells_terrain_connect([cell], TERRAIN_SET, T_GROUND, false)
		decor.erase_cell(cell)
	elif mb.button_index == MOUSE_BUTTON_RIGHT:
		ground.set_cells_terrain_connect([cell], TERRAIN_SET, -1, false)
		ground.erase_cell(cell)
		decor.erase_cell(cell + Vector2i.UP)
	else:
		return
	$CollisionDebug.queue_redraw()
	Tuning.stat("点击的格子", cell)
#endregion
