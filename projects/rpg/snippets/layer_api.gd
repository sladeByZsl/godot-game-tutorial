## 碰撞层 / 遮罩在代码里怎么改。层号从 1 开始数，和检查器、project.godot 里的名字一致。
extends CharacterBody2D


#region layer_api
func _ready() -> void:
	collision_layer = 0
	set_collision_layer_value(3, true)    # 我在第 3 层 player
	collision_mask = 0b11                 # 我会撞到第 1 层 world 和第 2 层 water
	print(get_collision_mask_value(2))    # true


func become_ghost() -> void:
	set_collision_mask_value(2, false)    # 不再被水挡住（像蝙蝠一样）
#endregion
