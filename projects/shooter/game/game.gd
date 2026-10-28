## 一局游戏：把玩家、子弹池、波次、Boss、特效、HUD 串起来，并负责分数、生命、炸弹。
class_name Game
extends Node2D

const MAX_BOMBS := 5
const START_LIVES := 3
# 用 load() 而不是 preload()：boss.gd、pickup.gd 里也引用了 Game，preload 会形成循环依赖
const PICKUP_SCENE_PATH := "res://game/pickup.tscn"
const BOSS_SCENE_PATH := "res://game/boss.tscn"

#region params
@export var shake_strength := 6.0       ## 屏幕震动强度（像素）
@export var glow := true:               ## WorldEnvironment 的发光（glow）
	set(v):
		glow = v
		if is_node_ready():
			env.environment.glow_enabled = v
@export var show_hitboxes := false:     ## 显示碰撞形状
	set(v):
		show_hitboxes = v
		if is_node_ready():
			hitbox_overlay.visible = v
#endregion

var score := 0
var lives := START_LIVES
var bombs := 2
var kills := 0
var boss: Boss
var _trauma := 0.0
var _over := false
var _time := 0.0
var _stress_left := 0.0
# 性能统计
var _stat_timer := 0.0
var _ft_sum := 0.0
var _ft_n := 0
var _ft_max := 0.0
var _created_last := 0

@onready var field: Node2D = $Field
@onready var paths: Node2D = $Field/Paths
@onready var boss_slot: Node2D = $Field/BossSlot
@onready var pickups: Node2D = $Field/Pickups
@onready var player: Player = $Field/Player
@onready var player_bullets: BulletPool = $Field/PlayerBullets
@onready var enemy_bullets: BulletPool = $Field/EnemyBullets
@onready var fx: Fx = $Field/Fx
@onready var hitbox_overlay: Node2D = $Field/HitboxOverlay
@onready var director: WaveDirector = $Director
@onready var camera: Camera2D = $Camera
@onready var env: WorldEnvironment = $WorldEnvironment
@onready var hud: Hud = $Hud
@onready var result_screen: ResultScreen = $Result


func _ready() -> void:
	_mirror_paths()
	player.game = self
	player.hit.connect(_on_player_hit)
	player.bomb_requested.connect(bomb)
	hitbox_overlay.game = self
	#region bind
	# 同一个参数可以绑定到多个对象：两个子弹池共用 "pool.*"
	Tuning.bind(self, "fx", ["shake_strength", "glow", "show_hitboxes"])
	Tuning.bind(fx, "fx", ["particle_amount", "particle_mode"])
	Tuning.bind(player_bullets, "pool", ["use_pool", "pool_size"])
	Tuning.bind(enemy_bullets, "pool", ["use_pool", "pool_size"])
	Tuning.bind(director, "waves", ["spawn_interval", "enemy_speed", "hp_mult", "bullet_density", "bullet_speed"])
	Tuning.action_triggered.connect(_on_action)
	#endregion
	glow = glow
	show_hitboxes = show_hitboxes
	director.wave_started.connect(func(i: int, w: WaveData) -> void:
		hud.banner("第 %d 波" % (i + 1), w.label))
	director.stage_cleared.connect(start_boss)
	director.start(self, Flow.start_at_boss)
	if Flow.start_at_boss:
		start_boss()
	if Flow.autoplay:
		player.autopilot = true
		player.invincible = true
	Audio.play_music()
	_created_last = BulletPool.nodes_created


#region mirror
## 每条 Path2D 复制一份左右镜像的：scale.x = -1 再平移到右边，曲线数据本身不用改。
func _mirror_paths() -> void:
	for p: Path2D in paths.get_children():
		var m := Path2D.new()
		m.name = p.name + "_M"
		m.curve = p.curve
		m.scale = Vector2(-1, 1)
		m.position = Vector2(600.0 - p.position.x, p.position.y)
		paths.add_child(m)
#endregion


func get_path2d(path_name: StringName) -> Path2D:
	return paths.get_node(NodePath(path_name))


func field_pos(node: Node2D) -> Vector2:
	return field.to_local(node.global_position)


func enemy_count() -> int:
	return get_tree().get_node_count_in_group("enemies")


func _physics_process(delta: float) -> void:
	if _stress_left > 0.0:
		_stress_left -= delta
		if Engine.get_physics_frames() % 2 == 0:
			var origin := Vector2(randf_range(80, 520), randf_range(40, 160))
			Danmaku.ring(enemy_bullets, origin, 16, 260.0, randf() * TAU, Bullet.Kind.VIOLET)


func _process(delta: float) -> void:
	if not _over:
		_time += delta
	_update_shake(delta)
	_update_stats(delta)
	hud.set_status(score, maxi(score, Flow.best_score()), lives, bombs, player.power, player.shield)
	if is_instance_valid(boss):
		hud.set_boss_hp(boss.hp / boss.max_hp)


#region shake
## 屏幕震动用"创伤值"：每次受击加一点，随时间衰减；偏移量和创伤值的平方成正比，
## 小震动几乎察觉不到，大爆炸才明显。只动 Camera2D 的 offset，HUD 在 CanvasLayer 上不受影响。
func shake(amount: float) -> void:
	_trauma = minf(_trauma + amount / 24.0, 1.0)


