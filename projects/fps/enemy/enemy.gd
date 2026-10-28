## 敌人：巡逻 → 发现玩家后追击 → 进入射程且看得见就开火。
## 移动靠 NavigationAgent3D 寻路，开启避障（avoidance）后多个敌人不会挤成一团。
class_name Enemy
extends CharacterBody3D

signal died(enemy: Enemy)

enum State { PATROL, CHASE, ATTACK, DEAD }

#region params
@export var move_speed := 3.2           ## 追击速度（米/秒），巡逻时是一半
@export var sight_range := 22.0         ## 视野距离（米）
@export var view_angle := 110.0         ## 视野角（度）：巡逻时只看得见前方这个扇形里的东西
@export var attack_range := 15.0        ## 进入这个距离并且看得见，就停下来射击
@export var max_health := 100.0
@export var shot_damage := 7.0
@export var fire_interval := 1.4        ## 两次射击间隔（秒）
#endregion

const WINDUP := 0.45                    # 开火前的"蓄力"提示时间：面罩变亮，给玩家反应的机会
const SHOT_MASK := 1 | 2                # 敌人的子弹检测 世界 + 玩家

var state := State.PATROL
var health := 100.0
var can_see := false
var last_known := Vector3.ZERO

var _player: Player
var _think := 0.0
var _lost_time := 0.0
var _fire_timer := 0.0
var _knock := Vector3.ZERO
var _flash := 0.0
var _flash_mat: StandardMaterial3D
var _visor_mat: StandardMaterial3D
var _parts: Array[MeshInstance3D] = []

@onready var agent: NavigationAgent3D = $NavigationAgent3D
@onready var eye: Marker3D = $Body/Eye
@onready var muzzle: Marker3D = $Body/Muzzle
@onready var visor: MeshInstance3D = $Body/Visor


func _ready() -> void:
	health = max_health
	_player = get_tree().get_first_node_in_group("player")
	Tuning.bind(self, "enemy", ["move_speed", "sight_range"])
	agent.velocity_computed.connect(_on_velocity_computed)
	for c in $Body.get_children():
		if c is MeshInstance3D:
			_parts.append(c)
	# 每个敌人一份独立的材质，受击闪白、面罩变亮时互不影响
	_visor_mat = visor.get_active_material(0).duplicate()
	visor.material_override = _visor_mat
	_flash_mat = StandardMaterial3D.new()
	_flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_flash_mat.albedo_color = Color(1, 1, 1, 0)
	_fire_timer = randf_range(0.5, fire_interval)
	_pick_patrol_point.call_deferred()


#region state_machine
func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	# 感知不用每帧做：每 0.15 秒打一次射线就够了，还能省性能
	_think -= delta
	if _think <= 0.0:
		_think = 0.15
		can_see = _can_see_player()
		if can_see:
			last_known = _player.global_position
			_lost_time = 0.0
	var dist := global_position.distance_to(_player.global_position)
	match state:
		State.PATROL:
			if can_see:
				_enter(State.CHASE)
			elif agent.is_navigation_finished():
				_pick_patrol_point()
		State.CHASE:
			if can_see and dist < attack_range:
				_enter(State.ATTACK)
			else:
				agent.target_position = last_known
				if not can_see:
					_lost_time += delta
					if _lost_time > 6.0 and agent.is_navigation_finished():
						_enter(State.PATROL)        # 跟丢了，回去巡逻
		State.ATTACK:
			if not can_see or dist > attack_range * 1.25 or _player.is_dead:
				_enter(State.CHASE)
			else:
				_attack(delta)
	_move()
	_update_visuals(delta)


func _enter(new_state: State) -> void:
	state = new_state
	match new_state:
		State.CHASE:
			agent.target_position = last_known
		State.ATTACK:
			_fire_timer = maxf(_fire_timer, WINDUP + 0.1)
		State.PATROL:
			_pick_patrol_point()
#endregion


