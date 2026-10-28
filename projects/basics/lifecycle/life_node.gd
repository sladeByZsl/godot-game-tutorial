## 一个"会说话"的节点：每个生命周期回调被调用时，都往 LifeLog 里写一行。
class_name LifeNode
extends Node

var label := ""
var feeds_timeline := false   # 只有 Root 把每一帧的调用时间记到时间轴上
var process_calls := 0
var physics_calls := 0
var last_callback := ""
var last_usec := 0


#region callbacks
func _init(p_label := "") -> void:
	label = p_label
	_log("_init", "还不在场景树里")


func _enter_tree() -> void:
	_log("_enter_tree")


func _ready() -> void:
	_log("_ready", "子节点都已就绪")


func _process(delta: float) -> void:
	process_calls += 1
	if feeds_timeline:
		LifeLog.tick(false, delta)
	if process_calls <= LifeLog.max_frame_logs:
		_log("_process", "delta = %.4f" % delta)


func _physics_process(delta: float) -> void:
	physics_calls += 1
	if feeds_timeline:
		LifeLog.tick(true, delta)
	if physics_calls <= LifeLog.max_frame_logs:
		_log("_physics_process", "delta = %.4f" % delta)


func _exit_tree() -> void:
	_log("_exit_tree")


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_log("PREDELETE", "对象真正被释放")
#endregion


func _log(callback: String, extra := "") -> void:
	last_callback = callback
	last_usec = Time.get_ticks_usec()
	LifeLog.write(label, callback, extra)
