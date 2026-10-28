## 主场景：把关卡、主角、相机和界面连起来。
extends Node2D

var _time := 0.0
var _finished := false

@onready var level: Level = $Level
@onready var player: Player = $Player
@onready var camera: GameCamera = $Player/Camera
@onready var hud: Hud = $HUD


func _ready() -> void:
	player.level = level
	player.global_position = level.player_start
	player.set_checkpoint(level.player_start)
	camera.set_bounds(level.get_bounds())
	camera.reset_smoothing()
	hud.setup(level.coin_total)
	player.coin_collected.connect(hud.set_coins)
	player.died.connect(hud.set_deaths)
	for k in get_tree().get_nodes_in_group("checkpoints"):
		k.reached.connect(hud.toast.bind("检查点！"))
	for g in get_tree().get_nodes_in_group("goals"):
		g.reached.connect(_on_goal_reached)
	Tuning.action_triggered.connect(func(a: String) -> void:
		if a == "restart":
			restart())


func _process(delta: float) -> void:
	if not _finished:
		_time += delta
		hud.set_time(_time)
	var cell := level.ground.local_to_map(level.ground.to_local(player.global_position + Vector2(0, -14)))
	Tuning.stat("所在格子", "(%d, %d)" % [cell.x, cell.y])
	Tuning.stat("金币", "%d / %d" % [player.coins, level.coin_total])


func _on_goal_reached() -> void:
	_finished = true
	hud.show_win(player.coins, player.deaths, _time)
	await get_tree().create_timer(4.0).timeout
	restart()


func restart() -> void:
	Engine.time_scale = 1.0
	get_tree().reload_current_scene()
