## 史莱姆：在地面上来回走，碰到墙、走到平台边缘或前面有尖刺就掉头。
## 玩家从上面踩下来会被消灭；从侧面碰到则玩家受伤。
extends CharacterBody2D

@export var speed := 55.0
@export var gravity := 1400.0

var level: Level
var dir := -1.0
var _dead := false
var _t := randf() * TAU

@onready var hitbox: Area2D = $Hitbox


func _ready() -> void:
	hitbox.body_entered.connect(_on_hitbox_body_entered)


#region patrol
func _physics_process(delta: float) -> void:
	if _dead:
		return
	velocity.y += gravity * delta
	velocity.x = dir * speed
	move_and_slide()
	if is_on_floor() and level:
		var ahead := global_position + Vector2(dir * 14.0, 0)
		# 前方脚下没有实心格子（要掉下去了）或者前方是尖刺 → 掉头
		if not level.is_solid(ahead + Vector2(0, 8)) or level.is_hazard(ahead + Vector2(0, -8)):
			dir = -dir
	if is_on_wall():
		dir = -dir
#endregion


func _process(delta: float) -> void:
	_t += delta * 8.0
	if not _dead:
		$Body.scale = Vector2(1.0 + sin(_t) * 0.06, 1.0 - sin(_t) * 0.06)
		$Body.facing = dir


#region stomp
func _on_hitbox_body_entered(body: Node2D) -> void:
	if _dead or not body is Player or body.dead:
		return
	var player := body as Player
	# 玩家正在下落，并且脚比史莱姆的上半身高 → 算"踩"。
	# 区域的 body_entered 信号会比真正接触晚一两个物理帧，所以判定线放得宽一点（身体中间偏下）。
	if player.velocity.y > 0.0 and player.global_position.y < global_position.y - 3.0:
		_squash_die()
		player.bounce()
	else:
		player.die()


func _squash_die() -> void:
	_dead = true
	set_deferred("collision_layer", 0)
	hitbox.set_deferred("monitoring", false)
	Fx.freeze(Fx.hit_stop)
	Fx.add_trauma(0.35)
	Fx.sparkle(global_position + Vector2(0, -10), Color("#b693ff"), 14)
	var tw := create_tween()
	tw.tween_property($Body, "scale", Vector2(1.6, 0.25), 0.08)
	tw.tween_interval(0.25)
	tw.tween_property($Body, "modulate:a", 0.0, 0.2)
	tw.tween_callback(queue_free)
#endregion
