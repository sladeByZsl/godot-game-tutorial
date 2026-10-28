## 一段对话 = 若干台词 + 触发条件 + 播完后的效果。全部用数据描述，NPC 脚本不写剧情。
#region dialogue
class_name Dialogue
extends Resource

@export var require_flag := ""            ## 只有这个标记为真时才会被选中（空 = 无条件）
@export var lines: Array[DialogueLine] = []
@export var flag_on_finish := ""          ## 播完后设置的标记
@export var reward_coins := 0
@export var reward_max_hp := 0            ## 增加的血量上限（半颗心为 1）
#endregion
