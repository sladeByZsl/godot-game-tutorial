## 显示碰撞形状。编辑器里有"调试 → 显示碰撞区域"（SceneTree.debug_collisions_hint），
## 但它只在调试版本里有效，导出的 Web 版看不到，所以这里自己画：把每个 Area2D 的圆形判定画出来。
extends Node2D

var game: Game


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _draw() -> void:
	var col_player := Color(0.3, 1.0, 0.4)
	var col_enemy := Color(1.0, 0.3, 0.3)
	_draw_area(game.player, col_player)
	_draw_area(game.player.pickup_area, Color(0.3, 1.0, 0.4, 0.35))
	for b in game.player_bullets.active:
		if b.active:
			_draw_area(b, Color(0.4, 0.8, 1.0))
	for b in game.enemy_bullets.active:
		if b.active:
			_draw_area(b, col_enemy)
	for e in get_tree().get_nodes_in_group("enemies"):
		_draw_area(e, Color(1.0, 0.6, 0.2))
	if is_instance_valid(game.boss):
		_draw_area(game.boss, Color(1.0, 0.6, 0.2))


func _draw_area(area: Area2D, col: Color) -> void:
	for child in area.get_children():
		var cs := child as CollisionShape2D
		if cs and cs.shape is CircleShape2D:
			var r: float = cs.shape.radius * cs.global_scale.x
			var p := to_local(cs.global_position)
			draw_arc(p, absf(r), 0, TAU, 20, col, 1.0)
			draw_circle(p, absf(r), Color(col, 0.18))
