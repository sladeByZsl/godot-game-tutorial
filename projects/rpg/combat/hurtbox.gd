## 受击区域。它负责检测：mask 里勾上对方攻击所在的层，碰到 Hitbox 就发出 hurt 信号。
## 无敌帧期间忽略攻击；无敌结束时如果还站在攻击范围里，会立刻再判一次。
#region hurtbox
class_name Hurtbox
extends Area2D

signal hurt(hitbox: Hitbox)

var invincible := false


func _ready() -> void:
	monitorable = false
	area_entered.connect(_on_area_entered)


func _on_area_entered(area: Area2D) -> void:
	if area is Hitbox and area.active and not invincible:
		hurt.emit(area)


## 开启无敌 seconds 秒。期间别人打不到，结束后重新检查一次重叠。
func start_invincibility(seconds: float) -> void:
	invincible = true
	await get_tree().create_timer(seconds, false).timeout
	invincible = false
	for area in get_overlapping_areas():
		if area is Hitbox and area.active:
			hurt.emit(area)
			break
#endregion
