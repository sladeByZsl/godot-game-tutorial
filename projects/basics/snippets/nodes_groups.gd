## 第 2 章片段：分组（groups）。一个节点可以属于任意多个组，组名就是一个字符串。
extends Node

#region groups
func _ready() -> void:
	add_to_group("enemies")                          # 代码里加组；也可以在编辑器"节点 → 分组"里加
	if is_in_group("enemies"):
		print("我是敌人")


func freeze_all_enemies() -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):   # 拿到组里所有节点
		enemy.set_process(false)


func alert_everyone() -> void:
	get_tree().call_group("enemies", "on_alarm")     # 对组里每个节点调用 on_alarm()（没有这个方法的会被跳过）


func find_the_sun() -> Node2D:
	return get_tree().get_first_node_in_group("sun") as Node2D   # 组里的第一个；组是空的就返回 null
#endregion


func on_alarm() -> void:
	print("警报！")
