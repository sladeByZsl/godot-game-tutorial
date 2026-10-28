## 第 3 章：@export / @onready、类、内部类、static、setter。
## 每个 .gd 文件本身就是一个类。这个文件没写 class_name，所以只能用 preload("…").new() 来创建。
extends Node2D

#region export_onready
@export var max_speed := 300.0                 # 出现在检查器里，可以在编辑器里改
@export_range(0, 100, 5) var armor := 20       # 带范围的滑块
@export var tint := Color.WHITE
@export_enum("战士", "法师", "弓手") var job := "战士"
@export_group("掉落")                           # 检查器里的分组标题
@export var drop_table: Array[String] = ["金币"]

@onready var label: Label = $Label             # 等节点进树、_ready() 之前才取值
@onready var start_pos := position             # 也可以是任意表达式
#endregion


#region setter
## 属性的 setter / getter：赋值时自动执行一段代码。
var health := 100:
	set(value):
		health = clampi(value, 0, max_health)   # 在 setter 里给自己赋值，不会再次触发 setter
		if health == 0:
			print("倒下了")
	get:
		return health

var max_health := 100
var is_alive: bool:                             # 只有 getter 的"计算属性"
	get:
		return health > 0
#endregion


#region inner_class
## 内部类：写在别的类里面的类。适合只在这个文件里用的小数据结构。
class Item:
	var name: String
	var price: int

	func _init(p_name: String, p_price := 1) -> void:   # 构造函数，new() 的参数传到这里
		name = p_name
		price = p_price

	func _to_string() -> String:                          # print() 时显示的文字
		return "%s(%d 金)" % [name, price]


func make_items() -> Array[Item]:
	return [Item.new("药水", 5), Item.new("钥匙")]
#endregion


#region static
## static：属于"类"本身，不属于某个实例。不用创建对象就能调用。
static var created_count := 0      # 所有实例共享的一个变量

static func lerp_color(a: Color, b: Color, t: float) -> Color:
	return a.lerp(b, t)


func _init() -> void:
	created_count += 1
#endregion


func run_all() -> void:
	health = 150
	print("health 被限制为 ", health, "，is_alive = ", is_alive)
	health -= 200
	print("is_alive = ", is_alive)
	print(make_items())
	print("lerp_color: ", lerp_color(Color.BLACK, Color.WHITE, 0.5))
	print("created_count = ", created_count)
