## 标题界面。根节点是全屏的 Control，里面用 MarginContainer + HBoxContainer + VBoxContainer 排版，
## 窗口尺寸变化时容器会自动重新排布，不需要手算坐标。
extends Control

@onready var start_button: Button = %Start
@onready var menu: Control = %Menu
@onready var settings: Control = %SettingsPanel
@onready var scores_box: VBoxContainer = %Scores


func _ready() -> void:
	Flow.state = Flow.State.TITLE
	start_button.pressed.connect(Flow.start_game.bind(false))
	%Boss.pressed.connect(Flow.start_game.bind(true))
	%Settings.pressed.connect(_open_settings)
	%Quit.pressed.connect(get_tree().quit)
	%Quit.visible = not OS.has_feature("web")     # 网页里"退出"没有意义
	settings.closed.connect(func() -> void:
		menu.show()
		%Settings.grab_focus())
	settings.hide()
	_fill_scores()
	UiSounds.attach(self)
	for b in menu.get_children():
		if b is Button:
			b.mouse_entered.connect(_on_button_hover.bind(b))
	start_button.grab_focus()      # 没有焦点的话，键盘和手柄就无从下手
	Audio.play_music()


#region focus
## 鼠标移到按钮上时也把焦点给它，这样鼠标、键盘、手柄三种操作的"当前项"始终是同一个。
func _on_button_hover(b: Button) -> void:
	b.grab_focus()
#endregion


func _open_settings() -> void:
	menu.hide()
	settings.open()


func _fill_scores() -> void:
	for c in scores_box.get_children():
		c.queue_free()
	if Flow.high_scores.is_empty():
		var empty := Label.new()
		empty.text = "还没有记录"
		empty.theme_type_variation = &"HudSmall"
		scores_box.add_child(empty)
	for i in Flow.high_scores.size():
		var e: Dictionary = Flow.high_scores[i]
		var row := HBoxContainer.new()
		for text in ["%d." % (i + 1), "%d" % e["score"], e["date"]]:
			var l := Label.new()
			l.text = text
			l.theme_type_variation = &"HudSmall"
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL if text == e["date"] else Control.SIZE_FILL
			l.custom_minimum_size.x = 28 if text.ends_with(".") else 90
			row.add_child(l)
		scores_box.add_child(row)
