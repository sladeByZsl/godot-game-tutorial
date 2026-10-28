## 平台跳跃的主角。所有"手感"参数都用 @export 暴露，在检查器（或教程网页）里可以直接调。
class_name Player
extends CharacterBody2D

signal coin_collected(total: int)
signal died(count: int)

#region params
@export_group("水平移动")
@export var max_speed := 260.0          ## 最高水平速度（像素/秒）
@export var acceleration := 1800.0      ## 地面加速度（像素/秒²）
@export var friction := 2200.0          ## 松开按键后的减速度
@export var air_control := 0.6          ## 空中加速度占地面的比例 0~1

@export_group("跳跃")
@export var jump_height := 110.0        ## 跳跃最高点高度（像素）
@export var time_to_peak := 0.38        ## 起跳到最高点的时间（秒）
@export var fall_multiplier := 1.6      ## 下落时重力放大倍数
@export var jump_cut := 0.45            ## 提前松开跳跃键时，保留多少上升速度
@export var max_fall_speed := 900.0

@export_group("宽容度")
@export var coyote_time := 0.10         ## 走出平台后还能起跳的时间
@export var jump_buffer := 0.12         ## 落地前提前按跳跃也算数的时间
#endregion

var level: Level                        ## 由 main.gd 在开局时设置
var coins := 0
var deaths := 0
var facing := 1.0
var dead := false
var _coyote_timer := 0.0
var _buffer_timer := 0.0
var _spawn_point := Vector2.ZERO
var _fall_speed := 0.0                  # 记录落地前一帧的下落速度，用来决定落地效果的强弱
var _happy_timer := 0.0
var _squash_tween: Tween

@onready var visual: Node2D = $Visual
@onready var flip: Node2D = $Visual/Flip
@onready var body: PlayerBody = $Visual/Flip/Rig/Body
@onready var anim: AnimationPlayer = $AnimationPlayer


func _ready() -> void:
	_spawn_point = global_position
	Tuning.bind(self, "player", [
		"max_speed", "acceleration", "friction", "air_control",
		"jump_height", "time_to_peak", "fall_multiplier", "jump_cut",
		"max_fall_speed", "coyote_time", "jump_buffer",
	])
	Tuning.action_triggered.connect(func(a: String) -> void:
		if a == "respawn":
			respawn())
	Tuning.changed.connect(func(key: String, value: Variant) -> void:
		if key == "fx.animation":
			set_animation_enabled(value))
	set_animation_enabled(Fx.animation)


#region gravity
## 由"跳多高、多久到顶"反推重力和起跳速度：
##   h = v0·t - ½·g·t²，最高点时 v = v0 - g·t = 0
##   => g = 2h / t²，v0 = 2h / t
func get_gravity_value() -> float:
	return 2.0 * jump_height / (time_to_peak * time_to_peak)


func get_jump_velocity() -> float:
	return -2.0 * jump_height / time_to_peak
#endregion


#region physics
func _physics_process(delta: float) -> void:
	if dead:
		velocity.y = minf(velocity.y + get_gravity_value() * delta, max_fall_speed)
		position += velocity * delta        # 死亡后不再参与碰撞，直接下落出屏幕
		return
	_apply_gravity(delta)
	_handle_jump(delta)
	_handle_horizontal(delta)

	var was_on_floor := is_on_floor()
	if not was_on_floor:
		_fall_speed = velocity.y
	move_and_slide()
	if not was_on_floor and is_on_floor():
		_on_landed()

	_check_hazards()
	if level and global_position.y > level.get_bounds().end.y + 64.0:
		die()
	_update_visual(delta)
	Tuning.stat("速度 x", roundi(velocity.x))
	Tuning.stat("速度 y", roundi(velocity.y))
	Tuning.stat("在地面", is_on_floor())
#endregion


#region gravity_apply
func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		return
	var g := get_gravity_value()
	if velocity.y > 0.0:
		g *= fall_multiplier    # 下落比上升更快，跳跃更"干脆"
	velocity.y = minf(velocity.y + g * delta, max_fall_speed)
#endregion


#region jump
func _handle_jump(delta: float) -> void:
	# 土狼时间：在地面时一直重置，离开地面后开始倒数
	if is_on_floor():
		_coyote_timer = coyote_time
	else:
		_coyote_timer -= delta

	# 跳跃缓冲：按下跳跃键后，在 jump_buffer 秒内落地都会自动起跳
	if Input.is_action_just_pressed("jump"):
		_buffer_timer = jump_buffer
	else:
		_buffer_timer -= delta

	if _buffer_timer > 0.0 and _coyote_timer > 0.0:
		velocity.y = get_jump_velocity()
		_buffer_timer = 0.0
		_coyote_timer = 0.0
		_on_jumped()

	# 可变跳跃高度：上升途中松开按键，砍掉一部分上升速度
	if Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= jump_cut
#endregion


