## 行走 / 站立。读方向键移动，按攻击进入 Attack，按交互找身边的 NPC 或宝箱。
#region move_state
extends BaseState

@onready var player := owner as Player


func physics_update(delta: float) -> void:
	player.move(delta, player.get_input_vector())
	player.play_walk_animation()


func handle_input(event: InputEvent) -> void:
	if event.is_action_pressed("attack") and player.can_attack():
		machine.transition_to(&"Attack")
	elif event.is_action_pressed("interact"):
		player.try_interact()
#endregion
