## 敌人（史莱姆、蝙蝠共用）。AI 用 enum + match 写的有限状态机：
## IDLE 发呆 → WANDER 游荡 → CHASE 追击 → ATTACK 蓄力扑击 → HURT 受伤 → DEAD 死亡
class_name Enemy
extends CharacterBody2D

#region params
@export var sense_radius := 64.0      ## 玩家进入这个距离就开始追
@export var lose_radius := 112.0      ## 追击中玩家离开这个距离就放弃（比感知半径大，避免在边界反复横跳）
@export var chase_speed := 50.0
@export var wander_interval := 2.0    ## 发呆多久后换个方向游荡（秒）
@export var damage := 1:              ## 碰到玩家扣多少血（半颗心 = 1）
	set(v):
		damage = v
		if is_node_ready():
			hitbox.damage = v
@export var max_hp := 3:              ## 改血量上限时，场上已有的敌人按比例调整当前血量
	set(v):
		if hp > 0 and max_hp > 0:
			hp = maxi(1, roundi(float(hp) * v / max_hp))
		max_hp = v
#endregion

@export_group("种类")
@export var kind := &"slime"
@export var speed_scale := 1.0        ## 蝙蝠飞得快一些
@export var flying := false           ## 飞行单位：精灵上下浮动

const ATTACK_RANGE := 26.0
const WINDUP := 0.35                  ## 扑击前的蓄力时间
const LUNGE_SPEED := 150.0
const PICKUP := preload("res://items/pickup.tscn")
const PUFF := preload("res://fx/puff.tscn")

#region fsm_enum
enum State { IDLE, WANDER, CHASE, ATTACK, HURT, DEAD }

var state := State.IDLE
var state_time := 0.0        # 进入当前状态多久了
#endregion

var hp := 3
var emote := ""              # 头顶的 "!" 或 "?"
var _emote_time := 0.0
var _wander_dir := Vector2.ZERO
var _attack_dir := Vector2.ZERO
var _lunged := false
var _player: Player

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var hitbox: Hitbox = $Hitbox
@onready var hurtbox: Hurtbox = $Hurtbox


func _ready() -> void:
	add_to_group("enemies")
	Tuning.bind(self, "enemy", ["sense_radius", "lose_radius", "chase_speed", "wander_interval", "damage", "max_hp"])
	hp = max_hp
	hitbox.damage = damage
	hurtbox.hurt.connect(_on_hurt)
	_player = get_tree().get_first_node_in_group("player")
	state_time = randf() * wander_interval     # 错开每只敌人的节奏
	sprite.play()


#region fsm_tick
func _physics_process(delta: float) -> void:
	state_time += delta
	match state:
		State.IDLE:
			velocity = velocity.move_toward(Vector2.ZERO, 300.0 * delta)
			if _sees_player():
				change_state(State.CHASE)
			elif state_time > wander_interval:
				change_state(State.WANDER)
		State.WANDER:
			velocity = velocity.move_toward(_wander_dir * chase_speed * 0.45 * speed_scale, 300.0 * delta)
			if _sees_player():
				change_state(State.CHASE)
			elif state_time > wander_interval * 0.6 or get_slide_collision_count() > 0:
				change_state(State.IDLE)
		State.CHASE:
			var to_player := _player.global_position - global_position
			velocity = velocity.move_toward(to_player.normalized() * chase_speed * speed_scale, 400.0 * delta)
			if _lost_player():
				change_state(State.IDLE)
				_show_emote("?")
			elif to_player.length() < ATTACK_RANGE and state_time > 0.3:
				change_state(State.ATTACK)
		State.ATTACK:
			if state_time < WINDUP:                       # 蓄力：停下、抖动
				velocity = velocity.move_toward(Vector2.ZERO, 800.0 * delta)
				sprite.position.x = sin(state_time * 60.0) * 1.0
			elif not _lunged:                             # 扑出去
				_lunged = true
				sprite.position.x = 0.0
				velocity = _attack_dir * LUNGE_SPEED * speed_scale
			else:
				velocity = velocity.move_toward(Vector2.ZERO, 300.0 * delta)
				if state_time > WINDUP + 0.45:
					change_state(State.CHASE)
		State.HURT:
			velocity = velocity.move_toward(Vector2.ZERO, 500.0 * delta)   # 击退速度慢慢衰减
			if state_time > 0.3:
				change_state(State.CHASE)
		State.DEAD:
			return
	move_and_slide()
	_update_visual(delta)
