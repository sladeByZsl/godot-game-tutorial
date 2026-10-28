## 武器管理：开火（射线检测）、散布、后坐力、弹药与换弹、切枪、武器摆动（sway）。
## 挂在 Camera3D 下面，所以枪模型和准星永远跟着视角走。
class_name WeaponManager
extends Node3D

signal hit_landed(killed: bool, headshot: bool)
signal ammo_changed(weapon_name: String, ammo: int, mag: int, reloading: bool)

## 碰撞层规划：1 = 世界，2 = 玩家，3 = 敌人，4 = 碎片。玩家的子弹只检测 世界 + 敌人。
const HIT_MASK := 1 | 4    # 第 1 层的值是 1，第 3 层的值是 1 << 2 = 4

@export var weapons: Array[WeaponData] = []
@export_enum("intersect_ray", "RayCast3D") var hit_method: String = "intersect_ray"

var current := 0
var ammo: Array[int] = []
var bloom := 0.0                 # 连射累积的额外散布（度）

var _cooldown := 0.0
var _reload_left := 0.0
var _switch_left := 0.0
var _trigger_ready := true
var _look_delta := Vector2.ZERO
var _sway := Vector2.ZERO
var _kick := 0.0
var _base_pos: Array[Vector3] = []
var _wall_target := 0.0   # 0 = 前面没墙，1 = 枪口已经顶到墙
var _wall := 0.0

@onready var player: Player = owner
@onready var camera: Camera3D = get_parent()
@onready var aim_ray: RayCast3D = $"../AimRay"
@onready var models: Array[Node3D] = [$Rifle, $Shotgun]


func _ready() -> void:
	Tuning.touch_look.connect(func(rel: Vector2) -> void: _look_delta += rel)   # 触屏转视角时枪也要摆动
	for w in weapons:
		ammo.append(w.mag_size)
	for m in models:
		_base_pos.append(m.position)
	aim_ray.add_exception(player)
	Tuning.bind(weapons[0], "rifle", ["recoil", "spread", "spread_per_shot", "fire_rate"])
	Tuning.bind(self, "weapon", ["hit_method"])
	Tuning.action_triggered.connect(func(a: String) -> void:
		if a == "switch_weapon":
			switch_to((current + 1) % weapons.size()))
	_show_model()
	_emit_ammo.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_look_delta += event.screen_relative
	elif event.is_action_pressed("weapon_1"):
		switch_to(0)
	elif event.is_action_pressed("weapon_2"):
		switch_to(1)
	elif event.is_action_pressed("weapon_switch"):
		switch_to((current + 1) % weapons.size())
	elif event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		switch_to((current + 1) % weapons.size())
	elif event.is_action_pressed("reload"):
		reload()


func _physics_process(delta: float) -> void:
	_check_wall()
	var w := weapons[current]
	_cooldown -= delta
	if _cooldown < 0.0:
		bloom = move_toward(bloom, 0.0, w.spread_recover * delta)
	if _reload_left > 0.0:
		_reload_left -= delta
		if _reload_left <= 0.0:
			ammo[current] = w.mag_size
			_emit_ammo()
	if _switch_left > 0.0:
		_switch_left -= delta
	if not Input.is_action_pressed("fire"):
		_trigger_ready = true
	var wants_fire := Input.is_action_pressed("fire") if w.automatic else Input.is_action_just_pressed("fire")
	if wants_fire and _trigger_ready and not player.is_dead:
		_try_fire()
	Tuning.stat("散布", "%.2f°" % current_spread())


#region fire
func _try_fire() -> void:
	var w := weapons[current]
	if _cooldown > 0.0 or _reload_left > 0.0 or _switch_left > 0.0:
		return
	if ammo[current] <= 0:
		reload()
		return
	ammo[current] -= 1
	_cooldown = 1.0 / w.fire_rate
	var spread := current_spread()
	var from := camera.global_position
	for i in w.pellets:
		var dir := _random_in_cone(spread)
		var to := from + dir * w.max_range
		var hit := _cast_query(from, to) if hit_method == "intersect_ray" else _cast_node(from, to)
		_apply_hit(hit, from, to, dir, w)
	bloom = minf(bloom + w.spread_per_shot, w.max_spread)
	# 后坐力：视角上跳 recoil 度，左右随机偏一点；Player 里会自动恢复
	player.add_recoil(w.recoil, randf_range(-0.35, 0.35) * w.recoil)
	_kick = 1.0
	models[current].flash()
	_emit_ammo()
	if ammo[current] == 0:
		reload()
#endregion


#region spread
## 当前散布（度）= 基础散布 + 连射累积 + 移动惩罚，空中再加，蹲下打折。
func current_spread() -> float:
	var w := weapons[current]
	var s := w.spread + bloom
	var speed := Vector2(player.velocity.x, player.velocity.z).length()
	s += speed / player.walk_speed * w.move_spread
	if not player.is_on_floor():
		s += 3.0
	if player.is_crouching():
		s *= 0.6
	return s


## 在半角为 spread_deg 的圆锥里随机取一个方向。
## 先在距离相机 1 米的平面上取一个半径为 tan(spread) 的圆盘内的点，
## 半径用 sqrt(randf())，点在圆盘里才是均匀分布的（直接用 randf() 会扎堆在中心）。
func _random_in_cone(spread_deg: float) -> Vector3:
	var r := tan(deg_to_rad(spread_deg)) * sqrt(randf())
	var a := randf() * TAU
	var local := Vector3(cos(a) * r, sin(a) * r, -1.0).normalized()
	return camera.global_basis * local
