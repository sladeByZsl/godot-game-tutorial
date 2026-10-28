## 第 2 章片段：组合优于继承。
## "血量"做成一个独立的小节点，玩家、敌人、木箱都可以挂一个，而不用共用一个巨大的父类。
extends Node

#region composition
signal died

@export var max_health := 100
var health := max_health


func take_damage(amount: int) -> void:
	health = maxi(health - amount, 0)
	if health == 0:
		died.emit()
#endregion

## 用法（写在玩家或敌人的脚本里）：
##   @onready var health: Node = $Health
##   func _on_hit(dmg: int) -> void:
##       health.take_damage(dmg)
