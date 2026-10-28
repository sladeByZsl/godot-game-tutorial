## 倒下：转一圈变淡，1.5 秒后在起点复活（满血，背包保留）。
extends BaseState

@onready var player := owner as Player


func enter(_msg := {}) -> void:
	player.velocity = Vector2.ZERO
	Game.toast.emit("你倒下了……")
	var tw := player.create_tween()
	tw.tween_property(player.sprite, "rotation", TAU * 0.75, 0.6)
	tw.parallel().tween_property(player.sprite, "modulate:a", 0.3, 0.6)
	tw.tween_interval(0.9)
	tw.tween_callback(func() -> void:
		player.respawn()
		machine.transition_to(&"Move"))


func exit() -> void:
	player.sprite.rotation = 0.0
	player.sprite.modulate.a = 1.0
