## 用代码画出主角：一个圆滚滚的小团子，头顶一片嫩芽。
## 下面这些属性都可以被 AnimationPlayer 当作轨道来做关键帧（脚的位置、眨眼、嫩芽摆动），
## setter 里调用 queue_redraw()，属性一变就重画。
@tool
class_name PlayerBody
extends Node2D

enum Face { NORMAL, HAPPY, SURPRISED, HURT }

const OUTLINE := Color("#5b2a24")
const SKIN := Color("#ff8a65")
const BELLY := Color("#ffd2b8")
const CHEEK := Color("#ff5e7a")
const LEAF := Color("#7ed957")

#region anim_props
@export var foot_l := Vector2(-6, 12):
	set(v):
		foot_l = v
		queue_redraw()
@export var foot_r := Vector2(6, 12):
	set(v):
		foot_r = v
		queue_redraw()
@export_range(0.0, 1.0) var blink := 0.0:
	set(v):
		blink = v
		queue_redraw()
@export var sprout_angle := 0.0:
	set(v):
		sprout_angle = v
		queue_redraw()
#endregion

var expression := Face.NORMAL:
	set(v):
		if v != expression:
			expression = v
			queue_redraw()
var look := Vector2.ZERO:       ## 眼睛看的方向（-1~1），由 player.gd 每帧设置
	set(v):
		look = v
		queue_redraw()

var _box := StyleBoxFlat.new()


func _init() -> void:
	_box.bg_color = SKIN
	_box.border_color = OUTLINE
	_box.set_border_width_all(2)
	_box.set_corner_radius_all(12)
	_box.anti_aliasing = true


func _draw() -> void:
	# 脚（画在身体后面）
	_ellipse(foot_l, 5.0, 3.6, OUTLINE)
	_ellipse(foot_r, 5.0, 3.6, OUTLINE)
	_ellipse(foot_l + Vector2(0, -0.6), 3.4, 2.2, SKIN.darkened(0.25))
	_ellipse(foot_r + Vector2(0, -0.6), 3.4, 2.2, SKIN.darkened(0.25))
	_draw_sprout()
	# 身体
	_box.draw(get_canvas_item(), Rect2(-14, -13, 28, 26))
	_ellipse(Vector2(0, 5), 9.0, 6.0, BELLY)
	_ellipse(Vector2(-7.5, -7.5), 3.2, 2.0, Color(1, 1, 1, 0.55))
	# 腮红
	_ellipse(Vector2(-9, 1) + look * 1.5, 2.6, 1.6, Color(CHEEK, 0.55))
	_ellipse(Vector2(9, 1) + look * 1.5, 2.6, 1.6, Color(CHEEK, 0.55))
	_draw_face()


func _draw_face() -> void:
	var off := look * Vector2(2.5, 1.5)
	var el := Vector2(-5, -3) + off
	var er := Vector2(5, -3) + off
	match expression:
		Face.HAPPY:
			draw_arc(el + Vector2(0, 1.5), 3.0, PI * 1.1, PI * 1.9, 8, OUTLINE, 2.0, true)
			draw_arc(er + Vector2(0, 1.5), 3.0, PI * 1.1, PI * 1.9, 8, OUTLINE, 2.0, true)
			var m := Vector2(0, 4) + off
			draw_colored_polygon(_arc_points(m, 3.6, 0.0, PI), OUTLINE)
			_ellipse(m + Vector2(0, 2.0), 1.8, 1.0, CHEEK)
		Face.SURPRISED:
			_ellipse(el, 3.0, 3.6, OUTLINE)
			_ellipse(er, 3.0, 3.6, OUTLINE)
			_ellipse(el + Vector2(-0.9, -1.2), 1.1, 1.1, Color.WHITE)
			_ellipse(er + Vector2(-0.9, -1.2), 1.1, 1.1, Color.WHITE)
			_ellipse(Vector2(0, 5) + off, 1.8, 2.3, OUTLINE)
		Face.HURT:
			for e: Vector2 in [el, er]:
				draw_line(e + Vector2(-2.5, -2.5), e + Vector2(2.5, 2.5), OUTLINE, 2.0, true)
				draw_line(e + Vector2(-2.5, 2.5), e + Vector2(2.5, -2.5), OUTLINE, 2.0, true)
			var w := PackedVector2Array()
			for i in 6:
				w.append(Vector2(-4.0 + i * 1.6, 5.0 + (1.0 if i % 2 else -0.5)) + off)
			draw_polyline(w, OUTLINE, 1.5, true)
		_:
			var h := lerpf(3.4, 0.4, blink)
			_ellipse(el, 2.3, h, OUTLINE)
			_ellipse(er, 2.3, h, OUTLINE)
			if blink < 0.5:
				_ellipse(el + Vector2(-0.7, -1.2), 0.9, 0.9, Color.WHITE)
				_ellipse(er + Vector2(-0.7, -1.2), 0.9, 0.9, Color.WHITE)
			draw_arc(Vector2(0, 2.5) + off, 2.4, PI * 0.15, PI * 0.85, 8, OUTLINE, 1.5, true)


func _draw_sprout() -> void:
	var base := Vector2(0, -12)
	var dir := Vector2.UP.rotated(sprout_angle)
	var tip := base + dir * 8.0
	draw_line(base, tip, Color("#3f7d2c"), 2.0, true)
	var side := dir.orthogonal()
	for s: float in [-1.0, 1.0]:
		var c := tip + side * s * 3.5 + dir * 1.0
		var leaf := PackedVector2Array()
		for i in 12:
			var a := TAU * i / 12.0
			leaf.append(c + side * cos(a) * 4.0 + dir * sin(a) * 2.2)
		draw_colored_polygon(leaf, LEAF.darkened(0.15 if s > 0 else 0.0))
		leaf.append(leaf[0])
		draw_polyline(leaf, Color("#3f7d2c"), 1.2, true)


func _ellipse(c: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 16:
		var a := TAU * i / 16.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, col)


func _arc_points(c: Vector2, r: float, from: float, to: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 11:
		var a := lerpf(from, to, i / 10.0)
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	return pts
