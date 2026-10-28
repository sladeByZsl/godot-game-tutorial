## 音量设置面板（标题界面和暂停菜单共用）。滑块直接改 Audio 的音量，关闭时存档。
extends PanelContainer

signal closed

@onready var music_slider: HSlider = %MusicSlider
@onready var sfx_slider: HSlider = %SfxSlider
@onready var music_value: Label = %MusicValue
@onready var sfx_value: Label = %SfxValue
@onready var back_button: Button = %Back


func _ready() -> void:
	music_slider.value_changed.connect(func(v: float) -> void:
		Audio.music_volume = v
		music_value.text = "%d%%" % roundi(v * 100))
	sfx_slider.value_changed.connect(func(v: float) -> void:
		Audio.sfx_volume = v
		sfx_value.text = "%d%%" % roundi(v * 100)
		Audio.play("pickup"))           # 拖音效音量时顺便试听
	back_button.pressed.connect(close)


func open() -> void:
	music_slider.value = Audio.music_volume
	sfx_slider.value = Audio.sfx_volume
	show()
	music_slider.grab_focus()            # 打开面板就把焦点给第一个控件，手柄/键盘才能接着操作


func close() -> void:
	Flow.save()
	hide()
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
