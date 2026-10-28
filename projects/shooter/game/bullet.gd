## 子弹。它自己不写 _physics_process：所有活动子弹由 BulletPool 在一个循环里统一移动，
## 几百颗子弹各跑一次脚本回调，比一个循环慢得多。
class_name Bullet
extends Area2D

enum Kind { PINK, ORANGE, VIOLET, RICE, BIG, PLAYER }

const TEXTURES := {
	Kind.PINK: preload("res://art/bullet_pink.png"),
	Kind.ORANGE: preload("res://art/bullet_orange.png"),
	Kind.VIOLET: preload("res://art/bullet_violet.png"),
	Kind.RICE: preload("res://art/bullet_rice.png"),
	Kind.BIG: preload("res://art/bullet_big.png"),
	Kind.PLAYER: preload("res://art/shot_player.png"),
}
const HIT_SCALE := {Kind.BIG: 2.2}   # 大玉的判定圈放大；其余用场景里的半径

var velocity := Vector2.ZERO
var accel := 0.0          ## 沿速度方向的加速度（负数 = 先快后慢）
var turn := 0.0           ## 每秒转过的角度（弧度），弯曲弹道
var damage := 1
@export var kind := Kind.PINK
var active := false       ## false = 已回收（或正在回收），碰撞回调要忽略
var from_pool := false    ## 由池管理的子弹回收时放回池里，否则 queue_free
var pool: BulletPool

@onready var sprite: Sprite2D = $Sprite
@onready var shape: CollisionShape2D = $Shape


func _ready() -> void:
	if monitoring:                     # 只有玩家子弹需要"检测"敌人
		area_entered.connect(_on_area_entered)


#region setup
## 每次从池里取出（或新建）后调用，把所有状态重置一遍——池化对象最容易出的 bug 就是"带着上一条命的状态"。
func setup(pos: Vector2, vel: Vector2, k: Kind) -> void:
	position = pos
	velocity = vel
	accel = 0.0
	turn = 0.0
	damage = 1
	if k != kind or sprite.texture == null:
		kind = k
		sprite.texture = TEXTURES[k]
		shape.scale = Vector2.ONE * HIT_SCALE.get(k, 1.0)
	rotation = vel.angle() if k == Kind.RICE or k == Kind.PLAYER else 0.0
#endregion


#region hit
func _on_area_entered(area: Area2D) -> void:
	if not active:
		return
	if area.has_method("take_hit"):
		area.take_hit(damage, global_position)
		pool.release(self)
#endregion
