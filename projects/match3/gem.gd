## 一颗宝石的"表现"：只负责画出来和做动画，不知道自己在棋盘的哪一格，也不参与任何判断。
## 画法全部用 _draw()：阴影 → 渐变底色 → 描边 → 内切面 → 高光，特殊宝石再叠一层标记。
class_name Gem
extends Node2D

const COLORS: Array[Color] = [
	Color("#ef4f64"),   # 红：圆
	Color("#f79a3c"),   # 橙：圆角方
	Color("#f6d04d"),   # 黄：星
	Color("#43c97e"),   # 绿：六边形
	Color("#3d8cf2"),   # 蓝：菱形
	Color("#a65ee8"),   # 紫：三角
	Color("#4fd3d6"),   # 青：五边形
]

var kind := 0
var special := 0
var radius := 26.0
var _t := 0.0


func setup(k: int, sp: int, r: float) -> void:
	kind = k
	special = sp
	radius = r
	set_process(special != Board.Special.NONE)
	queue_redraw()


func set_special(k: int, sp: int) -> void:
	setup(k, sp, radius)


static func color_of(k: int) -> Color:
	return COLORS[k % COLORS.size()] if k >= 0 and k != Board.RAINBOW else Color("#e8e4ff")


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


#region shapes
## 每种颜色一个形状：色盲玩家也能靠形状区分。
static func shape_points(k: int, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	match k % 7:
		0:  # 圆
			for i in 28:
				pts.append(Vector2.from_angle(TAU * i / 28.0) * r * 0.92)
		1:  # 圆角方
			var s := r * 0.78
			var c := r * 0.22
			for corner: Vector2 in [Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1), Vector2(-1, -1)]:
				var center := corner * (s - c)
				var a0 := corner.angle() - PI / 4.0
				for i in 5:
					pts.append(center + Vector2.from_angle(a0 + PI / 2.0 * i / 4.0) * c)
		2:  # 五角星
			for i in 10:
				var rr := r * (0.98 if i % 2 == 0 else 0.48)
				pts.append(Vector2.from_angle(-PI / 2.0 + TAU * i / 10.0) * rr)
		3:  # 六边形
			for i in 6:
				pts.append(Vector2.from_angle(TAU * i / 6.0) * r * 0.92)
		4:  # 菱形
			pts.append_array([Vector2(0, -r), Vector2(r * 0.78, 0), Vector2(0, r), Vector2(-r * 0.78, 0)])
		5:  # 三角
			for i in 3:
				pts.append(Vector2.from_angle(-PI / 2.0 + TAU * i / 3.0) * r * 1.02 + Vector2(0, r * 0.14))
		_:  # 五边形
			for i in 5:
				pts.append(Vector2.from_angle(-PI / 2.0 + TAU * i / 5.0) * r * 0.95)
	return pts
#endregion


#region draw
func _draw() -> void:
	if kind == Board.RAINBOW:
		_draw_rainbow()
		return
	var base := color_of(kind)
	var pts := shape_points(kind, radius)
	# 1. 阴影：同一个形状往下偏一点，半透明黑色
	var shadow := PackedVector2Array()
	for p in pts:
		shadow.append(p + Vector2(0, radius * 0.14))
	draw_colored_polygon(shadow, Color(0, 0, 0, 0.32))
	# 2. 底色：每个顶点按高度取色，上亮下暗，GPU 会在三角形内部插值成渐变
	var cols := PackedColorArray()
	for p in pts:
		var t := clampf((p.y / radius + 1.0) * 0.5, 0.0, 1.0)
		cols.append(base.lightened(0.28).lerp(base.darkened(0.32), t))
	draw_polygon(pts, cols)
	# 3. 描边
	var outline := pts.duplicate()
	outline.append(pts[0])
	draw_polyline(outline, base.darkened(0.5), maxf(1.5, radius * 0.07), true)
	# 4. 内切面：缩小的同形状，略微上移，更亮更透明，看起来像切割过的宝石面
	var facet := PackedVector2Array()
	for p in pts:
		facet.append(p * 0.56 + Vector2(0, -radius * 0.06))
	draw_colored_polygon(facet, Color(base.lightened(0.45), 0.55))
	# 5. 高光：左上角一个斜椭圆 + 一个小亮点
	draw_set_transform(Vector2(-radius * 0.3, -radius * 0.38), -0.6, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, radius * 0.24, Color(1, 1, 1, 0.55), true, -1.0, true)
	draw_set_transform(Vector2.ZERO)
	draw_circle(Vector2(radius * 0.32, radius * 0.3), radius * 0.07, Color(1, 1, 1, 0.45), true, -1.0, true)
	_draw_special_mark()