func _update_shake(delta: float) -> void:
	_trauma = maxf(0.0, _trauma - delta * 1.8)
	var k := _trauma * _trauma * shake_strength * 2.0
	camera.offset = Vector2(randf_range(-k, k), randf_range(-k, k))
#endregion


#region stats
func _update_stats(delta: float) -> void:
	_ft_sum += delta
	_ft_n += 1
	_ft_max = maxf(_ft_max, delta)
	_stat_timer += delta
	if _stat_timer < 0.5:
		return
	var created := BulletPool.nodes_created - _created_last
	_created_last = BulletPool.nodes_created
	var per_sec := roundi(created / _stat_timer)
	var frame_ms := _ft_sum / _ft_n * 1000.0
	var worst_ms := _ft_max * 1000.0
	var live := player_bullets.active.size() + enemy_bullets.active.size()
	var idle := player_bullets.free_count() + enemy_bullets.free_count()
	Tuning.stat("对象池", "开" if player_bullets.use_pool else "关")
	Tuning.stat("活动子弹", live)
	Tuning.stat("池中空闲", idle)
	Tuning.stat("每秒新建节点", per_sec)
	Tuning.stat("节点总数", int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
	Tuning.stat("帧时间 ms", snappedf(frame_ms, 0.1))
	Tuning.stat("最差帧 ms", snappedf(worst_ms, 0.1))
	Tuning.stat("音效请求/秒", Audio.plays_this_second)
	Tuning.stat("分数", score)
	hud.set_perf(player_bullets.use_pool, live, idle, per_sec, frame_ms, worst_ms)
	_stat_timer = 0.0
	_ft_sum = 0.0
	_ft_n = 0
	_ft_max = 0.0
#endregion


func on_enemy_killed(e: Enemy, points: int, drop_chance: float) -> void:
	score += points
	kills += 1
	var pos := field_pos(e)
	var big := e.data.kind == WaveData.Kind.TURRET
	fx.explode(pos, Enemy.LOOK[e.data.kind]["color"], big)
	Audio.play_at("big_explosion" if big else "explosion", e.global_position, -3.0)
	shake(8.0 if big else 3.0)
	if randf() < drop_chance:
		var r := randf()
		spawn_pickup(pos, Pickup.Type.POWER if r < 0.6 else (Pickup.Type.SHIELD if r < 0.85 else Pickup.Type.BOMB))


func spawn_pickup(pos: Vector2, type: Pickup.Type) -> void:
	var p: Pickup = load(PICKUP_SCENE_PATH).instantiate()
	p.type = type
	p.game = self
	p.position = pos
	pickups.add_child.call_deferred(p)     # 可能在物理回调里被调用，新增 Area2D 也要延后


## 把所有敌弹变成分数（炸弹、Boss 换阶段、玩家中弹时）。
func cancel_enemy_bullets() -> void:
	var sparks := [0]
	var n := enemy_bullets.clear_all(func(p: Vector2) -> void:
		sparks[0] += 1
		if sparks[0] % 4 == 0:
			fx.spark(p))
	score += n * 10


#region bomb
func bomb(free := false) -> void:
	if _over or (bombs <= 0 and not free):
		return
	if not free:
		bombs -= 1
	cancel_enemy_bullets()
	for e: Enemy in get_tree().get_nodes_in_group("enemies"):
		e.take_hit(30, e.global_position)
	if is_instance_valid(boss):
		boss.take_hit(40, boss.global_position)
	player.set_invulnerable(2.0)
	fx.ring(player.position, Color(0.6, 2.4, 1.0), 520.0, 0.8)
	fx.ring(player.position, Color(2.0, 2.0, 2.0), 300.0, 0.5)
	hud.flash()
	shake(24.0)
	Audio.play("big_explosion")
#endregion


func _on_player_hit() -> void:
	lives -= 1
	fx.explode(player.position, Color(0.4, 1.8, 2.4), true)
	Audio.play("hurt")
	shake(18.0)
	player.power = maxi(0, player.power - 1)
	cancel_enemy_bullets()
	bombs = maxi(bombs, 2)
	if lives < 0:
		lives = 0
		player.hide()
		player.process_mode = Node.PROCESS_MODE_DISABLED
		_finish(false)


#region boss
func start_boss() -> void:
	hud.warning()
	get_tree().create_timer(2.5, false).timeout.connect(_spawn_boss)


func _spawn_boss() -> void:
	boss = load(BOSS_SCENE_PATH).instantiate()
	boss_slot.add_child(boss)
	boss.phase_changed.connect(func(_p: int, phase_name: String) -> void: hud.boss_phase(phase_name))
	boss.defeated.connect(func() -> void: _finish(true))
	boss.start(self, Flow.start_phase)
	hud.show_boss(true)
#endregion


func _finish(cleared: bool) -> void:
	if _over:
		return
	_over = true
	director.running = false
	hud.show_boss(false)
	var rank := Flow.finish_game(score, director.wave_index + 1)
	# 等爆炸放完再弹结算。连接到节点的方法上：如果这 1.6 秒里场景被切走，连接会随节点一起断开。
	get_tree().create_timer(1.6, false).timeout.connect(
		result_screen.open.bind(cleared, score, kills, _time, rank))


func _on_action(action: String) -> void:
	match action:
		"bomb":
			bomb(true)
		"stress":
			_stress_left = 3.0
			player.set_invulnerable(3.5)
