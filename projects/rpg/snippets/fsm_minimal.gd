## 最小的 enum + match 状态机，只有三个状态。完整版见 enemies/enemy.gd。
extends CharacterBody2D

#region fsm_minimal
enum State { IDLE, CHASE, HURT }

var state := State.IDLE
var target: Node2D


func _physics_process(_delta: float) -> void:
	match state:
		State.IDLE:
			velocity = Vector2.ZERO
			if target and position.distance_to(target.position) < 64.0:
				state = State.CHASE
		State.CHASE:
			velocity = position.direction_to(target.position) * 50.0
		State.HURT:
			velocity *= 0.9
	move_and_slide()
#endregion
