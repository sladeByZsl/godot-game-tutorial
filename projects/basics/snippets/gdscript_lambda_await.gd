## 第 3 章：lambda（匿名函数）和 await。
extends Node

signal answered(text: String)


#region lambda
func lambda_demo() -> void:
	var square := func(x: int) -> int: return x * x    # 把函数存进变量，类型是 Callable
	print(square.call(7))                              # 49

	var counter := 0
	var add := func() -> void: counter += 1            # lambda 捕获的是外部变量当时的"值"
	add.call()
	print("counter 还是 ", counter)                    # 0：基本类型按值捕获

	var hits: Array[int] = []
	var record := func(n: int) -> void: hits.append(n)  # 数组是引用类型，改的是同一个数组
	record.call(5)
	print("hits = ", hits)                             # [5]

	var words := ["banana", "fig", "apple"]
	words.sort_custom(func(a: String, b: String) -> bool: return a.length() < b.length())
	print(words)                                       # ["fig", "apple", "banana"]
#endregion


#region await
## 带 await 的函数就是"协程"：执行到 await 时先返回，等信号来了再从这里接着往下走。
func countdown() -> void:
	for i in range(3, 0, -1):
		print("倒计时 ", i)
		await get_tree().create_timer(0.5).timeout    # 等 0.5 秒（SceneTreeTimer 的 timeout 信号）
	print("出发！")


func ask() -> String:
	var text: String = await answered               # 等这个信号，并拿到它的参数
	return "收到回答：" + text


func await_demo() -> void:
	print("A：调用 countdown 之前")
	countdown()                                     # 没写 await：不等它，马上往下走
	print("B：countdown 已经开始，但还没结束")
	await countdown()                               # 写了 await：等它整个执行完
	print("C：第二次倒计时结束")
#endregion
