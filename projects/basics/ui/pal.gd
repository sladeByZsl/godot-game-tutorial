## 三个小场景共用的配色和绘图小工具（全部是静态函数，不需要实例化）。
## 用法：Pal.text(self, Vector2(10, 20), "你好", 16, Pal.TEXT)
class_name Pal
extends RefCounted

const BG := Color("0d1220")
const BG2 := Color("151d33")
const PANEL := Color(0.10, 0.13, 0.21, 0.92)
const PANEL_HI := Color(0.14, 0.18, 0.29, 0.96)
const LINE := Color("2d3a5a")
const TEXT := Color("e6ebf5")
const TEXT2 := Color("9aa6c0")
const TEXT3 := Color("5f6b86")
const BLUE := Color("5ab0f0")
const ORANGE := Color("ffb454")
const PINK := Color("ff7ab2")
const GREEN := Color("7ddc8c")
const TEAL := Color("5ed4dc")
const PURPLE := Color("b79cff")
const RED := Color("ff6b6b")
const YELLOW := Color("ffd866")
const AXIS_X := Color("ff6b6b")
const AXIS_Y := Color("7ddc8c")

static var _glow_tex: GradientTexture2D
static var _box := StyleBoxFlat.new()


## 一张白色的径向渐变贴图，画光晕用（第一次用到时才生成）。
static func glow_texture() -> Texture2D:
	if _glow_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.25, Color(1, 1, 1, 0.55))
		g.add_point(0.55, Color(1, 1, 1, 0.16))
		_glow_tex = GradientTexture2D.new()
		_glow_tex.gradient = g
		_glow_tex.fill = GradientTexture2D.FILL_RADIAL
		_glow_tex.fill_from = Vector2(0.5, 0.5)
		_glow_tex.fill_to = Vector2(1.0, 0.5)
		_glow_tex.width = 128
		_glow_tex.height = 128
	return _glow_tex


static func glow(ci: CanvasItem, pos: Vector2, radius: float, color: Color) -> void:
	var r := Vector2(radius, radius)
	ci.draw_texture_rect(glow_texture(), Rect2(pos - r, r * 2.0), false, color)


static func font() -> Font:
	return ThemeDB.fallback_font


static func text_width(s: String, size: int) -> float:
	return font().get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


## pos 是文字基线左端；align = 0 左对齐、1 居中、2 右对齐（相对 pos.x）。
static func text(ci: CanvasItem, pos: Vector2, s: String, size: int, color: Color, align := 0) -> void:
	var w := text_width(s, size)
	var x := pos.x - (w * 0.5 if align == 1 else (w if align == 2 else 0.0))
	ci.draw_string(font(), Vector2(x, pos.y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


## 圆角面板，带描边和柔和阴影。
static func panel(ci: CanvasItem, rect: Rect2, fill: Color, border: Color, radius := 10, border_w := 1) -> void:
	_box.bg_color = fill
	_box.border_color = border
	_box.set_border_width_all(border_w)
	_box.set_corner_radius_all(radius)
	_box.shadow_color = Color(0, 0, 0, 0.35)
	_box.shadow_size = 8
	_box.shadow_offset = Vector2(0, 3)
	_box.anti_aliasing = true
	ci.draw_style_box(_box, rect)


## 带箭头的线段，用来画坐标轴和"调用"方向。
static func arrow(ci: CanvasItem, from: Vector2, to: Vector2, color: Color, width := 2.0, head := 8.0) -> void:
	var dir := (to - from).normalized()
	if dir == Vector2.ZERO:
		return
	var n := dir.orthogonal()
	ci.draw_line(from, to - dir * head * 0.6, color, width, true)
	ci.draw_colored_polygon(PackedVector2Array([to, to - dir * head + n * head * 0.5, to - dir * head - n * head * 0.5]), color)


## 给 Button 套上统一的深色风格。
static func style_button(b: Button, accent: Color) -> void:
	var states := {"normal": 0.0, "hover": 0.12, "pressed": 0.25, "focus": 0.0, "disabled": 0.0}
	for state: String in states:
		var sb := StyleBoxFlat.new()
		sb.bg_color = PANEL.lerp(accent, states[state])
		sb.border_color = accent if state != "disabled" else LINE
		sb.set_border_width_all(1 if state != "focus" else 0)
		sb.set_corner_radius_all(8)
		sb.content_margin_left = 12
		sb.content_margin_right = 12
		sb.content_margin_top = 6
		sb.content_margin_bottom = 6
		sb.anti_aliasing = true
		if state == "focus":
			sb.draw_center = false
		b.add_theme_stylebox_override(state, sb)
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", TEXT3)
	b.add_theme_font_size_override("font_size", 15)
	b.focus_mode = Control.FOCUS_NONE
