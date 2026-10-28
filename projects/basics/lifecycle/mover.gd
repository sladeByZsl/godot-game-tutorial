## 来回移动的小球。use_physics 决定它在 _process 还是 _physics_process 里移动。
## 物理帧率调低时，在 _physics_process 里移动的那个会一顿一顿的。
extends Node2D

@export var use_physics := false
@export var width := 300.0
@export var color := Color.WHITE

var _t := 0.0
var _start_x := 0.0


func _ready() -> void:
	_start_x = position.x


#region move
func _process(delta: float) -> void:
	if not use_physics:
		_step(delta)


func _physics_process(delta: float) -> void:
	if use_physics:
		_step(delta)


func _step(delta: float) -> void:
	_t += delta
	position.x = _start_x + (0.5 - 0.5 * cos(_t * 2.0)) * width   # 在起点和 width 之间来回
#endregion


func _draw() -> void:
	Pal.glow(self, Vector2.ZERO, 22.0, Color(color, 0.6))
	draw_circle(Vector2.ZERO, 7.0, color, true, -1.0, true)
	draw_circle(Vector2(-2, -2), 2.5, Color(1, 1, 1, 0.7), true, -1.0, true)