func _draw_special_mark() -> void:
	var white := Color(1, 1, 1, 0.92)
	match special:
		Board.Special.LINE_H, Board.Special.LINE_V:
			# 两道白色条纹 + 两端箭头，竖向的就把坐标系转 90°
			if special == Board.Special.LINE_V:
				draw_set_transform(Vector2.ZERO, PI / 2.0)
			var w := radius * 0.95
			var glow := 0.5 + 0.5 * sin(_t * 6.0)
			for off in [-radius * 0.2, radius * 0.2]:
				draw_line(Vector2(-w * 0.7, off), Vector2(w * 0.7, off), white, radius * 0.12, true)
			for s in [-1.0, 1.0]:
				var tip := Vector2(s * (w + radius * 0.12), 0)
				draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-s * radius * 0.3, -radius * 0.24),
						tip + Vector2(-s * radius * 0.3, radius * 0.24)]), Color(1, 1, 1, 0.6 + 0.4 * glow))
			draw_set_transform(Vector2.ZERO)
		Board.Special.BOMB:
			var pulse := 0.5 + 0.5 * sin(_t * 5.0)
			draw_arc(Vector2.ZERO, radius * (1.02 + 0.06 * pulse), 0, TAU, 40, Color(1, 1, 1, 0.5 + 0.4 * pulse), radius * 0.1, true)
			draw_circle(Vector2.ZERO, radius * 0.2, white, true, -1.0, true)
			for i in 4:
				var p := Vector2.from_angle(_t * 1.5 + TAU * i / 4.0) * radius * 1.02
				draw_circle(p, radius * 0.07, white, true, -1.0, true)


func _draw_rainbow() -> void:
	draw_circle(Vector2(0, radius * 0.14), radius * 0.9, Color(0, 0, 0, 0.32), true, -1.0, true)
	draw_circle(Vector2.ZERO, radius * 0.9, Color("#2b2545"), true, -1.0, true)
	draw_arc(Vector2.ZERO, radius * 0.9, 0, TAU, 40, Color("#cfc6ff"), radius * 0.08, true)
	for i in 7:
		var p := Vector2.from_angle(_t * 1.2 + TAU * i / 7.0) * radius * 0.56
		draw_circle(p, radius * 0.17, COLORS[i], true, -1.0, true)
		draw_circle(p + Vector2(-1, -1) * radius * 0.05, radius * 0.06, Color(1, 1, 1, 0.7), true, -1.0, true)
	draw_circle(Vector2.ZERO, radius * 0.18, Color(1, 1, 1, 0.9), true, -1.0, true)
#endregion


#region hint
var _hint_tween: Tween


## 提示：轻轻地反复缩放。循环 Tween 要记得在取消提示时 kill 掉。
func set_hint(on: bool) -> void:
	if _hint_tween:
		_hint_tween.kill()
		_hint_tween = null
	scale = Vector2.ONE
	if on:
		_hint_tween = create_tween().set_loops()
		_hint_tween.tween_property(self, "scale", Vector2(1.14, 1.14), 0.28).set_trans(Tween.TRANS_SINE)
		_hint_tween.tween_property(self, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_SINE)
#endregion
