## 波次调度：按 StageData 里的顺序，一波一波地生成敌人。
## 没有用 await + create_timer，而是自己记一个时钟：场景被切走时不会留下"悬空"的协程，
## 暂停时（_physics_process 不跑）时钟自然也停了。
class_name WaveDirector
extends Node

signal wave_started(index: int, wave: WaveData)
signal stage_cleared

const ENEMY_SCENE := preload("res://game/enemy.tscn")

#region params
@export var stage: StageData
@export var spawn_interval := 0.35     ## 同一队里相邻两架敌人的出发间隔（秒）
@export var enemy_speed := 150.0       ## 敌人沿路径飞行的速度（像素/秒）
@export var hp_mult := 1.0             ## 敌人血量倍数
@export var bullet_density := 1.0      ## 弹幕密度：每次发射的子弹数量倍数
@export var bullet_speed := 1.0        ## 敌弹速度倍数
#endregion

var game: Game
var wave_index := -1
var running := false
var _clock := 0.0
var _next_wave_at := 1.5
var _pending: Array = []               # [出发时间, WaveData, Path2D]，按时间排好序


func start(g: Game, skip_to_end := false) -> void:
	game = g
	running = not skip_to_end
	wave_index = stage.waves.size() - 1 if skip_to_end else -1


#region schedule
func _physics_process(delta: float) -> void:
	_clock += delta
	while not _pending.is_empty() and _pending[0][0] <= _clock:
		var item: Array = _pending.pop_front()
		_spawn(item[1], item[2])
	if not running:
		return
	if _pending.is_empty() and _clock >= _next_wave_at:
		if wave_index + 1 < stage.waves.size():
			_start_wave(wave_index + 1)
		elif game.enemy_count() == 0:          # 最后一波打完（或飞走）了，交给 Boss
			running = false
			stage_cleared.emit()


func _start_wave(i: int) -> void:
	wave_index = i
	var w: WaveData = stage.waves[i]
	wave_started.emit(i, w)
	_next_wave_at = _schedule(w) + w.wait_after


## 把一波敌人排进待出发队列，返回最后一架的出发时间。Boss 召唤护卫也用它。
func _schedule(w: WaveData) -> float:
	var paths: Array[Path2D] = [game.get_path2d(w.path_name)]
	if w.mirror:
		paths.append(game.get_path2d(StringName(str(w.path_name) + "_M")))
	var t := _clock
	for k in w.count:
		for p in paths:
			_pending.append([t, w, p])
		t += w.gap * spawn_interval
	_pending.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	return t


func spawn_escort() -> void:
	var w := WaveData.new()
	w.kind = WaveData.Kind.DRONE
	w.path_name = &"SwoopLeft"
	w.mirror = true
	w.count = 3
	w.hp = 3
	w.drop_chance = 0.2
	_schedule(w)
#endregion


#region spawn
func _spawn(w: WaveData, path: Path2D) -> void:
	var follow := PathFollow2D.new()
	follow.loop = false
	follow.rotates = false           # 敌人始终"脸朝下"，不跟着曲线转
	var e: Enemy = ENEMY_SCENE.instantiate()
	e.setup(w, game, follow, enemy_speed, hp_mult)
	follow.add_child(e)
	path.add_child(follow)
#endregion