#region perception
## 三道关：距离够近 → 在视野扇形里（已经在追的时候不限角度）→ 视线射线没被墙挡住。
func _can_see_player() -> bool:
	if _player.is_dead:
		return false
	var from := eye.global_position
	var target := _player.head.global_position
	var to := target - from
	if to.length() > sight_range:
		return false
	if state == State.PATROL:
		var forward := -global_basis.z                   # -Z 是前方
		var flat := Vector3(to.x, 0.0, to.z)
		if forward.angle_to(flat) > deg_to_rad(view_angle / 2.0):
			return false
	var query := PhysicsRayQueryParameters3D.create(from, target, SHOT_MASK, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var seen: bool = not hit.is_empty() and hit.collider == _player
	if DebugDraw.show_rays:
		var end: Vector3 = hit.get("position", target)
		DebugDraw.line(from, end, Color(0.3, 1.0, 0.4) if seen else Color(1.0, 0.3, 0.3, 0.6), 0.15)
	return seen
#endregion


func _pick_patrol_point() -> void:
	var map := get_world_3d().navigation_map
	if NavigationServer3D.map_get_iteration_id(map) == 0:
		return                                           # 导航地图还没同步好（第一帧）
	agent.target_position = NavigationServer3D.map_get_random_point(map, 1, false)


#region nav_move
func _move() -> void:
	var desired := Vector3.ZERO
	if state != State.ATTACK and not agent.is_navigation_finished():
		var next := agent.get_next_path_position()       # 路径上的下一个拐点
		var dir := next - global_position
		dir.y = 0.0
		var speed := move_speed * (0.5 if state == State.PATROL else 1.0)
		desired = dir.normalized() * speed
	agent.max_speed = move_speed
	if agent.avoidance_enabled:
		agent.velocity = desired          # 交给避障系统，它算出不撞别人的速度后发 velocity_computed 信号
	else:
		_on_velocity_computed(desired)
	if DebugDraw.show_nav and state != State.ATTACK:
		DebugDraw.path(agent.get_current_navigation_path(), Color(1.0, 0.6, 0.1))


func _on_velocity_computed(safe_velocity: Vector3) -> void:
	if state == State.DEAD:
		return
	var delta := get_physics_process_delta_time()
	velocity.x = safe_velocity.x + _knock.x
	velocity.z = safe_velocity.z + _knock.z
	velocity.y = 0.0 if is_on_floor() else velocity.y - 20.0 * delta
	_knock = _knock.lerp(Vector3.ZERO, 1.0 - exp(-8.0 * delta))
	move_and_slide()
	# 转向：攻击时面向玩家，否则面向移动方向。atan2(-x, -z) 求出让 -Z 对准某方向的偏航角
	var face := _player.global_position - global_position if state == State.ATTACK else safe_velocity
	if Vector2(face.x, face.z).length() > 0.1:
		rotation.y = lerp_angle(rotation.y, atan2(-face.x, -face.z), 1.0 - exp(-10.0 * delta))
#endregion


#region attack
func _attack(delta: float) -> void:
	_fire_timer -= delta
	if _fire_timer > 0.0:
		return
	_fire_timer = fire_interval
	var from := muzzle.global_position
	# 命中率：距离越远、玩家跑得越快，瞄准点的随机偏移越大
	var chest := _player.global_position + Vector3.UP * 1.2
	var player_speed := Vector2(_player.velocity.x, _player.velocity.z).length()
	var miss_radius := 0.2 + from.distance_to(chest) * 0.025 + player_speed * 0.09
	var aim := chest + Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized() * randf() * miss_radius
	var to := from + (aim - from).normalized() * (sight_range + 5.0)
	var query := PhysicsRayQueryParameters3D.create(from, to, SHOT_MASK, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var end: Vector3 = hit.get("position", to)
	Effects.tracer(from, end)
	if not hit.is_empty() and hit.collider == _player:
		_player.take_damage(shot_damage, global_position)
	elif not hit.is_empty():
		Effects.spark(end, hit.normal, Color(1.0, 0.5, 0.3))
#endregion


#region take_damage
## 被玩家的射线打中时调用。返回 {killed, headshot} 给武器，用来显示命中标记。
func take_damage(amount: float, hit_pos: Vector3, dir: Vector3) -> Dictionary:
	if state == State.DEAD:
		return {}
	var headshot := hit_pos.y - global_position.y > 1.42    # 打在头部高度：双倍伤害
	var dmg := amount * (2.0 if headshot else 1.0)
	health -= dmg
	Effects.damage_number(hit_pos, dmg, headshot)
	_flash = 1.0
	_knock += Vector3(dir.x, 0.0, dir.z).normalized() * 1.5
	# 挨打就知道玩家在哪：直接进入追击（即使玩家在背后）
	last_known = _player.global_position
	if state == State.PATROL:
		_enter(State.CHASE)
	if health <= 0.0:
		_die(dir)
		return {"killed": true, "headshot": headshot}
	return {"killed": false, "headshot": headshot}


func _die(dir: Vector3) -> void:
	state = State.DEAD
	Effects.explode(_parts, global_position + Vector3.UP * 1.0, Vector3(dir.x, 0.0, dir.z).normalized())
	died.emit(self)
	queue_free()
#endregion


func _update_visuals(delta: float) -> void:
	# 受击闪白：把一层半透明白色材质叠在所有部件上（material_overlay），再淡出
	if _flash > 0.0:
		_flash = maxf(_flash - delta * 6.0, 0.0)
		_flash_mat.albedo_color.a = _flash * 0.8
		for p in _parts:
			p.material_overlay = _flash_mat if _flash > 0.0 else null
	# 面罩亮度：平时暗红，追击时变亮，开火前蓄力时最亮
	var glow := 1.5
	if state == State.CHASE:
		glow = 3.0
	elif state == State.ATTACK:
		glow = 3.0 + (8.0 if _fire_timer < WINDUP else 0.0)
	_visor_mat.emission_energy_multiplier = lerpf(_visor_mat.emission_energy_multiplier, glow, 1.0 - exp(-12.0 * delta))
