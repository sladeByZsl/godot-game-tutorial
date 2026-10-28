## 屏幕上的常驻界面：心形血量、金币、任务、交互提示、底部消息。全部在代码里搭，方便看清结构。
extends CanvasLayer

const HEARTS := preload("res://art/hearts.png")
const ITEMS := preload("res://art/items.png")

var player: Player
var _hearts: HBoxContainer
var _coins: Label
var _quest: Label
var _toast: Label
var _toast_time := 0.0
var _prompt: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # 暂停（对话、背包）时提示也要能消失
	_hearts = HBoxContainer.new()
	_hearts.position = Vector2(16, 12)
	_hearts.add_theme_constant_override("separation", 0)
	add_child(_hearts)

	var coin_row := HBoxContainer.new()
	coin_row.position = Vector2(18, 56)
	coin_row.add_child(_icon(ITEMS, Rect2(0, 0, 16, 16), 28))
	_coins = _label(20)
	coin_row.add_child(_coins)
	add_child(coin_row)

	_quest = _label(18)
	_quest.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_quest.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_quest.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_quest.offset_right = -16
	_quest.offset_top = 14
	add_child(_quest)

	var help := _label(14)
	help.text = "WASD 移动   J/空格 攻击   E 交互   I 背包   K 存档   L 读档"
	help.modulate = Color(1, 1, 1, 0.75)
	help.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	help.offset_left = 16
	help.offset_top = -30
	add_child(help)

	_toast = _label(20)
	_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast.offset_top = -86
	_toast.modulate.a = 0.0
	add_child(_toast)

	_prompt = _label(15)
	_prompt.add_theme_stylebox_override("normal", _box())
	add_child(_prompt)

	Game.hp_changed.connect(_on_hp_changed)
	Game.coins_changed.connect(func(c: int) -> void: _coins.text = "× %d" % c)
	Game.flags_changed.connect(_update_quest)
	Game.toast.connect(show_toast)
	_on_hp_changed(Game.hp, Game.max_hp)
	_coins.text = "× %d" % Game.coins
	_update_quest()


#region hearts
func _on_hp_changed(hp: int, max_hp: int) -> void:
	for c in _hearts.get_children():
		c.queue_free()
	for i in range(0, max_hp, 2):       # 每颗心代表 2 点血
		var frame := 0 if hp >= i + 2 else (1 if hp == i + 1 else 2)   # 满 / 半 / 空
		_hearts.add_child(_icon(HEARTS, Rect2(frame * 16, 0, 16, 16), 40))
#endregion


func _update_quest() -> void:
	if Game.has_flag("reward_given"):
		_quest.text = "任务完成 ★"
	elif Game.has_flag("slimes_cleared"):
		_quest.text = "任务：回村找村长"
	elif Game.has_flag("quest_active"):
		_quest.text = "任务：打倒史莱姆 %d / %d" % [Game.slimes_killed, Game.QUEST_TARGET]
	else:
		_quest.text = "和村长聊聊"


func show_toast(text: String) -> void:
	_toast.text = text
	_toast_time = 2.2


func _process(delta: float) -> void:
	_toast_time -= delta
	_toast.modulate.a = clampf(_toast_time * 2.0, 0.0, 1.0)
	# 交互提示跟着目标走：世界坐标 → 屏幕坐标
	var target := player.interact_target if player and not get_tree().paused else null
	_prompt.visible = target != null
	if target:
		_prompt.text = "E " + target.interact_label()
		var screen := get_viewport().get_canvas_transform() * (target.global_position + Vector2(0, -22))
		_prompt.position = screen - Vector2(_prompt.size.x / 2.0, _prompt.size.y)


func _icon(tex: Texture2D, region: Rect2, px: int) -> TextureRect:
	var at := AtlasTexture.new()
	at.atlas = tex
	at.region = region
	var r := TextureRect.new()
	r.texture = at
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = Vector2(px, px)
	return r


func _label(size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color(0.08, 0.06, 0.12))
	l.add_theme_constant_override("outline_size", 6)
	return l


func _box() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.09, 0.15, 0.85)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 1
	sb.content_margin_bottom = 2
	return sb
