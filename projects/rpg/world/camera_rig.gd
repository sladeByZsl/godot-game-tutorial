## 跟随玩家的镜头。两种模式：平滑跟随，或者塞尔达式的"按房间切换"。
extends Camera2D

#region camera_params
@export var room_mode := false:       ## 按房间切换镜头
	set(v):
		room_mode = v
		_room = NO_ROOM
		_apply_smoothing()
@export var smoothing := 6.0:         ## 跟随平滑速度，0 = 关闭平滑
	set(v):
		smoothing = v
		_apply_smoothing()
#endregion

const ROOM_SIZE := Vector2(320, 176)   # 20 × 11 格
const NO_ROOM := Vector2i(-99, -99)

var target: Node2D
var _room := NO_ROOM
var _tween: Tween


func _ready() -> void:
	Tuning.bind(self, "camera", ["room_mode", "smoothing"])
	_apply_smoothing()


#region follow
func _physics_process(_delta: float) -> void:
	if target == null:
		return
	if not room_mode:
		global_position = target.global_position
		return
	var room := Vector2i((target.global_position / ROOM_SIZE).floor())
	if room == _room:
		return
	var first := _room == NO_ROOM
	_room = room
	var center := (Vector2(room) + Vector2(0.5, 0.5)) * ROOM_SIZE
	if _tween:
		_tween.kill()
	if first:
		global_position = center
	else:
		_tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
		_tween.tween_property(self, "global_position", center, 0.45).set_trans(Tween.TRANS_SINE)
#endregion


## 瞬移（读档、复活）后调用，跳过平滑直接对准目标。
func snap() -> void:
	_room = NO_ROOM
	if target:
		global_position = target.global_position
	reset_smoothing()


func _apply_smoothing() -> void:
	position_smoothing_enabled = smoothing > 0.0 and not room_mode
	position_smoothing_speed = maxf(smoothing, 0.1)
