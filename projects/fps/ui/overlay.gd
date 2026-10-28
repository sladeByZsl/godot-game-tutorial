## "点击画面开始 / 已暂停"提示层。游戏暂停时它仍然要响应点击，所以 process_mode = ALWAYS。
extends Control

signal clicked

@onready var title: Label = $Center/Box/Title
@onready var sub: Label = $Center/Box/Sub


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		clicked.emit()


func show_start() -> void:
	title.text = "FPS 竞技场"
	sub.text = "点击画面开始"
	visible = true


func show_paused() -> void:
	title.text = "已暂停"
	sub.text = "点击画面继续（鼠标会被锁定，按 Esc 释放）"
	visible = true
