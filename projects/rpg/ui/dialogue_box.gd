## 对话框：逐字显示台词，支持选项。播放期间暂停游戏（本节点 process_mode = ALWAYS）。
extends CanvasLayer

@export var chars_per_sec := 30.0        ## 打字速度（字/秒）

var _dialogue: Dialogue
var _index := 0
var _shown := 0.0                        # 已经"打"出来的字数（带小数，逐帧累加）
var _choice := 0

@onready var panel: Control = $Panel
@onready var speaker: Label = $Panel/Margin/VBox/Speaker
@onready var text: RichTextLabel = $Panel/Margin/VBox/Text
@onready var choices: HBoxContainer = $Panel/Margin/VBox/Choices
@onready var arrow: Label = $Panel/Arrow


func _ready() -> void:
	panel.hide()
	Tuning.bind(self, "dialogue", ["chars_per_sec"])
	Game.dialogue_requested.connect(start)


func start(dialogue: Dialogue) -> void:
	_dialogue = dialogue
	_index = 0
	panel.show()
	get_tree().paused = true
	_show_line()


func is_open() -> bool:
	return panel.visible


#region show_line
func _show_line() -> void:
	var line := _dialogue.lines[_index]
	speaker.text = line.speaker
	text.text = Game.format_text(line.text)
	text.visible_characters = 0          # 先一个字都不显示
	_shown = 0.0
	choices.hide()
	_choice = 0
#endregion


#region typewriter
func _process(delta: float) -> void:
	if not panel.visible:
		return
	var total := text.get_total_character_count()
	if text.visible_characters < total:
		_shown += chars_per_sec * delta
		text.visible_characters = mini(int(_shown), total)
	elif not _current_line().choices.is_empty() and not choices.visible:
		_build_choices()
	arrow.visible = text.visible_characters >= total and not choices.visible
	arrow.modulate.a = 1.0 if Time.get_ticks_msec() % 800 < 500 else 0.3
#endregion


#region dialogue_input
func _unhandled_input(event: InputEvent) -> void:
	if not panel.visible:
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("attack"):
		get_viewport().set_input_as_handled()   # 吞掉这次按键，玩家那边收不到
		if text.visible_characters < text.get_total_character_count():
			text.visible_characters = text.get_total_character_count()   # 没打完：先一下子显示全
			_shown = text.visible_characters
		elif choices.visible:
			_pick(_choice)
		else:
			_next()
	elif choices.visible and (event.is_action_pressed("move_left") or event.is_action_pressed("move_right")):
		get_viewport().set_input_as_handled()
		_choice = wrapi(_choice + (1 if event.is_action_pressed("move_right") else -1), 0, choices.get_child_count())
		_highlight()
#endregion


func _current_line() -> DialogueLine:
	return _dialogue.lines[_index]


func _build_choices() -> void:
	for c in choices.get_children():
		c.queue_free()
	for opt in _current_line().choices:
		var l := Label.new()
		l.text = opt
		l.add_theme_font_size_override("font_size", 20)
		choices.add_child(l)
	choices.show()
	_highlight()


func _highlight() -> void:
	var opts := _current_line().choices
	for i in choices.get_child_count():
		var l := choices.get_child(i) as Label
		l.text = ("▶ " if i == _choice else "   ") + opts[i]
		l.modulate = Color(1, 0.86, 0.45) if i == _choice else Color(0.8, 0.8, 0.86)


#region finish
func _pick(i: int) -> void:
	var flags := _current_line().choice_flags
	if i < flags.size():
		Game.set_flag(flags[i])
	_next()


func _next() -> void:
	_index += 1
	if _index < _dialogue.lines.size():
		_show_line()
		return
	# 对话结束：把这段对话声明的效果应用到全局状态
	Game.set_flag(_dialogue.flag_on_finish)
	if _dialogue.reward_coins:
		Game.add_coins(_dialogue.reward_coins)
	if _dialogue.reward_max_hp:
		Game.max_hp += _dialogue.reward_max_hp
		Game.change_hp(Game.max_hp)
	panel.hide()
	get_tree().paused = false
#endregion
