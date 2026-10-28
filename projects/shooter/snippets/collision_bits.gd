## 碰撞层的位运算（第 13 章用的语法片段）。
## collision_layer / collision_mask 都是 32 位整数，第 n 层对应二进制的第 n-1 位：1 << (n - 1)。
extends Node

#region bits
const PLAYER := 1 << 0          # 第 1 层 → 0b00001 = 1
const PLAYER_BULLET := 1 << 1   # 第 2 层 → 0b00010 = 2
const ENEMY := 1 << 2           # 第 3 层 → 0b00100 = 4
const ENEMY_BULLET := 1 << 3    # 第 4 层 → 0b01000 = 8
const PICKUP := 1 << 4          # 第 5 层 → 0b10000 = 16


func setup_player_hurtbox(area: Area2D) -> void:
	area.collision_layer = PLAYER                 # 我是谁：玩家
	area.collision_mask = ENEMY | ENEMY_BULLET    # 我检测谁：敌人和敌弹，4 | 8 = 12
	# 也可以按层号（从 1 开始）逐个开关，不用自己算位：
	area.set_collision_mask_value(5, false)       # 不检测道具
	print(area.get_collision_mask_value(4))       # true


## "A 能发现 B" 的条件：A 的 mask 和 B 的 layer 至少有一位相同。
static func detects(a_mask: int, b_layer: int) -> bool:
	return (a_mask & b_layer) != 0
#endregion
