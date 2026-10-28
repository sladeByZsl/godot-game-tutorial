## 跟随主角的相机：平滑、死区（drag margin）、边界（limit）、前瞻（look-ahead）和基于 trauma 的震动。
## 作为 Player 的子节点：相机节点的位置 = 主角位置 + 前瞻偏移，
## Camera2D 自己负责死区和平滑，真正的画面中心会"追"这个点。
class_name GameCamera
extends Camera2D

#region params
@export var smoothing_speed := 6.0:     ## 平滑速度，0 = 关闭平滑（画面硬跟）
	set(v):
		smoothing_speed = v
		position_smoothing_enabled = v > 0.0
		position_smoothing_speed = maxf(v, 0.1)
@export var look_ahead := 64.0          ## 朝面对方向多看多少像素
@export var drag_margin_h := 0.15:      ## 水平死区（占半个屏幕宽的比例）
	set(v):
		drag_margin_h = v
		drag_horizontal_enabled = v > 0.0
		drag_left_margin = v
		drag_right_margin = v
@export var drag_margin_v := 0.2:       ## 竖直死区
	set(v):
		drag_margin_v = v
		drag_vertical_enabled = v > 0.0
		drag_top_margin = v
		drag_bottom_margin = v
@export var use_limits := true:         ## 不让镜头拍到关卡外面
	set(v):
		use_limits = v
		limit_enabled = v
@export var zoom_level := 1.0:
	set(v):
		zoom_level = v
		zoom = Vector2(v, v)
@export var show_debug := false         ## 在屏幕上画出死区和前瞻目标
#endregion

@export_group("震动")
@export var max_offset := Vector2(28, 20)   ## trauma = 1 时的最大偏移（像素）
@export var max_roll := 0.06                ## trauma = 1 时的最大旋转（弧度）
@export var trauma_decay := 1.4             ## 每秒衰减多少 trauma

var trauma := 0.0
var _noise := FastNoiseLite.new()
var _time := 0.0
var _look := 0.0
var _base_y := 0.0

@onready var player: Player = get_parent()


func _ready() -> void:
	_base_y = position.y
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 0.9
	ignore_rotation = false
	Fx.camera = self
	# 带 setter 的属性在声明时赋的默认值不会触发 setter，这里手动应用一次
	smoothing_speed = smoothing_speed
	drag_margin_h = drag_margin_h
	drag_margin_v = drag_margin_v
	use_limits = use_limits
	zoom_level = zoom_level
	Tuning.bind(self, "camera", ["smoothing_speed", "look_ahead", "drag_margin_h",
			"drag_margin_v", "use_limits", "zoom_level", "show_debug"])


func set_bounds(rect: Rect2) -> void:
	limit_left = int(rect.position.x)
	limit_top = int(rect.position.y)
	limit_right = int(rect.end.x)
	limit_bottom = int(rect.end.y)


func _process(delta: float) -> void:
	_update_look_ahead(delta)
	_update_shake(delta)


#region look_ahead
## 前瞻：相机目标点朝主角面对的方向偏移，跑得越快偏得越多；用指数平滑避免转身时镜头猛甩。
func _update_look_ahead(delta: float) -> void:
	var speed_k := clampf(absf(player.velocity.x) / player.max_speed, 0.0, 1.0)
	var target := player.facing * look_ahead * speed_k
	_look = lerpf(_look, target, 1.0 - exp(-3.0 * delta))
	position = Vector2(_look, _base_y)
#endregion


#region shake
## trauma（创伤值）模型：受击时累加 trauma（0~1），随时间线性衰减；
## 实际震动幅度 = trauma²，小冲击几乎不晃，大冲击晃得厉害，衰减也显得自然。
## 偏移用连续噪声而不是每帧随机数，画面是"晃"而不是"抖"。
func add_trauma(amount: float) -> void:
	trauma = minf(trauma + amount, 1.0)


func _update_shake(delta: float) -> void:
	trauma = maxf(trauma - trauma_decay * delta, 0.0)
	_time += delta * 30.0
	var s := trauma * trauma * Fx.shake
	offset = Vector2(
		max_offset.x * s * _noise.get_noise_2d(1.0, _time),
		max_offset.y * s * _noise.get_noise_2d(100.0, _time))
	rotation = max_roll * s * _noise.get_noise_2d(200.0, _time)
	Tuning.stat("trauma", snappedf(trauma, 0.01))
#endregion
