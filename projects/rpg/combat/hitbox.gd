## 攻击判定区域（剑、敌人的身体）。它自己不检测任何东西，只"被" Hurtbox 看见。
## 碰撞层放在 player_attack 或 enemy_attack，monitoring 关掉。
#region hitbox
class_name Hitbox
extends Area2D

@export var damage := 1
@export var knockback := 120.0     ## 击退初速度（像素/秒）
@export var active := true:        ## 关掉时 Hurtbox 会忽略它（比如剑没挥出来、敌人正在受伤）
	set(v):
		active = v
		for c in get_children():
			if c is CollisionShape2D:
				c.set_deferred("disabled", not v)


func _ready() -> void:
	monitoring = false
	active = active
#endregion
