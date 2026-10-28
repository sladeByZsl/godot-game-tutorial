## 第 2 章片段：取得别的节点的几种写法。
## 假设场景结构是：
##   Level (本脚本)
##   ├─ Player
##   │   ├─ Sprite
##   │   └─ %HealthBar   （勾选了"作为唯一名称访问"）
##   └─ Enemies
##       ├─ Slime
##       └─ Bat
extends Node


func _ready() -> void:
	#region get_node
	var player := get_node("Player")                  # 相对路径：从自己出发，找名叫 Player 的子节点
	var sprite := get_node("Player/Sprite")           # 用 / 一层层往下走
	var slime := $Enemies/Slime                       # $ 是 get_node() 的简写，效果完全一样
	var quoted := $"Enemies/Bat"                      # 名字里有空格或特殊字符时，加引号
	#endregion

	#region parent
	var level := player.get_parent()                  # 往上走一层
	var bat := slime.get_node("../Bat")               # .. 表示父节点：从 Slime 出发 → Enemies → Bat
	var root_window := get_node("/root")              # 以 / 开头是绝对路径，从场景树的根（一个 Window）开始
	var tuning := get_node("/root/Tuning")            # 自动加载的单例就挂在 /root 下面
	#endregion

	#region unique
	var bar_long := get_node("Player/HealthBar")      # 普通写法：要写全路径
	var bar := %HealthBar                             # 唯一名称：不管藏在第几层，同一场景里直接拿到
	var bar_same := get_node("%HealthBar")            # 和上一行等价
	#endregion

	#region safe
	var boss := get_node_or_null("Enemies/Boss")      # 找不到时返回 null，不报错
	if boss == null:
		print("这一关没有 Boss")
	if has_node("Enemies/Bat"):
		print("有蝙蝠")
	var deep := find_child("Sprite", true, false)     # 按名字递归搜索（慢，别每帧调用）
	#endregion

	print([player, sprite, quoted, level, bat, root_window, tuning, bar_long, bar, bar_same, deep])
