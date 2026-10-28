## 宝箱：鼠标点它就打开，发出 opened 信号，过一会儿自动关上。
class_name Chest
extends Node2D

#region opened
signal opened(gold: int)

@export var gold := 10          ## 每次开箱给多少金币
@export var cooldown := 1.0     ## 打开后多久自动关上（秒）

var is_open := false


func open() -> void:
	if is_open:
		return
	is_open = true
	opened.emit(gold)
	_burst()
	await get_tree().create_timer(cooldown).timeout   # 等计时器的 timeout 信号，期间不会卡住游戏
	is_open = false
#endregion

var _lid := 0.0                  # 盖子角度 0 → 1
var _coins: Array[Dictionary] = []
var _hover := false


func viz_rect() -> Rect2:
	return Rect2(global_position - Vector2(38, 34), Vector2(76, 66))


func _unhandled_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		if Rect2(-38, -34, 76, 66).has_point(get_local_mouse_position()):
			open()
			get_viewport().set_input_as_handled()


func _burst() -> void:
	for i in 9:
		var a := randf_range(-PI * 0.85, -PI * 0.15)
		_coins.append({"p": Vector2(0, -6), "v": Vector2(cos(a), sin(a)) * randf_range(140, 260), "life": 1.0})


func _process(delta: float) -> void:
	_lid = move_toward(_lid, 1.0 if is_open else 0.0, delta * 5.0)
	_hover = Rect2(-38, -34, 76, 66).has_point(get_local_mouse_position())
	for c in _coins:
		c.v.y += 520.0 * delta
		c.p += c.v * delta
		c.life -= delta * 1.1
	_coins = _coins.filter(func(c: Dictionary) -> bool: return c.life > 0.0)
	queue_redraw()


func _draw() -> void:
	var wood := Color("a8642f")
	var band := Color("f2c14e")
	draw_set_transform(Vector2(0, 30), 0.0, Vector2(1.0, 0.22))
	draw_circle(Vector2.ZERO, 36.0, Color(0, 0, 0, 0.35), true, -1.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if _lid > 0.0:
		Pal.glow(self, Vector2(0, -8), 70.0, Color(1.0, 0.8, 0.3, 0.7 * _lid))
	if _hover and not is_open:
		Pal.glow(self, Vector2(0, 0), 60.0, Color(1.0, 0.85, 0.4, 0.25))
	# 箱体
	Pal.panel(self, Rect2(-32, -6, 64, 34), wood, wood.darkened(0.45), 5, 2)
	draw_rect(Rect2(-32, 4, 64, 5), band.darkened(0.15))
	draw_rect(Rect2(-5, -6, 10, 34), band)
	# 盖子：绕后方的铰链往上翻
	var hinge := Vector2(0, -6)
	var ang := -_lid * 1.9
	var lid := PackedVector2Array([Vector2(-32, 0), Vector2(32, 0), Vector2(30, -14), Vector2(18, -20), Vector2(-18, -20), Vector2(-30, -14)])
	var squash := cos(ang)
	for i in lid.size():
		lid[i] = hinge + Vector2(lid[i].x, lid[i].y * squash)
	draw_colored_polygon(lid, wood.lightened(0.12))
	draw_polyline(lid + PackedVector2Array([lid[0]]), wood.darkened(0.45), 2.0, true)
	draw_rect(Rect2(-5, hinge.y - 20.0 * absf(squash), 10, 20.0 * absf(squash)), band)
	for c in _coins:
		draw_circle(c.p, 4.5, Color(band, clampf(c.life * 2.0, 0, 1)), true, -1.0, true)
		draw_circle(c.p + Vector2(-1, -1), 2.0, Color(1, 1, 0.8, clampf(c.life * 2.0, 0, 1)), true, -1.0, true)
