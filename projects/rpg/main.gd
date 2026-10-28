## 主场景：把地图、镜头、界面接起来，处理网页上的按钮（重新开始 / 存档 / 读档 / 生成敌人）。
extends Node2D

const SLIME := preload("res://enemies/slime.tscn")
const BAT := preload("res://enemies/bat.tscn")
const PUFF := preload("res://fx/puff.tscn")

var _spawned := 0

@onready var world: Node2D = $World
@onready var player: Player = $World/Player
@onready var camera: Camera2D = $Camera
@onready var hud: CanvasLayer = $HUD
@onready var overlay: Control = $Debug/Overlay


func _ready() -> void:
	camera.target = player
	camera.snap()
	hud.player = player
	overlay.world = world
	Tuning.action_triggered.connect(_on_action)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("save_game"):
		_on_action("save")
	elif event.is_action_pressed("load_game"):
		_on_action("load")


#region actions
func _on_action(action: String) -> void:
	match action:
		"restart":
			Game.reset()                        # autoload 里的状态不会随场景重载清空
			get_tree().paused = false
			get_tree().reload_current_scene()
		"save":
			if Game.save_game(player.global_position, _enemies_to_save()):
				Game.toast.emit("已存档（user://save.json）")
		"load":
			var p := Game.load_game()
			if p.is_empty():
				Game.toast.emit("还没有存档")
				return
			_restore_enemies(p["enemies"])
			player.teleport(Vector2(p["x"], p["y"]))
			camera.snap()
			Game.toast.emit("读档完成")
		"spawn_enemy":
			_spawn_enemy()
#endregion


#region save_enemies
func _enemies_to_save() -> Array:
	var out := []
	for e: Enemy in get_tree().get_nodes_in_group("enemies"):
		if e.hp > 0:                       # 正在播死亡动画的不存
			out.append({"kind": str(e.kind), "x": e.global_position.x, "y": e.global_position.y, "hp": e.hp})
	return out


func _restore_enemies(list: Array) -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		e.remove_from_group("enemies")     # 先移出分组：queue_free 要到帧末才真正删除
		e.queue_free()
	for d: Dictionary in list:
		var enemy: Enemy = (BAT if d["kind"] == "bat" else SLIME).instantiate()
		enemy.position = Vector2(d["x"], d["y"])
		world.add_child(enemy)
		enemy.hp = int(d["hp"])
#endregion


func _spawn_enemy() -> void:
	var scene := SLIME if _spawned % 2 == 0 else BAT
	for i in 30:
		var pos := player.global_position + Vector2.from_angle(randf() * TAU) * randf_range(48.0, 90.0)
		if world.is_free(pos):
			var enemy := scene.instantiate()
			enemy.position = pos
			world.add_child(enemy)
			var puff := PUFF.instantiate()
			puff.position = pos + Vector2(0, -6)
			world.add_child(puff)
			_spawned += 1
			return
	Game.toast.emit("附近没有空地")


func _process(_delta: float) -> void:
	var enemies := get_tree().get_nodes_in_group("enemies")
	var nearest: Enemy = null
	for e: Enemy in enemies:
		if nearest == null or e.global_position.distance_to(player.global_position) < nearest.global_position.distance_to(player.global_position):
			nearest = e
	Tuning.stat("血量", "%d / %d" % [Game.hp, Game.max_hp])
	Tuning.stat("敌人数", enemies.size())
	Tuning.stat("最近敌人状态", nearest.state_name() if nearest else "-")
	Tuning.stat("金币", Game.coins)
	Tuning.stat("有存档", Game.has_save())
