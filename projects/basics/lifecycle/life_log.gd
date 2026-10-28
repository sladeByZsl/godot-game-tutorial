## 生命周期日志：一个只有静态成员的类，任何地方都能直接 LifeLog.write(...)。
## 用静态变量是因为 _init() 被调用时节点还不在场景树里，没法用 get_node 去找别的节点。
class_name LifeLog
extends RefCounted

const WINDOW_USEC := 1_500_000            # 时间轴显示最近 1.5 秒

static var entries: Array[Dictionary] = []
static var max_frame_logs := 3            # 每个节点只记录前几次 _process/_physics_process
static var process_times: Array[int] = []    # 最近 1.5 秒内每次 _process 的时间戳（微秒）
static var physics_times: Array[int] = []
static var last_process_delta := 0.0
static var last_physics_delta := 0.0


static func write(who: String, callback: String, extra := "") -> void:
	entries.append({"who": who, "cb": callback, "extra": extra,
		"frame": Engine.get_process_frames(), "usec": Time.get_ticks_usec()})
	if entries.size() > 300:
		entries.pop_front()


static func tick(is_physics: bool, delta: float) -> void:
	var now := Time.get_ticks_usec()
	if is_physics:
		physics_times.append(now)
		last_physics_delta = delta
	else:
		process_times.append(now)
		last_process_delta = delta
	_trim(process_times, now)
	_trim(physics_times, now)


static func _trim(arr: Array[int], now: int) -> void:
	while not arr.is_empty() and now - arr[0] > WINDOW_USEC:
		arr.pop_front()


## 最近 1 秒内的次数。
static func rate(arr: Array[int]) -> int:
	var now := Time.get_ticks_usec()
	var n := 0
	for t in arr:
		if now - t <= 1_000_000:
			n += 1
	return n
