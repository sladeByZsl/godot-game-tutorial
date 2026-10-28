## 暂停菜单。process_mode = WHEN_PAUSED：游戏暂停时它才处理输入和动画，平时完全不占用。
extends CanvasLayer

@onready var menu: Control = %Menu
@onready var resume_button: Button = %Resume
@onready var settings: Control = %SettingsPanel


func _ready() -> void:
	hide()
	settings.hide()
	Flow.state_changed.connect(_on_state_changed)
	resume_button.pressed.connect(func() -> void: Flow.set_paused(false))
	%Restart.pressed.connect(func() -> void: Flow.start_game(Flow.start_at_boss))
	%Settings.pressed.connect(func() -> void:
		menu.hide()
		settings.open())
	%ToTitle.pressed.connect(Flow.go_to_title)
	settings.closed.connect(func() -> void:
		menu.show()
		%Settings.grab_focus())
	UiSounds.attach(self)


func _on_state_changed(state: Flow.State) -> void:
	visible = state == Flow.State.PAUSED
	if visible:
		menu.show()
		settings.hide()
		resume_button.grab_focus()
