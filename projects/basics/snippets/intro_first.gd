## 第 1 章片段：第一个脚本。挂到一个 Sprite2D 上，按 F6 运行当前场景。
extends Sprite2D

#region first
@export var speed_degrees := 90.0      # 每秒转多少度；@export 让它出现在检查器里


func _ready() -> void:
	print("你好，Godot！我叫 ", name)   # 输出在编辑器底部的"输出"面板


func _process(delta: float) -> void:
	rotation_degrees += speed_degrees * delta   # delta 是距上一帧的秒数，乘上它速度才和帧率无关
#endregion
