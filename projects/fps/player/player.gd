## 第一人称控制器。
## 节点结构：Player（CharacterBody3D，只绕 Y 轴左右转）→ Head（只绕 X 轴上下看）→ Camera3D（晃动、后坐力）
## 把左右转和上下看拆到两个节点上，各自只有一个旋转轴，就不会出现"转着转着歪了"的问题。
class_name Player
extends CharacterBody3D

signal health_changed(hp: float, max_hp: float)
signal damaged(from_position: Vector3, amount: float)
signal died

#region params
@export_group("视角")
@export var mouse_sensitivity := 0.12   ## 每移动 1 像素转多少度
@export var invert_y := false           ## 反转 Y 轴（飞行游戏玩家的习惯）
@export var max_pitch := 88.0           ## 抬头/低头的最大角度
@export var fov := 75.0                 ## 垂直视野角（度）
@export var sprint_fov := 86.0          ## 冲刺时的视野角

@export_group("移动")
@export var walk_speed := 5.0           ## 行走速度（米/秒）
@export var sprint_mult := 1.6          ## 冲刺速度倍率
@export var crouch_mult := 0.5          ## 蹲行速度倍率
@export var acceleration := 45.0        ## 地面加速度（米/秒²）
@export var friction := 40.0            ## 松开按键后的减速度
@export var air_control := 0.3          ## 空中加速度占地面的比例
@export var jump_velocity := 5.2        ## 起跳速度（米/秒）
@export var gravity := 14.0             ## 重力加速度（米/秒²，现实是 9.8，游戏里通常更大）

@export_group("镜头")
@export var bob_amount := 0.05          ## 头部晃动幅度（米）
@export var bob_freq := 1.3             ## 每走 1 米相位增加多少弧度
#endregion

const STAND_HEIGHT := 1.8
const CROUCH_HEIGHT := 1.05
const EYE_BELOW_TOP := 0.18             # 眼睛在头顶下方多少米

var max_health := 100.0
var health := 100.0
var is_dead := false

var _crouching := false
var _sprinting := false
var _was_on_floor := true
var _bob_phase := 0.0
var _bob_offset := Vector3.ZERO
var _land_target := 0.0
var _land_offset := 0.0
var _recoil_target := Vector2.ZERO
var _recoil := Vector2.ZERO
var _tilt := 0.0
var _spawn: Transform3D

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var collision: CollisionShape3D = $CollisionShape3D
@onready var capsule: CapsuleShape3D = collision.shape


func _ready() -> void:
	Tuning.touch_look.connect(_look)   # 手机上：网页右半屏滑动 = 鼠标移动
	_spawn = global_transform
	camera.fov = fov
	Tuning.bind(self, "player", [
		"mouse_sensitivity", "invert_y", "fov", "sprint_fov",
		"walk_speed", "sprint_mult", "acceleration", "air_control", "jump_velocity", "gravity",
		"bob_amount", "bob_freq",
	])


#region mouse_look
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# screen_relative 是鼠标在屏幕上实际移动的像素，不受窗口拉伸（stretch）影响，适合做视角
		_look(event.screen_relative)


## 鼠标和触屏共用：relative 是移动了多少像素。
func _look(relative: Vector2) -> void:
	var d := relative * deg_to_rad(mouse_sensitivity)
	rotate_y(-d.x)                                  # 身体左右转（偏航 yaw）
	var pitch_dir := 1.0 if invert_y else -1.0
	head.rotation.x = clampf(head.rotation.x + d.y * pitch_dir,
			-deg_to_rad(max_pitch), deg_to_rad(max_pitch))   # 头上下看（俯仰 pitch），限制角度
#endregion


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	_update_crouch(delta)
	_apply_gravity_and_jump(delta)
	_move(delta)
	var fall_speed := -velocity.y
	move_and_slide()
	if is_on_floor() and not _was_on_floor:
		_on_landed(fall_speed)
	_was_on_floor = is_on_floor()
	_update_camera(delta)
	if global_position.y < -20.0:
		respawn()
	Tuning.stat("速度", "%.1f m/s" % Vector2(velocity.x, velocity.z).length())
	Tuning.stat("状态", "蹲下" if _crouching else ("冲刺" if _sprinting else ("空中" if not is_on_floor() else "地面")))


