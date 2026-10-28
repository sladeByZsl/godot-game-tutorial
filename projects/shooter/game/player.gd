## 玩家飞船。根节点是 Area2D：射击游戏不需要"撞墙滑动"之类的物理响应，只需要知道"碰到了什么"。
## 判定点（Hurtbox，就是根节点上的小圆）只有 4 像素，比飞船画出来小得多——弹幕游戏的惯例。
## 另有一个大一圈的 PickupArea 专门吸道具：两个 Area2D 用不同的 mask，各管各的。
class_name Player
extends Area2D

signal hit
signal bomb_requested

#region params
@export var move_speed := 330.0       ## 移动速度（像素/秒），按住低速键时减半
@export var fire_rate := 12.0         ## 每秒发射几轮
@export var bullet_speed := 900.0     ## 子弹速度（像素/秒）
@export var spread_angle := 14.0      ## 散射：整把扇形张开的角度（度）
@export var bullet_count := 3         ## 每轮几颗（火力升级还会再加）
@export var auto_fire := false        ## 不用按键，自动射击
@export var invincible := false       ## 无敌模式（测试用）
#endregion

const FIELD := Rect2(14, 20, 572, 506)   # 能移动的范围（Field 局部坐标）
const MAX_POWER := 3

var game: Game
var power := 0
var shield := false
var autopilot := false
var _cooldown := 0.0
var _invul := 0.0
var _t := 0.0
var _focus := false
var _tilt := 0.0

@onready var pickup_area: Area2D = $PickupArea


func _ready() -> void:
	Tuning.bind(self, "player", ["move_speed", "fire_rate", "bullet_speed", "spread_angle",
		"bullet_count", "auto_fire", "invincible"])
	area_entered.connect(_on_area_entered)
	pickup_area.area_entered.connect(_on_pickup)


func _physics_process(delta: float) -> void:
	_t += delta
	_invul = maxf(0.0, _invul - delta)
	#region move
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if autopilot:
		dir = _autopilot_dir()
	_focus = Input.is_action_pressed("focus")
	var spd := move_speed * (0.5 if _focus else 1.0)
	position += dir * spd * delta              # get_vector 已经把斜向长度归一化到 1，斜着走不会更快
	position = position.clamp(FIELD.position, FIELD.end)
	_tilt = lerpf(_tilt, dir.x, 1.0 - exp(-10.0 * delta))
	#endregion
	_cooldown -= delta
	if (Input.is_action_pressed("shoot") or auto_fire or autopilot) and _cooldown <= 0.0:
		_cooldown = 1.0 / fire_rate
		_fire()
	if Input.is_action_just_pressed("bomb"):
		bomb_requested.emit()
	visible = _invul <= 0.0 or fmod(_t, 0.12) < 0.07     # 无敌时闪烁
	queue_redraw()


#region fire
## 一轮射出 n 颗，在正上方（-PI/2）两侧均匀展开 spread_angle 度。
func _fire() -> void:
	var n := bullet_count + power
	var spread := deg_to_rad(spread_angle) * (1.0 + 0.15 * power)
	for i in n:
		var t := 0.0 if n == 1 else float(i) / (n - 1) - 0.5
		var angle := -PI / 2 + t * spread
		var muzzle := position + Vector2((t * 18.0), -14.0)
		game.player_bullets.spawn(muzzle, Vector2.from_angle(angle) * bullet_speed, Bullet.Kind.PLAYER)
	Audio.play("shoot", -8.0)
#endregion


#region hurt
func _on_area_entered(area: Area2D) -> void:
	if area is Bullet:
		if not area.active:
			return
		area.pool.release(area)               # 敌弹撞到玩家就消失
	elif not (area is Enemy or area is Boss):
		return
	if invincible or _invul > 0.0:
		return
	if shield:
		shield = false
		_invul = 1.0
		game.fx.ring(position, Color(0.4, 1.8, 2.4), 70.0)
		Audio.play("hurt", -6.0)
		return
	_invul = 2.5
	hit.emit()
#endregion


func _on_pickup(area: Area2D) -> void:
	if area is Pickup:
		area.collect(self)


func add_power() -> void:
	power = mini(power + 1, MAX_POWER)


func set_invulnerable(seconds: float) -> void:
	_invul = maxf(_invul, seconds)


func _autopilot_dir() -> Vector2:
	var target := Vector2(300.0 + sin(_t * 0.9) * 210.0, 440.0 + sin(_t * 1.7) * 30.0)
	if is_instance_valid(game.boss):           # 有 Boss 时跟着它左右移动
		target.x = game.boss.position.x + sin(_t * 1.3) * 50.0
	var d := target - position
	return d.normalized() if d.length() > 4.0 else Vector2.ZERO


func _draw() -> void:
	var cyan := Color(0.4, 1.8, 2.4)
	var w := 13.0 * (1.0 - absf(_tilt) * 0.25)
	var hull := PackedVector2Array([Vector2(0, -18), Vector2(w * 0.45, -4), Vector2(w, 10),
		Vector2(w * 0.35, 7), Vector2(0, 12), Vector2(-w * 0.35, 7), Vector2(-w, 10),
		Vector2(-w * 0.45, -4), Vector2(0, -18)])
	# 引擎尾焰：长度随时间抖动
	var flame := 9.0 + sin(_t * 47.0) * 3.0 + randf() * 2.0
	draw_colored_polygon(PackedVector2Array([Vector2(-4, 9), Vector2(4, 9), Vector2(0, 9 + flame)]),
		Color(2.4, 1.2, 0.4, 0.9))
	draw_colored_polygon(hull.slice(0, -1), Color(0.02, 0.08, 0.12, 0.95))
	draw_polyline(hull, Color(cyan, 0.25), 6.0, true)
	draw_polyline(hull, cyan, 2.0, true)
	draw_circle(Vector2(0, -3), 3.0, Color(1.6, 1.6, 2.0))
	if shield:
		draw_arc(Vector2.ZERO, 26.0 + sin(_t * 6.0) * 1.5, 0, TAU, 40, Color(0.4, 1.6, 2.4, 0.7), 2.0, true)
	if _focus:     # 低速模式下显示真实判定点
		draw_circle(Vector2.ZERO, 5.0, Color(2.0, 2.0, 2.0))
		draw_circle(Vector2.ZERO, 3.0, Color(2.2, 0.3, 0.5))
