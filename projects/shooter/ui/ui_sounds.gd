## 给一棵 UI 树里的所有按钮/滑块挂上音效：焦点移动"嘀"一声，按下"叮"一声。
class_name UiSounds
extends RefCounted


static func attach(root: Node) -> void:
	for c in root.find_children("*", "Control", true, false):
		if c is BaseButton or c is Slider:
			c.focus_entered.connect(Audio.play.bind("ui_move", -4.0))
		if c is BaseButton:
			c.pressed.connect(Audio.play.bind("ui_ok", 0.0))
