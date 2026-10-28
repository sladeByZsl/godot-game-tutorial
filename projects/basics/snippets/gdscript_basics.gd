## 第 3 章「GDScript 速成」用到的语法片段：变量、函数、控制流、数组和字典。
## 这个文件能直接运行：把它挂到任意节点上，或者调用 run_all()，输出会打印到"输出"面板。
extends Node

#region vars
var hp = 100                 # 动态类型：以后可以赋任何类型的值
var speed: float = 120.0     # 显式静态类型
var player_name := "Alice"   # := 根据右边的值推断类型（这里是 String），之后不能再赋别的类型
var lives := 3               # 推断为 int
var ratio := 3 / 2           # 两个 int 相除还是 int，结果是 1
var ratio_f := 3 / 2.0       # 只要有一个是 float，结果就是 1.5
const MAX_LIVES := 5         # 常量，不能修改
enum State { IDLE, RUN, JUMP }   # 枚举，本质是一组 int 常量：IDLE=0, RUN=1, JUMP=2
var state := State.IDLE
#endregion


#region functions
## 参数和返回值都可以写类型；带默认值的参数要放在后面。
func damage(amount: int, critical := false) -> int:
	var result := amount * 2 if critical else amount   # 三元表达式：值 if 条件 else 值
	hp -= result
	return result


## 没有返回值就写 -> void
func say_hello(who: String) -> void:
	print("你好，%s！" % who)   # % 格式化：%s 字符串，%d 整数，%.2f 两位小数
#endregion


#region control_flow
func control_flow_demo() -> void:
	if hp > 50:
		print("状态良好")
	elif hp > 0:
		print("快不行了")
	else:
		print("倒下了")

	for i in 3:                       # 0, 1, 2（等价于 range(3)）
		print("第 ", i, " 次")
	for i in range(10, 0, -3):        # 10, 7, 4, 1
		print(i)

	var n := 0
	while n < 3:
		n += 1
	print("n = ", n)
#endregion


#region match
func describe(value: Variant) -> String:
	match value:
		0:
			return "零"
		1, 2, 3:
			return "很小"
		"start":
			return "字符串 start"
		[var x, var y]:                       # 数组模式：正好两个元素，并把它们绑定到 x、y
			return "二元数组 %s, %s" % [x, y]
		{"type": "coin", ..}:                  # 字典模式：有 type 键且值是 coin，.. 表示允许有别的键
			return "金币字典"
		var other when other is int and other < 0:   # 守卫条件（4.4 起支持 when）
			return "负数"
		_:
			return "其他"
#endregion


#region arrays
func arrays_demo() -> void:
	var items := ["剑", "盾", 3]               # 普通数组：什么类型都能放
	var scores: Array[int] = [90, 72, 85]     # 类型化数组：只能放 int
	scores.append(60)
	scores.sort()                             # [60, 72, 85, 90]
	print(scores, " 最高分 ", scores.max(), " 共 ", scores.size(), " 个")
	print(items[0], " / 最后一个：", items[-1])  # 负数下标从末尾数
	var passed := scores.filter(func(s: int) -> bool: return s >= 80)   # [85, 90]
	var doubled := scores.map(func(s: int) -> int: return s * 2)
	print(passed, " ", doubled)
	print("有 72 吗？", 72 in scores)
#endregion


#region dicts
func dicts_demo() -> void:
	var player := {"name": "Alice", "hp": 100, "pos": Vector2(3, 4)}
	player["hp"] -= 30
	player.level = 2                          # 键是字符串时，也可以用点号读写
	print(player.name, " hp=", player["hp"], " 等级 ", player.get("level", 1))
	print("有 mp 键吗？", player.has("mp"), "  mp 默认 ", player.get("mp", 0))
	for key in player:                        # 遍历的是键（按插入顺序）
		print(key, " -> ", player[key])
	var stock: Dictionary[String, int] = {"苹果": 3, "香蕉": 5}   # 类型化字典（4.4 起）
	stock["苹果"] += 1
	print(stock)
#endregion


func run_all() -> void:
	print("ratio = ", ratio, ", ratio_f = ", ratio_f, ", state = ", state)
	print("damage 返回 ", damage(10, true), "，hp 剩 ", hp)
	say_hello(player_name)
	control_flow_demo()
	for v: Variant in [0, 2, "start", [1, 2], {"type": "coin", "value": 5}, -7, 3.5]:
		print("describe(", v, ") = ", describe(v))
	arrays_demo()
	dicts_demo()
