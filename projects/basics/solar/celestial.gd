## 太阳、地球、月亮共用的脚本。
## 每个天体只做一件事：绕自己的原点旋转。挂在它下面的子节点会被"带着转"，这就是公转。
class_name CelestialBody
extends Node2D

enum Kind { SUN, EARTH, MOON }

@export var kind := Kind.SUN
@export var radius := 40.0

#region params
@export var spin_speed := 20.0          ## 自转速度（度/秒）
@export var distance := 0.0:            ## 离父节点原点多远，也就是本地坐标 position 的长度
	set(value):
		distance = value
		if kind != Kind.SUN:
			var dir := position.normalized() if position != Vector2.ZERO else Vector2.RIGHT
			position = dir * distance
@export var body_scale := 1.0:          ## 缩放。子节点会一起变大变小
	set(value):
		body_scale = value
		scale = Vector2(value, value)
#endregion

@export var show_axes := true:
	set(value):
		show_axes = value
		queue_redraw()

#region detach
## 打开后变成 top_level：不再继承父节点的变换，停在原地，但自己的子节点照样跟着它。
@export var detach := false:
	set(value):
		if value == top_level:
			return
		var keep := global_transform     # 先记住现在在屏幕上的样子
		top_level = value
		global_transform = keep          # 切换后把全局变换还原，避免"瞬移"
		detach = value
#endregion

var _spots: Array[Vector3] = []          # 表面的斑点/陆地/环形山：x, y 是位置，z 是半径


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(kind) * 7 + 3
	var count: int = [6, 5, 7][kind]
	for i in count:
		var a := rng.randf() * TAU
		var d := rng.randf_range(0.15, 0.62) * radius
		_spots.append(Vector3(cos(a) * d, sin(a) * d, rng.randf_range(0.12, 0.26) * radius))


#region spin
func _process(delta: float) -> void:
	rotation += deg_to_rad(spin_speed) * delta   # 只改自己的 rotation，子节点自动跟着转
	queue_redraw()                               # 背光的一面要始终背对太阳，所以每帧重画
#endregion


func _draw() -> void:
	match kind:
		Kind.SUN:
			_draw_sun()
		Kind.EARTH:
			_draw_planet(Color("3d7fd6"), Color("5fbf7a"), Pal.BLUE)
		Kind.MOON:
			_draw_planet(Color("b9c0cf"), Color("8e96a8"), Color("c9cfdb"))
	if show_axes:
		_draw_axes()


func _draw_sun() -> void:
	Pal.glow(self, Vector2.ZERO, radius * 4.2, Color(1.0, 0.62, 0.2, 0.55))
	Pal.glow(self, Vector2.ZERO, radius * 2.0, Color(1.0, 0.85, 0.4, 0.8))
	draw_circle(Vector2.ZERO, radius, Color("ff9f43"), true, -1.0, true)
	draw_circle(Vector2(-radius * 0.12, -radius * 0.12), radius * 0.8, Color("ffb454"), true, -1.0, true)
	draw_circle(Vector2(-radius * 0.22, -radius * 0.22), radius * 0.45, Color("ffd27a"), true, -1.0, true)
	for s in _spots:   # 太阳黑子：跟着自转一起转，能看出转了多少
		draw_circle(Vector2(s.x, s.y), s.z * 0.35, Color(0.9, 0.5, 0.15, 0.55), true, -1.0, true)


func _draw_planet(base: Color, spot: Color, glow: Color) -> void:
	Pal.glow(self, Vector2.ZERO, radius * 2.3, Color(glow, 0.35))
	draw_circle(Vector2.ZERO, radius, base, true, -1.0, true)
	for s in _spots:
		draw_circle(Vector2(s.x, s.y), s.z, spot, true, -1.0, true)
	#region night_side
	# 背对太阳的半边画成夜晚。太阳的方向要换算到本地坐标，因为本节点自己在转。
	var sun := get_tree().get_first_node_in_group("sun") as Node2D
	if sun != null:
		var away := -to_local(sun.global_position).normalized()
		var a := away.angle()
		var pts := PackedVector2Array()
		for i in 25:
			var t := a - PI * 0.5 + PI * i / 24.0
			pts.append(Vector2(cos(t), sin(t)) * (radius + 0.5))
		draw_colored_polygon(pts, Color(0.02, 0.03, 0.08, 0.62))
	#endregion
	draw_arc(Vector2.ZERO, radius, 0, TAU, 48, Color(1, 1, 1, 0.25), 1.0, true)


## 本地坐标轴：x 红、y 绿。画在本地坐标系里，所以会跟着节点一起转、一起缩放。
func _draw_axes() -> void:
	var l := radius + 24.0
	Pal.arrow(self, Vector2.ZERO, Vector2(l, 0), Pal.AXIS_X, 2.0, 9.0)
	Pal.arrow(self, Vector2.ZERO, Vector2(0, l), Pal.AXIS_Y, 2.0, 9.0)
	draw_circle(Vector2.ZERO, 3.0, Color.WHITE, true, -1.0, true)


## 屏幕上显示的标签文字（由 Solar 画在最上层，避免被别的天体挡住）。
func label_lines() -> PackedStringArray:
	var lines := PackedStringArray([String(name)])
	if show_axes and kind != Kind.SUN:
		lines.append("position (%d, %d)" % [roundi(position.x), roundi(position.y)])
	return lines
