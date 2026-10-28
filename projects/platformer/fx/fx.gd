## 手感效果（"果汁"）的开关和工具函数，作为自动加载单例 Fx 使用。
## 每种效果都有强度参数，设成 0 / 关 就能对比"有"和"没有"的区别。
extends Node

const DUST := preload("res://fx/dust.tscn")
const SPARKLE := preload("res://fx/sparkle.tscn")

#region params
@export var animation := true        ## 角色动画（AnimationPlayer）
@export var squash := 1.0            ## 挤压拉伸强度，0 = 关
@export var particles := true        ## 粒子：烟尘、闪光、彩带
@export var shake := 1.0             ## 屏幕震动强度倍数，0 = 关
@export var hit_stop := 0.06         ## 命中停顿时长（秒），0 = 关
#endregion

var camera: GameCamera               ## 相机在 _ready 里把自己登记到这里
var _freeze_id := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # 命中停顿期间自己也要继续计时
	Tuning.bind(self, "fx", ["animation", "squash", "particles", "shake", "hit_stop"])
	Tuning.action_triggered.connect(func(a: String) -> void:
		if a == "shake":
			add_trauma(0.7))


#region hit_stop
## 命中停顿：把整个游戏的时间流速压到接近 0，过一小会儿再恢复。
## 计时器的第 4 个参数 ignore_time_scale = true，否则它自己也会被"冻住"。
func freeze(duration: float) -> void:
	if duration <= 0.0:
		return
	_freeze_id += 1
	var id := _freeze_id
	Engine.time_scale = 0.05
	await get_tree().create_timer(duration, true, false, true).timeout
	if id == _freeze_id:      # 期间又触发了新的停顿，就让新的那次负责恢复
		Engine.time_scale = 1.0
#endregion


func add_trauma(amount: float) -> void:
	if is_instance_valid(camera) and shake > 0.0:
		camera.add_trauma(amount)


#region burst
## 在 pos 处放一次性粒子：实例化场景 → 设置 → 加进场景树 → 播完自动删除。
func burst(scene: PackedScene, pos: Vector2, color: Color, amount: int, dir := Vector2.ZERO) -> void:
	if not particles or amount <= 0:
		return
	var p := scene.instantiate() as CPUParticles2D
	p.amount = amount
	p.color = color
	if dir != Vector2.ZERO:
		p.direction = dir
		p.spread = 30.0
	p.global_position = pos
	get_tree().current_scene.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)
#endregion


func puff(pos: Vector2, color: Color, amount: int, dir := Vector2.ZERO) -> void:
	burst(DUST, pos, color, amount, dir)


func sparkle(pos: Vector2, color: Color, amount := 10) -> void:
	burst(SPARKLE, pos, color, amount)