#region horizontal
func _handle_horizontal(delta: float) -> void:
	var dir := Input.get_axis("move_left", "move_right")
	var accel := acceleration if is_on_floor() else acceleration * air_control
	if dir != 0.0:
		velocity.x = move_toward(velocity.x, dir * max_speed, accel * delta)
		facing = signf(dir)
	else:
		var decel := friction if is_on_floor() else friction * air_control
		velocity.x = move_toward(velocity.x, 0.0, decel * delta)
#endregion


#region juice_events
func _on_jumped() -> void:
	squash(Vector2(0.7, 1.35))
	Fx.puff(global_position, _dust_color(), 6, Vector2.UP)


func _on_landed() -> void:
	# 下落越快，压得越扁、烟尘越多
	var k := clampf(_fall_speed / max_fall_speed, 0.0, 1.0)
	squash(Vector2(1.0 + 0.45 * k, 1.0 - 0.4 * k))
	Fx.puff(global_position, _dust_color(), int(4 + 10 * k), Vector2.ZERO)
	if k > 0.85:
		Fx.add_trauma(0.25)
#endregion


#region squash
## 挤压拉伸：先把 Visual 瞬间缩放到 to，再用 Tween 弹回 (1, 1)。
## Fx.squash 是强度：0 = 关闭，1 = 原样，2 = 加倍夸张。
func squash(to: Vector2, duration := 0.25) -> void:
	if Fx.squash <= 0.0:
		visual.scale = Vector2.ONE
		return
	if _squash_tween:
		_squash_tween.kill()
	visual.scale = Vector2.ONE.lerp(to, Fx.squash)
	_squash_tween = create_tween()
	_squash_tween.tween_property(visual, "scale", Vector2.ONE, duration) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
#endregion


#region anim_select
func _update_visual(delta: float) -> void:
	if dead:
		return
	flip.scale.x = facing
	body.look = Vector2(facing * minf(absf(velocity.x) / max_speed, 1.0), clampf(velocity.y / 600.0, -1.0, 1.0))
	_happy_timer -= delta
	if _happy_timer > 0.0:
		body.expression = PlayerBody.Face.HAPPY
	elif velocity.y > max_fall_speed * 0.8:
		body.expression = PlayerBody.Face.SURPRISED
	else:
		body.expression = PlayerBody.Face.NORMAL

	if not Fx.animation:
		return
	var next := "idle"
	if not is_on_floor():
		next = "jump" if velocity.y < 0.0 else "fall"
	elif absf(velocity.x) > 20.0:
		next = "run"
	if anim.current_animation != next:
		anim.play(next, 0.08)
	# 跑步动画的播放速度跟着实际速度走，脚步才不会"打滑"
	anim.speed_scale = clampf(absf(velocity.x) / 220.0, 0.6, 1.8) if next == "run" else 1.0
	Tuning.stat("动画", next)
#endregion


## AnimationPlayer 的"调用方法轨道"会在跑步动画里每次脚落地时调用这里。
#region footstep
func _footstep() -> void:
	if is_on_floor():
		Fx.puff(global_position + Vector2(-facing * 6.0, 0), _dust_color(), 2, Vector2(-facing, -0.4))
#endregion


func set_animation_enabled(on: bool) -> void:
	if on:
		anim.active = true
	else:
		anim.play("RESET")
		anim.advance(0.0)
		anim.active = false


#region hazard
## 尖刺没有碰撞形状：每帧用身体上的几个采样点去查瓦片的自定义数据 hazard。
func _check_hazards() -> void:
	if level == null:
		return
	for p: Vector2 in [Vector2(-8, -3), Vector2(8, -3), Vector2(0, -20)]:
		if level.is_hazard(global_position + p):
			die()
			return
#endregion


func _dust_color() -> Color:
	if level:
		return level.dust_color_at(global_position + Vector2(0, 4))
	return Color.WHITE


func collect_coin() -> void:
	coins += 1
	_happy_timer = 0.6
	coin_collected.emit(coins)


func bounce() -> void:
	velocity.y = get_jump_velocity() * 0.8
	_happy_timer = 0.4
	squash(Vector2(0.75, 1.3))


func set_checkpoint(pos: Vector2) -> void:
	_spawn_point = pos


#region die
func die() -> void:
	if dead:
		return
	dead = true
	deaths += 1
	died.emit(deaths)
	body.expression = PlayerBody.Face.HURT
	Fx.freeze(Fx.hit_stop * 2.0)
	Fx.add_trauma(0.6)
	if Fx.animation:
		anim.play("hurt")
	velocity = Vector2(-facing * 60.0, get_jump_velocity() * 0.9)
	await get_tree().create_timer(1.0).timeout
	respawn()
#endregion


func respawn() -> void:
	global_position = _spawn_point
	velocity = Vector2.ZERO
	dead = false
	_buffer_timer = 0.0
	if Fx.animation:
		anim.play("idle")
	var cam := get_node_or_null("Camera") as Camera2D
	if cam:
		cam.reset_smoothing()
	visual.scale = Vector2(0.2, 0.2)
	squash(Vector2(0.2, 0.2), 0.45)
