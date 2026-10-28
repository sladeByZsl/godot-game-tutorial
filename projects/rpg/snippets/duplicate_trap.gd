## 共享资源的坑：两个节点 @export 了同一份 .tres，改一个，另一个也跟着变。
extends Node

@export var data: EnemyData   # 在检查器里给两只史莱姆拖了同一个 slime_data.tres


#region trap
func take_damage_wrong(amount: int) -> void:
	# 错误：data 是所有史莱姆共享的同一个对象，这一刀砍在了"全体史莱姆"身上
	data.hp -= amount
#endregion


#region fix_duplicate
func _ready() -> void:
	# 修法一：拿到资源后复制一份私有的。duplicate() 默认是浅复制，
	# 资源里如果还嵌着别的资源（数组、子资源），要用 duplicate(true) 或 duplicate_deep()
	data = data.duplicate()
	data.hp = data.max_hp
#endregion


#region fix_split
# 修法二（更推荐）：资源只放不会变的数据，会变的状态放在节点自己身上
var hp := 0


func setup() -> void:
	hp = data.max_hp


func take_damage(amount: int) -> void:
	hp -= amount
#endregion
