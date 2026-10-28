## 挥剑：打开剑的 Hitbox 一小段时间，期间不能走动，结束回到 Move。
#region attack_state
extends BaseState

const DURATION := 0.24
var _time := 0.0

@onready var player := owner as Player


func enter(_msg := {}) -> void:
	_time = 0.0
	player.start_swing()


func physics_update(delta: float) -> void:
	_time += delta
	player.move(delta, Vector2.ZERO)     # 挥剑时滑行减速
	if _time >= DURATION:
		machine.transition_to(&"Move")


func exit() -> void:
	player.end_swing()
#endregion
