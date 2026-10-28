## 第 4 章「信号与节点通信」用到的语法片段。
## 这个节点自己造一个按钮和一个计时器当信号源，演示各种连接写法。
extends Node

#region declare
signal hit                                   # 不带参数
signal health_changed(old: int, new: int)    # 带参数（参数类型只是说明，发信号时不强制检查）
signal item_picked(item_name: String, count: int)
#endregion

var button := Button.new()
var log_lines: PackedStringArray = []


#region connect_styles
func connect_styles() -> void:
	# 1. 连到一个方法：最常用
	button.pressed.connect(_on_button_pressed)
	# 2. 连到 lambda：逻辑很短、不想单独写方法时
	button.pressed.connect(func() -> void: log_lines.append("lambda 收到 pressed"))
	# 3. 自定义信号也一样，参数会按顺序传给回调
	health_changed.connect(_on_health_changed)
	# 4. 发信号：参数个数要和声明的一致
	health_changed.emit(100, 80)
	button.pressed.emit()                     # 内置信号也能用代码发出（模拟点击）


func _on_button_pressed() -> void:
	log_lines.append("方法收到 pressed")


func _on_health_changed(old: int, new: int) -> void:
	log_lines.append("血量 %d → %d" % [old, new])
#endregion


#region bind_unbind
func bind_unbind() -> void:
	# bind：在信号参数后面"追加"额外参数。多个按钮共用一个回调时很有用
	for i in 3:
		var b := Button.new()
		b.pressed.connect(_on_slot_pressed.bind(i))
		b.pressed.emit()
		b.free()
	# unbind：丢掉信号的最后 n 个参数。回调不关心这些参数时用
	item_picked.connect(_on_anything.unbind(2))
	item_picked.emit("药水", 3)


func _on_slot_pressed(slot: int) -> void:
	log_lines.append("第 %d 个格子被点了" % slot)


func _on_anything() -> void:
	log_lines.append("有东西被捡起来了")
#endregion


#region one_shot
func one_shot_demo() -> void:
	hit.connect(_on_first_hit, CONNECT_ONE_SHOT)   # 触发一次后自动断开
	hit.emit()
	hit.emit()                                     # 第二次不会再调用 _on_first_hit
	log_lines.append("还连着吗？%s" % hit.is_connected(_on_first_hit))


func _on_first_hit() -> void:
	log_lines.append("第一次被打！")
#endregion


#region disconnect
func disconnect_demo() -> void:
	if not hit.is_connected(_on_first_hit):        # 重复 connect 同一个回调会报错，先检查
		hit.connect(_on_first_hit)
	hit.disconnect(_on_first_hit)                  # 断开时传入同一个 Callable
	log_lines.append("连接数：%d" % hit.get_connections().size())
#endregion


#region await_signal
## await 一个信号：函数在这里暂停，等信号发出后再继续，信号参数作为 await 的结果返回。
func wait_for_click() -> void:
	log_lines.append("等玩家点按钮……")
	await button.pressed
	log_lines.append("按钮被点了，继续往下走")


func wait_for_pickup() -> void:
	var args: Array = await item_picked             # 多个参数时，结果是一个数组
	log_lines.append("捡到 %s × %d" % args)
#endregion


func run_all() -> void:
	connect_styles()
	bind_unbind()
	one_shot_demo()
	disconnect_demo()
	wait_for_click()
	log_lines.append("wait_for_click() 已经返回，但它还在等")
	button.pressed.emit()
	wait_for_pickup()
	item_picked.emit("钥匙", 2)
	for l in log_lines:
		print(l)
	button.free()
