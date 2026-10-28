## 教学用可视化：碰撞形状、敌人感知范围、状态机当前状态。
## 画在屏幕空间（CanvasLayer 里），文字不会被镜头放大而发虚。
extends Control

const COL_BODY := Color(0.35, 0.65, 1.0)
const COL_WORLD := Color(0.55, 0.6, 0.75)
const COL_WATER := Color(0.3, 0.85, 1.0)
const COL_HURT := Color(0.4, 1.0, 0.5)
const COL_HIT := Color(1.0, 0.3, 0.3)
const COL_ZONE := Color(1.0, 0.85, 0.3)

var world: Node2D
var _tile_polys: Array = []    # [[PackedVector2Array(世界坐标), Color], ...]


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if world == null:
		return
	var xf := get_viewport().get_canvas_transform()
	var font := get_theme_default_font()
	if Game.show_boxes:
		_draw_tiles(xf)
		for shape: CollisionShape2D in world.find_children("*", "CollisionShape2D", true, false):
			_draw_shape(xf, shape)
	for e: Enemy in get_tree().get_nodes_in_group("enemies"):
		var p := xf * e.global_position
		var s := xf.get_scale().x
		if Game.show_ranges and e.state != Enemy.State.DEAD:
			var chasing := e.state == Enemy.State.CHASE or e.state == Enemy.State.ATTACK
			if chasing:   # 追击中：只看丢失半径（红色虚线），跑出去就会放弃
				_dashed_circle(p, e.lose_radius * s, Color(1, 0.45, 0.4, 0.9))
			else:         # 没发现玩家：只看感知半径（黄色实线），走进来就会被发现
				draw_circle(p, e.sense_radius * s, Color(1, 0.85, 0.3, 0.08))
				draw_arc(p, e.sense_radius * s, 0, TAU, 64, Color(1, 0.85, 0.3, 0.9), 2.0)
		if Game.show_states:
			_tag(font, p + Vector2(0, -78), e.state_name(), _state_color(e.state_name()))
	if Game.show_states:
		var player := get_tree().get_first_node_in_group("player") as Player
		if player and player.machine.state:
			_tag(font, xf * player.global_position + Vector2(0, -72), String(player.machine.state.name), Color(0.6, 0.85, 1))


func _draw_shape(xf: Transform2D, cs: CollisionShape2D) -> void:
	var owner_node := cs.get_parent()
	var col := COL_BODY
	if owner_node is Hitbox:
		col = COL_HIT if (owner_node as Hitbox).active else Color(COL_HIT, 0.25)
	elif owner_node is Hurtbox:
		col = COL_HURT
	elif owner_node is Area2D:
		col = COL_ZONE
	elif owner_node is StaticBody2D:
		col = COL_WORLD
	var t := xf * cs.global_transform
	if cs.shape is RectangleShape2D:
		var h: Vector2 = cs.shape.size / 2.0
		var pts := PackedVector2Array([t * Vector2(-h.x, -h.y), t * Vector2(h.x, -h.y), t * Vector2(h.x, h.y), t * Vector2(-h.x, h.y)])
		draw_colored_polygon(pts, Color(col, 0.18))
		pts.append(pts[0])
		draw_polyline(pts, col, 1.5)
	elif cs.shape is CircleShape2D:
		var r: float = cs.shape.radius * t.get_scale().x
		draw_circle(t.origin, r, Color(col, 0.12))
		draw_arc(t.origin, r, 0, TAU, 32, col, 1.5)


func _draw_tiles(xf: Transform2D) -> void:
	if _tile_polys.is_empty():
		for layer_name in ["Ground", "Obstacles"]:
			var layer := world.get_node(layer_name) as TileMapLayer
			for cell in layer.get_used_cells():
				var data := layer.get_cell_tile_data(cell)
				for phys in 2:
					for i in data.get_collision_polygons_count(phys):
						var pts := PackedVector2Array()
						for v in data.get_collision_polygon_points(phys, i):
							pts.append(layer.to_global(layer.map_to_local(cell) + v))
						_tile_polys.append([pts, COL_WORLD if phys == 0 else COL_WATER])
	for item in _tile_polys:
		var pts: PackedVector2Array = xf * (item[0] as PackedVector2Array)
		draw_colored_polygon(pts, Color(item[1], 0.15))
		pts.append(pts[0])
		draw_polyline(pts, item[1], 1.0)


func _dashed_circle(c: Vector2, r: float, col: Color) -> void:
	var n := 48
	for i in range(0, n, 2):
		draw_arc(c, r, TAU * i / n, TAU * (i + 1) / n, 4, col, 2.0)


func _tag(font: Font, p: Vector2, text: String, col: Color) -> void:
	var size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15)
	var rect := Rect2(p - Vector2(size.x / 2 + 5, 15), Vector2(size.x + 10, 20))
	draw_rect(rect, Color(0.08, 0.07, 0.12, 0.85))
	draw_rect(rect, col, false, 1.0)
	draw_string(font, Vector2(rect.position.x + 5, p.y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, col)


func _state_color(s: String) -> Color:
	match s:
		"CHASE": return Color(1, 0.6, 0.3)
		"ATTACK": return Color(1, 0.35, 0.35)
		"HURT": return Color(1, 1, 1)
		"WANDER": return Color(0.6, 0.9, 0.6)
	return Color(0.75, 0.75, 0.85)
