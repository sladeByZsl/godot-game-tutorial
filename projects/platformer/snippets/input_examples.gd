## 第 6 章：读取输入的几种写法。这个文件不在游戏里运行，只用来在教程中展示（能通过编译检查）。
extends Node

#region input_poll
func _physics_process(_delta: float) -> void:
	# 轮询：每一帧主动去问"现在按着没有"
	var dir := Input.get_axis("move_left", "move_right")      # -1 ~ 1；手柄摇杆会得到中间值
	var holding := Input.is_action_pressed("jump")            # 这一帧是否按着
	var pressed := Input.is_action_just_pressed("jump")       # 是否"这一帧刚按下"
	var released := Input.is_action_just_released("jump")    # 是否"这一帧刚松开"
	print(dir, holding, pressed, released)
#endregion


#region input_event
## 事件：有输入发生时引擎调用。适合"按一下触发一次"的操作，比如暂停菜单。
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().paused = not get_tree().paused
#endregion


#region input_map
## 在代码里添加一个动作并绑定按键（一般在 项目设置 → 输入映射 里点出来就行）。
func add_dash_action() -> void:
	if not InputMap.has_action("dash"):
		InputMap.add_action("dash")
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_SHIFT        # 用物理键位，换了键盘布局位置也不变
	InputMap.action_add_event("dash", ev)
#endregion
