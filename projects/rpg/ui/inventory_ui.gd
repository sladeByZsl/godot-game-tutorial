## 背包界面：按 I 打开（暂停游戏），方向键选格子，E 使用，I / Esc 关闭。
extends CanvasLayer

const COLS := 4

var _selected := 0
var _panel: PanelContainer
var _grid: GridContainer
var _desc: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 9
	_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.09, 0.15, 0.95)
	sb.border_color = Color(0.95, 0.84, 0.58)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(18)
	_panel.add_theme_stylebox_override("panel", sb)
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	add_child(_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	_panel.add_child(vb)
	var title := Label.new()
	title.text = "背包"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.95, 0.8, 0.45))
	vb.add_child(title)
	_grid = GridContainer.new()
	_grid.columns = COLS
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	vb.add_child(_grid)
	_desc = Label.new()
	_desc.custom_minimum_size = Vector2(300, 52)
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.add_theme_font_size_override("font_size", 16)
	vb.add_child(_desc)
	_panel.hide()
	Game.inventory.changed.connect(_refresh)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory") or (_panel.visible and event.is_action_pressed("ui_cancel")):
		if _panel.visible or not get_tree().paused:   # 对话中不开背包
			_toggle()
		get_viewport().set_input_as_handled()
		return
	if not _panel.visible:
		return
	var move := Vector2i.ZERO
	if event.is_action_pressed("move_left"): move.x = -1
	elif event.is_action_pressed("move_right"): move.x = 1
	elif event.is_action_pressed("move_up"): move.y = -1
	elif event.is_action_pressed("move_down"): move.y = 1
	if move != Vector2i.ZERO:
		_selected = wrapi(_selected + move.x + move.y * COLS, 0, Inventory.SIZE)
		_refresh()
	elif event.is_action_pressed("interact") or event.is_action_pressed("attack"):
		_use_selected()
	get_viewport().set_input_as_handled()


func _toggle() -> void:
	_panel.visible = not _panel.visible
	get_tree().paused = _panel.visible
	if _panel.visible:
		_refresh()
		_panel.reset_size()
		_panel.position = (_panel.get_viewport_rect().size - _panel.size) / 2.0


#region use_item
func _use_selected() -> void:
	var slot: Inventory.Slot = Game.inventory.slots[_selected]
	if slot == null:
		return
	if slot.item.heal <= 0:
		_desc.text = "%s 不能直接使用。" % slot.item.display_name
		return
	if Game.hp >= Game.max_hp:
		_desc.text = "血是满的，先留着吧。"
		return
	Game.change_hp(slot.item.heal)
	Game.inventory.remove_at(_selected)     # 只改这一格的数量，ItemData 本身不动
#endregion


func _refresh() -> void:
	if not _panel.visible:
		return
	for c in _grid.get_children():
		c.queue_free()
	for i in Inventory.SIZE:
		var slot: Inventory.Slot = Game.inventory.slots[i]
		var cell := Panel.new()
		cell.custom_minimum_size = Vector2(64, 64)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.2, 0.18, 0.27)
		sb.set_corner_radius_all(6)
		sb.border_color = Color(0.95, 0.84, 0.58) if i == _selected else Color(0.3, 0.27, 0.38)
		sb.set_border_width_all(3 if i == _selected else 2)
		cell.add_theme_stylebox_override("panel", sb)
		if slot:
			var icon := TextureRect.new()
			icon.texture = slot.item.icon
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.position = Vector2(8, 8)
			icon.size = Vector2(48, 48)
			cell.add_child(icon)
			var n := Label.new()
			n.text = str(slot.count)
			n.add_theme_font_size_override("font_size", 15)
			n.add_theme_constant_override("outline_size", 5)
			n.add_theme_color_override("font_outline_color", Color(0.08, 0.06, 0.12))
			n.position = Vector2(44, 40)
			cell.add_child(n)
		_grid.add_child(cell)
	var sel: Inventory.Slot = Game.inventory.slots[_selected]
	_desc.text = "%s：%s" % [sel.item.display_name, sel.item.description] if sel else "（空）"
