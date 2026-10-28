## 刷怪：场上始终保持 count 个敌人。死一个，3 秒后在离玩家较远的出生点补一个。
extends Node3D

signal enemy_killed

const ENEMY := preload("res://enemy/enemy.tscn")
## 候选出生点（大致位置），生成时用导航网格把它"吸附"到最近的可走位置上
const SPAWN_POINTS: Array[Vector3] = [
	Vector3(-18, 0, -18), Vector3(18, 0, -18), Vector3(-18, 0, 18), Vector3(18.5, 0, 18.5),
	Vector3(0, 0, -18), Vector3(0, 0, 18), Vector3(-18, 0, -2), Vector3(18, 0, 3),
]

@export var count := 5:
	set(v):
		count = v
		if _started:
			_sync()

var _started := false


func _ready() -> void:
	Tuning.bind(self, "spawner", ["count"])


func start() -> void:
	# 烘焙好的导航网格要等导航服务器下一次同步后才能查询（同步前查询只会得到原点），
	# 所以一直等到能在平台附近查到可走的点再开始刷怪
	var map := get_world_3d().navigation_map
	while NavigationServer3D.map_get_closest_point(map, Vector3(0, 5, 0)) == Vector3.ZERO:
		await get_tree().physics_frame
	_started = true
	_sync()


func is_started() -> bool:
	return _started


func alive() -> Array:
	return get_children().filter(func(e: Node) -> bool: return e is Enemy and e.state != Enemy.State.DEAD and not e.is_queued_for_deletion())


func _sync() -> void:
	var list := alive()
	while list.size() > count:
		list.pop_back().queue_free()
	for i in count - list.size():
		spawn_one()


func spawn_one(near_player := false) -> Enemy:
	var player: Node3D = get_tree().get_first_node_in_group("player")
	var points := SPAWN_POINTS.duplicate()
	points.shuffle()
	var pick: Vector3 = points[0]
	for p: Vector3 in points:
		var far := p.distance_to(player.global_position) > 14.0
		if far != near_player:
			pick = p
			break
	var map := get_world_3d().navigation_map
	var e: Enemy = ENEMY.instantiate()
	add_child(e)
	e.global_position = NavigationServer3D.map_get_closest_point(map, pick)
	e.rotation.y = randf() * TAU
	e.died.connect(_on_enemy_died)
	return e


func _on_enemy_died(_e: Enemy) -> void:
	enemy_killed.emit()
	get_tree().create_timer(3.0, false).timeout.connect(_sync)   # false：游戏暂停时计时器也暂停
