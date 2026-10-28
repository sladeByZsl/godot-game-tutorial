## 界面：分数、目标进度条和星星、剩余步数、连锁提示、结算面板。
## 所有控件都在 _ready 里用代码搭出来，main.gd 只调用这里的几个函数。
class_name Hud
extends CanvasLayer

signal restart_pressed

var _panel: PanelContainer
var _score_label: Label
var _target_label: Label
var _moves_label: Label
var _info_label: Label
var _bar: Control
var _chain_label: Label
var _toast: Label
var _result: PanelContainer
var _result_title: Label
var _result_stars: Label
var _result_score: Label

var _score := 0
var _shown_score := 0.0
var _target := 3000
var _board_rect := Rect2()


func _ready() -> void:
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", _box(Color(0.08, 0.09, 0.18, 0.86), 16))
	add_child(_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	_panel.add_child(vb)
	vb.add_child(_label("分数", 15, Color("#9aa4d6")))
	_score_label = _label("0", 40, Color.WHITE)
	vb.add_child(_score_label)
	_bar = Control.new()
	_bar.custom_minimum_size = Vector2(0, 34)
	_bar.draw.connect(_draw_bar)
	vb.add_child(_bar)
	_target_label = _label("目标 3000", 14, Color("#9aa4d6"))
	vb.add_child(_target_label)
	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 12)
	vb.add_child(sep)
	vb.add_child(_label("剩余步数", 15, Color("#9aa4d6")))
	_moves_label = _label("20", 40, Color("#ffd35c"))
	vb.add_child(_moves_label)
	_info_label = _label("", 13, Color("#7d86b8"))
	_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(_info_label)

	_chain_label = _label("", 44, Color("#ffe27a"))
	_chain_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_chain_label.modulate.a = 0.0
	add_child(_chain_label)
	_toast = _label("", 20, Color.WHITE)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.modulate.a = 0.0
	add_child(_toast)
	_build_result()


func _label(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.04, 0.04, 0.1))
	l.add_theme_constant_override("outline_size", 6 if font_size > 30 else 0)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _box(color: Color, radius: int) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = color
	b.set_corner_radius_all(radius)
	b.set_content_margin_all(18)
	b.border_color = Color(1, 1, 1, 0.08)
	b.set_border_width_all(1)
	b.shadow_color = Color(0, 0, 0, 0.35)
	b.shadow_size = 12
	return b


func _build_result() -> void:
	_result = PanelContainer.new()
	_result.add_theme_stylebox_override("panel", _box(Color(0.1, 0.1, 0.22, 0.96), 20))
	_result.visible = false
	add_child(_result)
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 10)
	_result.add_child(vb)
	_result_title = _label("", 30, Color.WHITE)
	_result_stars = _label("", 54, Color("#ffd35c"))
	_result_score = _label("", 18, Color("#c8cdf0"))
	for l in [_result_title, _result_stars, _result_score]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(l)
	var btn := Button.new()
	btn.text = "再来一局"
	btn.add_theme_font_size_override("font_size", 20)
	btn.custom_minimum_size = Vector2(180, 46)
	btn.add_theme_stylebox_override("normal", _box(Color("#5b5bf0"), 12))
	btn.add_theme_stylebox_override("hover", _box(Color("#7373ff"), 12))
	btn.add_theme_stylebox_override("pressed", _box(Color("#4646c8"), 12))
	btn.pressed.connect(func() -> void: restart_pressed.emit())
	vb.add_child(btn)


## 横屏时面板在棋盘右边，竖屏（手机）时在上面。
func layout(panel_rect: Rect2, board_rect: Rect2) -> void:
	_panel.position = panel_rect.position
	_panel.size = panel_rect.size
	_panel.custom_minimum_size = panel_rect.size
	_chain_label.position = Vector2(board_rect.position.x, board_rect.get_center().y - 60)
	_chain_label.size = Vector2(board_rect.size.x, 60)
	_chain_label.pivot_offset = _chain_label.size * 0.5
	_toast.position = Vector2(board_rect.position.x, board_rect.end.y - 50)
	_toast.size = Vector2(board_rect.size.x, 30)
	_board_rect = board_rect


