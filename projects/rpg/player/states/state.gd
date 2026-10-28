## 状态基类：每个状态是一个节点，自己管进入、退出、每帧更新、输入。
#region state
class_name BaseState
extends Node

var machine: StateMachine


func enter(_msg := {}) -> void:
	pass


func exit() -> void:
	pass


func handle_input(_event: InputEvent) -> void:
	pass


func physics_update(_delta: float) -> void:
	pass
#endregion