#region move
func _move(delta: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	# input 是"相对自己"的方向：x 左右，y 前后（前 = -1）。乘上身体的 basis 就变成世界方向。
	# Godot 里 -Z 是前方，所以"前"对应 Vector3(0, 0, -1)。
	var wish_dir := (transform.basis * Vector3(input.x, 0.0, input.y)).normalized()
	_sprinting = Input.is_action_pressed("sprint") and input.y < -0.1 and not _crouching
	var speed := walk_speed
	if _sprinting:
		speed *= sprint_mult
	elif _crouching:
		speed *= crouch_mult

	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	var rate: float
	if is_on_floor():
		rate = acceleration if wish_dir != Vector3.ZERO else friction
	else:
		# 空中：只有一部分操控力，没有输入时保持惯性（没有地面摩擦）
		rate = acceleration * air_control if wish_dir != Vector3.ZERO else 0.0
	# move_toward：每帧朝目标速度最多改变 rate·delta，相当于恒定加速度
	horizontal = horizontal.move_toward(wish_dir * speed, rate * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	_tilt = -input.x
#endregion


#region jump
func _apply_gravity_and_jump(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	elif Input.is_action_just_pressed("jump") and not _crouching:
		# 跳跃高度 h = v² / (2g)：默认 5.2² / 28 ≈ 0.97 米，跳不上 1.2 米高的箱子，但能跳上 0.9 米的台子
		velocity.y = jump_velocity
#endregion


#region crouch
func _update_crouch(delta: float) -> void:
	var want := Input.is_action_pressed("crouch")
	if want and not _crouching:
		_set_body_height(CROUCH_HEIGHT)
		_crouching = true
	elif not want and _crouching and _can_stand_up():
		_set_body_height(STAND_HEIGHT)
		_crouching = false
	# 碰撞体是瞬间变矮的，眼睛高度则平滑地跟过去
	var eye := (CROUCH_HEIGHT if _crouching else STAND_HEIGHT) - EYE_BELOW_TOP
	head.position.y = lerpf(head.position.y, eye, 1.0 - exp(-12.0 * delta))


## 头顶检测：拿当前（蹲着的）碰撞体，"假装"往上挪一段，看会不会撞到东西。
## test_move 不会真的移动角色，只返回会不会发生碰撞。
func _can_stand_up() -> bool:
	return not test_move(global_transform, Vector3.UP * (STAND_HEIGHT - CROUCH_HEIGHT))


func _set_body_height(h: float) -> void:
	capsule.height = h
	collision.position.y = h / 2.0     # 脚底保持在原点，胶囊从上面缩短
#endregion


#region camera_smooth
func _on_landed(fall_speed: float) -> void:
	# 落得越快，镜头往下沉得越多（最多 0.3 米）
	_land_target = -clampf((fall_speed - 2.0) * 0.035, 0.0, 0.3)


func _update_camera(delta: float) -> void:
	_update_head_bob(delta)
	# 两级平滑：目标值先"弹"出去再慢慢回零，实际值快速追目标。这样有冲击感又不生硬。
	_land_offset = lerpf(_land_offset, _land_target, 1.0 - exp(-25.0 * delta))
	_land_target = lerpf(_land_target, 0.0, 1.0 - exp(-7.0 * delta))
	_recoil = _recoil.lerp(_recoil_target, 1.0 - exp(-30.0 * delta))
	_recoil_target = _recoil_target.lerp(Vector2.ZERO, 1.0 - exp(-6.0 * delta))
	camera.position = _bob_offset + Vector3(0.0, _land_offset, 0.0)
	camera.rotation.x = _recoil.x
	camera.rotation.y = _recoil.y
	camera.rotation.z = lerpf(camera.rotation.z, _tilt * deg_to_rad(1.5), 1.0 - exp(-8.0 * delta))
	_update_fov(delta)
#endregion


#region head_bob
func _update_head_bob(delta: float) -> void:
	var speed := Vector2(velocity.x, velocity.z).length()
	var target := Vector3.ZERO
	if is_on_floor() and speed > 0.5:
		# 相位按"走过的距离"增长：走得越快，晃得越快；停下时相位不变
		_bob_phase += speed * bob_freq * delta
		var amp := bob_amount * minf(speed / walk_speed, 1.6)
		# 横向走 1 个周期，纵向走 2 个周期（左右脚各落地一次）→ 轨迹是横放的 8 字
		target = Vector3(sin(_bob_phase) * amp * 0.6, sin(_bob_phase * 2.0) * amp, 0.0)
	# 帧率无关的平滑：系数 1 - exp(-k·dt)，不管 30 帧还是 144 帧，过渡快慢都一样
	_bob_offset = _bob_offset.lerp(target, 1.0 - exp(-10.0 * delta))
#endregion


#region fov
func _update_fov(delta: float) -> void:
	var moving_fast := Vector2(velocity.x, velocity.z).length() > walk_speed * 1.1
	var target := sprint_fov if (_sprinting and moving_fast) else fov
	camera.fov = lerpf(camera.fov, target, 1.0 - exp(-8.0 * delta))
#endregion


## 武器开火时调用：视角往上跳 pitch 度，左右随机偏 yaw 度，之后自动恢复。
func add_recoil(pitch_deg: float, yaw_deg: float) -> void:
	_recoil_target += Vector2(deg_to_rad(pitch_deg), deg_to_rad(yaw_deg))


func is_crouching() -> bool:
	return _crouching


func take_damage(amount: float, from_position: Vector3) -> void:
	if is_dead:
		return
	health = maxf(health - amount, 0.0)
	health_changed.emit(health, max_health)
	damaged.emit(from_position, amount)
	_recoil_target += Vector2(deg_to_rad(randf_range(-1.0, 1.0)), deg_to_rad(randf_range(-1.5, 1.5)))
	if health <= 0.0:
		is_dead = true
		died.emit()


func respawn() -> void:
	global_transform = _spawn
	velocity = Vector3.ZERO
	head.rotation = Vector3.ZERO
	health = max_health
	is_dead = false
	health_changed.emit(health, max_health)
