## 受伤：被击退一小段距离，期间不能操作。
#region hurt_state
extends BaseState

const DURATION := 0.22
var _time := 0.0

@onready var player := owner as Player


func enter(msg := {}) -> void:
	_time = 0.0
	player.velocity = msg.get("knockback", Vector2.ZERO)


func physics_update(delta: float) -> void:
	_time += delta
	player.velocity = player.velocity.move_toward(Vector2.ZERO, 900.0 * delta)
	player.move_and_slide()
	if _time >= DURATION:
		machine.transition_to(&"Move")
#endregion
