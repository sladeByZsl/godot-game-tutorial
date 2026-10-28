## 俯视角主角。移动、朝向、动画、受伤逻辑在这里；"现在能做什么"交给子节点状态机。
class_name Player
extends CharacterBody2D

#region params
@export var speed := 90.0                 ## 最高速度（像素/秒，1 格 = 16 像素）
@export var acceleration := 900.0         ## 起步加速度
@export var friction := 1100.0            ## 松手后的减速度
@export var normalize_diagonal := true    ## 斜向移动是否归一化
@export var attack_cooldown := 0.35       ## 两次挥剑的最短间隔（秒）
@export var knockback := 160.0:           ## 剑把敌人击退的初速度
	set(v):
		knockback = v
		if is_node_ready():
			sword_hitbox.knockback = v
@export var invincible_time := 0.8        ## 受伤后的无敌时间（秒）
#endregion

var facing := Vector2.DOWN
var interact_target: Node2D = null
var _cooldown := 0.0
var _spawn := Vector2.ZERO
var _blink := 0.0

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var sword_pivot: Node2D = $SwordPivot
@onready var sword: Sprite2D = $SwordPivot/Sword
@onready var sword_hitbox: Hitbox = $SwordPivot/SwordHitbox
@onready var slash: Node2D = $SwordPivot/Slash
@onready var interact_area: Area2D = $InteractArea
@onready var machine: StateMachine = $StateMachine


func _ready() -> void:
	add_to_group("player")
	_spawn = global_position
	Tuning.bind(self, "player", [
		"speed", "acceleration", "friction", "normalize_diagonal",
		"attack_cooldown", "knockback", "invincible_time",
	])
	sword_hitbox.knockback = knockback
	sword_hitbox.active = false
	hurtbox.hurt.connect(_on_hurt)


func _physics_process(delta: float) -> void:
	_cooldown -= delta
	_update_interact_target()
	_update_blink(delta)
	Tuning.stat("速度", roundi(velocity.length()))
	Tuning.stat("玩家状态", String(machine.state.name) if machine.state else "")


#region input_vector
func get_input_vector() -> Vector2:
	if normalize_diagonal:
		# get_vector 把结果的长度限制在 1 以内：同时按右和下得到 (0.707, 0.707)
		return Input.get_vector("move_left", "move_right", "move_up", "move_down")
	# 两个轴各取各的：斜向时是 (1, 1)，长度 √2 ≈ 1.414，跑得比直走快
	return Vector2(Input.get_axis("move_left", "move_right"), Input.get_axis("move_up", "move_down"))
#endregion


#region move
func move(delta: float, input: Vector2) -> void:
	if input != Vector2.ZERO:
		# 朝目标速度逼近，每秒最多改变 acceleration：起步有个很短的加速过程
		velocity = velocity.move_toward(input * speed, acceleration * delta)
		facing = _to_four_way(input)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
	move_and_slide()
#endregion


## 把任意方向归到上下左右四个朝向之一（精灵图只有四个方向）。
func _to_four_way(v: Vector2) -> Vector2:
	if absf(v.x) > absf(v.y) + 0.01:
		return Vector2(signf(v.x), 0)
	if absf(v.y) > absf(v.x) + 0.01:
		return Vector2(0, signf(v.y))
	# 正对角：如果当前朝向是其中一个分量就保持，避免斜走时来回翻转
	if (facing.x != 0 and signf(facing.x) == signf(v.x)) or (facing.y != 0 and signf(facing.y) == signf(v.y)):
		return facing
	return Vector2(0, signf(v.y))


func _dir_name() -> String:
	if facing.y < 0:
		return "up"
	if facing.y > 0:
		return "down"
	return "side"


func play_walk_animation() -> void:
	sprite.flip_h = facing.x < 0
	var moving := velocity.length() > 8.0
	sprite.play(("walk_" if moving else "idle_") + _dir_name())
	sprite.speed_scale = clampf(velocity.length() / 90.0, 0.6, 2.0) if moving else 1.0


#region swing
func can_attack() -> bool:
	return _cooldown <= 0.0


func start_swing() -> void:
	_cooldown = attack_cooldown
	sprite.flip_h = facing.x < 0
	sprite.play("attack_" + _dir_name())
	# 剑的枢轴朝向 facing：枢轴旋转 0 时剑尖朝上（-Y），所以要加 90°
	sword_pivot.rotation = facing.angle() + PI / 2.0
	move_child(sword_pivot, 0 if facing.y < 0 else -1)   # 朝上挥时剑画在身体后面
	sword.visible = true
	sword.rotation = -1.2
	create_tween().tween_property(sword, "rotation", 1.2, 0.14).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	slash.play()
	sword_hitbox.active = true


func end_swing() -> void:
	sword_hitbox.active = false
	sword.visible = false
#endregion


#region take_hit
func _on_hurt(hitbox: Hitbox) -> void:
	if is_dead():
		return
	Game.change_hp(-hitbox.damage)
	var dir := (global_position - hitbox.global_position).normalized()
	if Game.hp <= 0:
		machine.transition_to(&"Dead")
		return
	machine.transition_to(&"Hurt", {"knockback": dir * hitbox.knockback})
	hurtbox.start_invincibility(invincible_time)   # 无敌帧：这段时间里 Hurtbox 不再响应
	_blink = invincible_time
#endregion


func _update_blink(delta: float) -> void:
	_blink = maxf(_blink - delta, 0.0)
	# 无敌期间以 15 Hz 闪烁，让玩家看得出"现在打不到我"
	sprite.modulate.a = 0.35 if _blink > 0.0 and fmod(_blink, 0.133) < 0.066 else 1.0


#region interact
func _update_interact_target() -> void:
	var best: Node2D = null
	var best_d := INF
	for area in interact_area.get_overlapping_areas():
		var target := area.get_parent() as Node2D
		if target and target.has_method("interact") and target.can_interact():
			var d := global_position.distance_squared_to(target.global_position)
			if d < best_d:
				best = target
				best_d = d
	interact_target = best


func try_interact() -> void:
	if interact_target:
		interact_target.interact(self)
#endregion


func is_dead() -> bool:
	return machine.state != null and machine.state.name == &"Dead"


func respawn() -> void:
	global_position = _spawn
	velocity = Vector2.ZERO
	Game.change_hp(Game.max_hp)


func teleport(pos: Vector2) -> void:
	global_position = pos
	velocity = Vector2.ZERO
