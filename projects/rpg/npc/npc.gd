## 会说话的 NPC。剧情全在 dialogues 数组里（.tres 资源），脚本只负责挑一段来播。
extends StaticBody2D

@export var npc_name := "村民"
## 按顺序检查，第一个满足 require_flag 的对话会被播放。把条件最苛刻的放最前面。
@export var dialogues: Array[Dialogue] = []


func can_interact() -> bool:
	return pick_dialogue() != null


func interact_label() -> String:
	return "交谈"


func interact(_player: Player) -> void:
	var d := pick_dialogue()
	if d:
		Game.dialogue_requested.emit(d)


#region pick
func pick_dialogue() -> Dialogue:
	for d in dialogues:
		if d.require_flag == "" or Game.has_flag(d.require_flag):
			return d
	return null
#endregion
