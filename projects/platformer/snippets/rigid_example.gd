## 第 6 章对比用：如果用 RigidBody2D 来做平台跳跃角色，代码会是这样（不在游戏里运行）。
extends RigidBody2D

#region rigid
@export var move_force := 900.0
@export var jump_impulse := 420.0


func _ready() -> void:
	lock_rotation = true              # 否则角色会像箱子一样翻滚


func _physics_process(_delta: float) -> void:
	var dir := Input.get_axis("move_left", "move_right")
	apply_central_force(Vector2(dir * move_force, 0))       # 只能"推"它，速度由物理引擎算
	if Input.is_action_just_pressed("jump"):
		apply_central_impulse(Vector2(0, -jump_impulse))    # 是否站在地上，还得自己另外检测
#endregion