#endregion


#region ray_query
## 方式一：PhysicsDirectSpaceState3D.intersect_ray —— 不需要节点，随时查询一次。
## 适合"一次性"的检测：开枪、霰弹枪的每颗弹丸、敌人的视线。
func _cast_query(from: Vector3, to: Vector3) -> Dictionary:
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to, HIT_MASK, [player.get_rid()])
	return space.intersect_ray(query)   # 没打中返回 {}；打中有 position、normal、collider 等字段
#endregion


#region ray_node
## 方式二：RayCast3D 节点 —— 在场景里摆好（这里是 Camera3D/AimRay），
## 它每个物理帧自动检测一次；临时改了方向就调用 force_raycast_update() 立即刷新。
## 适合"持续"的检测：脚下是否有地面、准星指着什么。
func _cast_node(from: Vector3, to: Vector3) -> Dictionary:
	aim_ray.collision_mask = HIT_MASK
	aim_ray.global_position = from
	aim_ray.target_position = aim_ray.to_local(to)
	aim_ray.force_raycast_update()
	if not aim_ray.is_colliding():
		return {}
	return {
		"position": aim_ray.get_collision_point(),
		"normal": aim_ray.get_collision_normal(),
		"collider": aim_ray.get_collider(),
	}
#endregion


#region apply_hit
func _apply_hit(hit: Dictionary, from: Vector3, to: Vector3, dir: Vector3, w: WeaponData) -> void:
	var end: Vector3 = hit.get("position", to)
	if DebugDraw.show_rays:
		DebugDraw.line(from + camera.global_basis.y * -0.08, end, Color(1.0, 0.85, 0.2), 1.2)
	if hit.is_empty():
		return
	var target: Object = hit.collider
	if target.has_method("take_damage"):
		# 鸭子类型：谁有 take_damage 方法，谁就能被打。不需要知道它是敌人还是油桶
		var result: Dictionary = target.take_damage(w.damage, end, dir)
		hit_landed.emit(result.get("killed", false), result.get("headshot", false))
		Effects.spark(end, hit.normal, Color(1.0, 0.35, 0.25))
	else:
		Effects.bullet_hole(end, hit.normal)
		Effects.spark(end, hit.normal, Color(1.0, 0.8, 0.45))
#endregion


func reload() -> void:
	var w := weapons[current]
	if _reload_left > 0.0 or ammo[current] == w.mag_size:
		return
	_reload_left = w.reload_time
	_emit_ammo()


func switch_to(index: int) -> void:
	if index == current or _switch_left > 0.0:
		return
	_reload_left = 0.0
	current = index
	bloom = 0.0
	_switch_left = 0.35
	_show_model()
	_emit_ammo()


## 回到游戏时调用：鼠标松开之前不开火（避免"点击画面开始"的那一下打出一枪）。
func block_trigger() -> void:
	_trigger_ready = false


func _show_model() -> void:
	for i in models.size():
		models[i].visible = i == current


func _emit_ammo() -> void:
	var w := weapons[current]
	ammo_changed.emit(w.display_name, ammo[current], w.mag_size, _reload_left > 0.0)


#region sway
func _process(delta: float) -> void:
	# 摆动（sway）：鼠标往右甩，枪往左"拖"一下再回来；限制最大偏移，防止甩太快枪飞出画面
	var target := (Vector2(-_look_delta.x, _look_delta.y) * 0.0015).limit_length(0.05)
	_look_delta = Vector2.ZERO
	_sway = _sway.lerp(target, 1.0 - exp(-9.0 * delta))
	_kick = lerpf(_kick, 0.0, 1.0 - exp(-16.0 * delta))
	# 换弹 / 切枪：把枪往下压，做一个简单的"放下-抬起"动作
	var lower := 0.0
	if _reload_left > 0.0:
		var t := 1.0 - _reload_left / weapons[current].reload_time
		lower = sin(t * PI) * 0.22
	if _switch_left > 0.0:
		lower = _switch_left / 0.35 * 0.3
	_wall = lerpf(_wall, _wall_target, 1.0 - exp(-14.0 * delta))
	var m := models[current]
	m.position = _base_pos[current] + Vector3(_sway.x, _sway.y - lower - _wall * 0.05, _kick * 0.07 + _wall * WALL_REACH * 0.55)
	m.rotation = Vector3(_kick * 0.1 + _sway.y * 2.0 - lower + _wall * 0.9, _sway.x * 2.0, _sway.x * 3.0)
#endregion


#region wall_retract
## 防穿墙：枪模型比玩家的碰撞胶囊伸得更远，贴墙时枪管会插进墙里。
## 每个物理帧从相机往前打一条很短的射线，离墙越近，枪越往回收、枪口越往上抬。
const WALL_REACH := 0.75   # 枪口到相机的大致距离（米）


func _check_wall() -> void:
	var from := camera.global_position
	var to := from - camera.global_basis.z * WALL_REACH
	var query := PhysicsRayQueryParameters3D.create(from, to, 1, [player.get_rid()])   # 只检测第 1 层"世界"
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	_wall_target = 0.0 if hit.is_empty() else 1.0 - from.distance_to(hit.position) / WALL_REACH
#endregion
