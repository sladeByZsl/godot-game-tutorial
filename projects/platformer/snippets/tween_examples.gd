## 第 7 章：Tween 的几种常见写法。这个文件不在游戏里运行，只用来在教程中展示（能通过编译检查）。
extends Node2D

#region chain
func chain_example() -> void:
	var tw := create_tween()                              # 补间绑定在这个节点上，节点被删除时自动停止
	tw.tween_property(self, "position:x", 300.0, 0.5)     # 第 1 步
	tw.tween_property(self, "rotation", PI, 0.3)          # 第 2 步：等第 1 步结束才开始
	tw.tween_interval(0.2)                                # 第 3 步：等 0.2 秒
	tw.tween_callback(queue_free)                         # 第 4 步：调用一个方法
#endregion


#region parallel
func parallel_example() -> void:
	var tw := create_tween().set_parallel()               # 之后添加的步骤都同时开始
	tw.tween_property(self, "scale", Vector2(2, 2), 0.4)
	tw.tween_property(self, "modulate:a", 0.0, 0.4)
	tw.chain().tween_callback(queue_free)                 # chain()：这一步等前面全部结束

	# 另一种写法：默认按顺序，只让某一步和上一步同时进行
	var tw2 := create_tween()
	tw2.tween_property(self, "position:y", -40.0, 0.3).as_relative()
	tw2.parallel().tween_property(self, "rotation", 0.5, 0.3)
#endregion


#region ease
func ease_example() -> void:
	var tw := create_tween()
	tw.tween_property(self, "position:x", 400.0, 0.6) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)     # 冲过头一点再退回来
	tw.tween_property(self, "position:x", 0.0, 0.6) \
			.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)   # 像球落地一样弹几下
#endregion


#region loops
func loop_example() -> void:
	var tw := create_tween().set_loops()                  # 不传次数 = 无限循环
	tw.tween_property(self, "position:y", -6.0, 0.5).as_relative().set_trans(Tween.TRANS_SINE)
	tw.tween_property(self, "position:y", 6.0, 0.5).as_relative().set_trans(Tween.TRANS_SINE)


func await_example() -> void:
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.5)
	await tw.finished                                     # 等补间播完再往下执行
	queue_free()
#endregion


#region kill
var _tween: Tween


func restart_tween() -> void:
	if _tween:
		_tween.kill()          # 先停掉旧的；两个补间同时改一个属性，结果会互相打架
	_tween = create_tween()
	_tween.tween_property(self, "scale", Vector2.ONE, 0.2).from(Vector2(1.3, 0.7))
#endregion
