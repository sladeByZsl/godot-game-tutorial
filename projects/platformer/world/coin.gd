## 金币：自己旋转、上下浮动；玩家碰到后弹起、闪光、淡出。
extends Area2D

var _t := randf() * TAU
var _taken := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	if _taken:
		return
	_t += delta
	position.y += sin(_t * 3.0) * 0.15
	scale.x = cos(_t * 2.5)          # 横向缩放在 -1~1 之间变化，看起来像在转
	queue_redraw()


func _draw() -> void:
	var edge := Color("#b8741a")
	draw_circle(Vector2.ZERO, 10.0, edge, true, -1.0, true)
	draw_circle(Vector2.ZERO, 8.5, Color("#ffc93c"), true, -1.0, true)
	draw_circle(Vector2.ZERO, 5.5, Color("#ffe48a"), true, -1.0, true)
	draw_rect(Rect2(-1.2, -4, 2.4, 8), edge)
	draw_circle(Vector2(-3.5, -4), 1.6, Color(1, 1, 1, 0.9), true, -1.0, true)


#region collect
func _on_body_entered(body: Node2D) -> void:
	if _taken or not body is Player:
		return
	_taken = true
	body.collect_coin()
	Fx.sparkle(global_position, Color("#ffd84a"))
	set_deferred("monitoring", false)
	scale = Vector2.ONE
	# 并行：同时往上飘、放大、淡出；结束后删除自己
	var tw := create_tween().set_parallel()
	tw.tween_property(self, "position:y", position.y - 28.0, 0.35) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", Vector2(1.6, 1.6), 0.35) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate:a", 0.0, 0.2).set_delay(0.15)
	tw.chain().tween_callback(queue_free)
#endregion
