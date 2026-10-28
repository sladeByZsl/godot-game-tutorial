## 微基准：新建/销毁 vs 从池里取出/放回，各做 N 次，比较耗时。
## 用法：Godot --headless --path projects/shooter -s res://gen/bench_pool.gd
extends SceneTree

const N := 2000
const SCENE := preload("res://game/enemy_bullet.tscn")


func _initialize() -> void:
	var holder := Node2D.new()
	root.add_child(holder)
	for round_i in 3:
		# 1) 不用池：instantiate + add_child，然后 free（queue_free 在帧末做的也是这件事）
		var t0 := Time.get_ticks_usec()
		var list: Array[Node] = []
		for i in N:
			var b := SCENE.instantiate()
			b.position = Vector2(i % 600, i / 4)
			holder.add_child(b)
			list.append(b)
		var t1 := Time.get_ticks_usec()
		for b in list:
			b.free()
		var t2 := Time.get_ticks_usec()
		# 2) 用池：预先建好，只切换 process_mode / visible
		var pool: Array[Node2D] = []
		for i in N:
			var b: Node2D = SCENE.instantiate()
			holder.add_child(b)
			b.hide()
			b.process_mode = Node.PROCESS_MODE_DISABLED
			pool.append(b)
		var t3 := Time.get_ticks_usec()
		for i in N:
			var b := pool[i]
			b.position = Vector2(i % 600, i / 4)
			b.show()
			b.process_mode = Node.PROCESS_MODE_INHERIT
		var t4 := Time.get_ticks_usec()
		for b in pool:
			b.hide()
			b.process_mode = Node.PROCESS_MODE_DISABLED
		var t5 := Time.get_ticks_usec()
		for b in pool:
			b.free()
		print("第 %d 轮  每颗子弹：新建 %.1f µs，销毁 %.1f µs ｜ 池取出 %.1f µs，放回 %.1f µs" % [
			round_i + 1, float(t1 - t0) / N, float(t2 - t1) / N, float(t4 - t3) / N, float(t5 - t4) / N])
	quit()