func set_info(text: String) -> void:
	_info_label.text = text


func set_values(score: int, target: int, moves_left: int) -> void:
	_score = score
	_target = maxi(target, 1)
	_target_label.text = "目标 %d（2 倍得三星）" % _target
	_moves_label.text = str(moves_left)
	_moves_label.add_theme_color_override("font_color", Color("#ff7a7a") if moves_left <= 3 else Color("#ffd35c"))


func _process(delta: float) -> void:
	# 分数数字滚动：每帧向真实分数靠近一部分，而不是一下子跳过去
	if absf(_shown_score - _score) > 0.5:
		_shown_score = lerpf(_shown_score, _score, 1.0 - exp(-10.0 * delta))
		_score_label.text = str(roundi(_shown_score))
		_bar.queue_redraw()
	elif _score_label.text != str(_score):
		_shown_score = _score
		_score_label.text = str(_score)
		_bar.queue_redraw()


#region stars
## 星级：达到目标 1 星，1.5 倍 2 星，2 倍 3 星。进度条的满格是 2 倍目标。
static func stars_for(score: int, target: int) -> int:
	if score >= target * 2:
		return 3
	if score >= roundi(target * 1.5):
		return 2
	return 1 if score >= target else 0
#endregion


func _draw_bar() -> void:
	var w := _bar.size.x
	var y := 18.0
	var track := Rect2(0, y - 5, w, 10)
	_bar.draw_rect(track, Color(1, 1, 1, 0.1))
	var k := clampf(_shown_score / (_target * 2.0), 0.0, 1.0)
	_bar.draw_rect(Rect2(track.position, Vector2(w * k, 10)), Color("#7c6cff"))
	for i in 3:
		var at := [0.5, 0.75, 1.0][i] as float
		var c := Vector2(w * at - (8.0 if i == 2 else 0.0), y)
		var lit := k >= at - 0.0001
		var pts := PackedVector2Array()
		for j in 10:
			pts.append(c + Vector2.from_angle(-PI / 2.0 + TAU * j / 10.0) * (11.0 if j % 2 == 0 else 5.0))
		_bar.draw_colored_polygon(pts, Color("#ffd35c") if lit else Color("#3b3f63"))


func show_chain(n: int) -> void:
	_chain_label.text = "连锁 ×%d" % n
	_chain_label.modulate.a = 1.0
	_chain_label.scale = Vector2(0.5, 0.5)
	var tw := _chain_label.create_tween()
	tw.tween_property(_chain_label, "scale", Vector2(1.0, 1.0), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.35)
	tw.tween_property(_chain_label, "modulate:a", 0.0, 0.3)


func toast(text: String) -> void:
	_toast.text = text
	var tw := _toast.create_tween()
	tw.tween_property(_toast, "modulate:a", 1.0, 0.15)
	tw.tween_interval(1.2)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.4)


func show_result(score: int, target: int) -> void:
	var stars := stars_for(score, target)
	_result_title.text = "过关！" if stars > 0 else "步数用完了"
	_result_stars.text = "★".repeat(stars) + "☆".repeat(3 - stars)
	_result_score.text = "得分 %d　目标 %d" % [score, target]
	_result.visible = true
	_result.reset_size()
	_result.position = _board_rect.get_center() - _result.size * 0.5
	_result.pivot_offset = _result.size * 0.5
	_result.scale = Vector2(0.7, 0.7)
	_result.modulate.a = 0.0
	var tw := _result.create_tween().set_parallel(true)
	tw.tween_property(_result, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_result, "modulate:a", 1.0, 0.2)


func hide_result() -> void:
	_result.visible = false
