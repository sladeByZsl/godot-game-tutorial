## 移动平台：AnimatableBody2D + 循环 Tween。
## sync_to_physics 打开后，引擎会把这一帧的位移当作速度，站在上面的 CharacterBody2D 会被一起带走。
extends AnimatableBody2D

const TILES := preload("res://art/tiles.png")

@export var width_tiles := 3
@export var travel := Vector2(160, 0)     ## 从起点移动到哪里（相对位移）
@export var duration := 2.0               ## 单程时间（秒）


#region move
func _ready() -> void:
	var shape := RectangleShape2D.new()
	shape.size = Vector2(width_tiles * 32, 10)
	$Collision.shape = shape
	$Collision.position = Vector2(width_tiles * 16, 5)
	var start := position
	var tw := create_tween().set_loops()
	tw.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)   # 在物理帧里移动，和角色的碰撞同步
	tw.tween_property(self, "position", start + travel, duration) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_interval(0.4)
	tw.tween_property(self, "position", start, duration) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_interval(0.4)
#endregion


func _draw() -> void:
	# 直接从瓦片图集里截取木平台的左端、中间、右端来画
	for i in width_tiles:
		var col := 2
		if i == 0:
			col = 1
		elif i == width_tiles - 1:
			col = 3
		draw_texture_rect_region(TILES, Rect2(i * 32, 0, 32, 32), Rect2(col * 32, 4 * 32, 32, 32))
