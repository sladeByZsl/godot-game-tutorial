## 节点式状态机：子节点就是各个状态，同一时刻只有一个处于激活。
#region machine
class_name StateMachine
extends Node

signal state_changed(from: StringName, to: StringName)

@export var initial_state: BaseState
var state: BaseState


func _ready() -> void:
	for child in get_children():
		if child is BaseState:
			child.machine = self
	await owner.ready          # 等角色本身准备好再进入第一个状态
	state = initial_state
	state.enter()


func _unhandled_input(event: InputEvent) -> void:
	if state:
		state.handle_input(event)


func _physics_process(delta: float) -> void:
	if state:
		state.physics_update(delta)


func transition_to(target: StringName, msg := {}) -> void:
	var next := get_node_or_null(NodePath(target)) as BaseState
	if next == null:
		push_error("没有这个状态：%s" % target)
		return
	var from := state.name
	state.exit()
	state = next
	state.enter(msg)
	state_changed.emit(from, target)
#endregion