#endregion


#region change_state
func change_state(next: State) -> void:
	if state == State.DEAD:
		return                                   # 死了就不再切换
	var prev := state
	state = next
	state_time = 0.0
	match next:
		State.WANDER:
			_wander_dir = Vector2.from_angle(randf() * TAU)
		State.CHASE:
			if prev == State.IDLE or prev == State.WANDER:
				_show_emote("!")
		State.ATTACK:
			_attack_dir = global_position.direction_to(_player.global_position)
			_lunged = false
		State.HURT:
			sprite.position.x = 0.0
	hitbox.active = next != State.HURT and next != State.DEAD
#endregion


#region sense
func _sees_player() -> bool:
	if _player == null or _player.is_dead():
		return false
	return global_position.distance_to(_player.global_position) <= sense_radius


func _lost_player() -> bool:
	return _player.is_dead() or global_position.distance_to(_player.global_position) > lose_radius
#endregion


#region on_hurt
func _on_hurt(attack: Hitbox) -> void:
	if state == State.DEAD:
		return
	hp -= attack.damage
	# 击退：沿"攻击者 → 自己"的方向给一个初速度，HURT 状态里再慢慢减到 0
	velocity = attack.global_position.direction_to(global_position) * attack.knockback
	_flash()
	if hp <= 0:
		_die()
	else:
		change_state(State.HURT)
		hurtbox.start_invincibility(0.25)     # 一次挥剑只算一下
#endregion


func _flash() -> void:
	var mat := sprite.material as ShaderMaterial
	mat.set_shader_parameter("flash", 1.0)
	create_tween().tween_method(func(v: float) -> void: mat.set_shader_parameter("flash", v), 1.0, 0.0, 0.25)


func _die() -> void:
	change_state(State.DEAD)
	hitbox.active = false
	hurtbox.set_deferred("monitoring", false)
	Game.on_enemy_killed(kind)
	var puff := PUFF.instantiate()
	puff.position = position + Vector2(0, -6)
	get_parent().add_child(puff)
	_drop_loot()
	var tw := create_tween()
	tw.tween_property(self, "velocity", Vector2.ZERO, 0.3)
	tw.parallel().tween_property(sprite, "scale", Vector2(1.4, 0.3), 0.3)
	tw.parallel().tween_property(self, "modulate:a", 0.0, 0.3)
	tw.tween_callback(queue_free)


func _drop_loot() -> void:
	var roll := randf()
	var kind_name := ""
	if kind == &"slime" and roll < 0.35:
		kind_name = "gel"
	elif roll < 0.6:
		kind_name = "coin"
	elif roll < 0.8:
		kind_name = "heart"
	if kind_name == "":
		return
	var p := PICKUP.instantiate()
	p.setup(kind_name)
	p.position = position
	get_parent().add_child.call_deferred(p)


func _show_emote(text: String) -> void:
	emote = text
	_emote_time = 0.8
	queue_redraw()


func _update_visual(delta: float) -> void:
	if absf(velocity.x) > 4.0:
		sprite.flip_h = velocity.x < 0.0
	if flying:
		sprite.position.y = -6.0 + sin(Time.get_ticks_msec() * 0.006) * 2.0
	if _emote_time > 0.0:
		_emote_time -= delta
		if _emote_time <= 0.0:
			emote = ""
			queue_redraw()


func state_name() -> String:
	return State.keys()[state]


## 头顶的像素风 "!" / "?"
func _draw() -> void:
	if emote == "":
		return
	var o := Vector2(-2, -26 if flying else -22)
	draw_rect(Rect2(o + Vector2(-1, -1), Vector2(6, 9)), Color(0.15, 0.12, 0.2))
	var c := Color(1, 0.85, 0.3) if emote == "!" else Color(0.85, 0.9, 1)
	if emote == "!":
		draw_rect(Rect2(o + Vector2(1, 0), Vector2(2, 4)), c)
		draw_rect(Rect2(o + Vector2(1, 5), Vector2(2, 2)), c)
	else:
		draw_rect(Rect2(o + Vector2(0, 0), Vector2(4, 1)), c)
		draw_rect(Rect2(o + Vector2(3, 1), Vector2(1, 2)), c)
		draw_rect(Rect2(o + Vector2(1, 3), Vector2(2, 1)), c)
		draw_rect(Rect2(o + Vector2(1, 4), Vector2(1, 1)), c)
		draw_rect(Rect2(o + Vector2(1, 6), Vector2(1, 1)), c)
