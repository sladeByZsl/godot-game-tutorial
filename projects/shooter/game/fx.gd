## 特效：爆炸粒子（固定数量的发射器轮流使用）+ 冲击波圆环和闪光（统一在一个 _draw 里画）。
class_name Fx
extends Node2D

const EMITTERS := 16
const SPARK := preload("res://art/spark.png")

#region params
@export var particle_amount := 40:     ## 每次爆炸的粒子数
	set(v):
		particle_amount = v
		_rebuild()
@export_enum("GPU", "CPU") var particle_mode := "GPU":   ## GPUParticles2D 还是 CPUParticles2D
	set(v):
		particle_mode = v
		_rebuild()
#endregion

var _emitters: Array = []      # GPUParticles2D 或 CPUParticles2D，两者接口几乎一样
var _next := 0
var _rings: Array = []          # 每项 [位置, 颜色, 最大半径, 已过时间, 持续时间]


func _ready() -> void:
	_rebuild()


#region particles
## 用代码搭一个 GPUParticles2D 当模板。CPU 模式下用 convert_from_particles() 把同样的设置抄过去。
func _make_gpu() -> GPUParticles2D:
	var p := GPUParticles2D.new()
	p.amount = maxi(1, particle_amount)
	p.lifetime = 0.7
	p.one_shot = true
	p.explosiveness = 1.0              # 1 = 所有粒子在同一瞬间发出
	p.emitting = false
	p.texture = SPARK
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD   # 加法混合：重叠处越叠越亮
	p.material = add
	var m := ParticleProcessMaterial.new()
	m.particle_flag_disable_z = true
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = 4.0
	m.spread = 180.0
	m.initial_velocity_min = 60.0
	m.initial_velocity_max = 280.0
	m.gravity = Vector3.ZERO
	m.damping_min = 150.0
	m.damping_max = 250.0
	m.scale_min = 0.9
	m.scale_max = 2.0
	var fade := Gradient.new()                   # 从亮白到透明
	fade.set_color(0, Color(1.25, 1.25, 1.25, 1.0))
	fade.set_color(1, Color(1, 1, 1, 0.0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	m.color_ramp = ramp
	p.process_material = m
	return p


func _rebuild() -> void:
	if not is_inside_tree():
		return
	for e in _emitters:
		e.queue_free()
	_emitters.clear()
	if particle_amount <= 0:
		return
	for i in EMITTERS:
		var gpu := _make_gpu()
		if particle_mode == "CPU":
			var cpu := CPUParticles2D.new()
			cpu.convert_from_particles(gpu)      # 把 GPU 版的所有参数（包括过程材质）转换过来
			cpu.emitting = false
			cpu.material = gpu.material
			gpu.free()
			add_child(cpu)
			_emitters.append(cpu)
		else:
			add_child(gpu)
			_emitters.append(gpu)
#endregion


## 在 pos（Field 局部坐标）炸开。big = 大爆炸（同时用两个发射器 + 更大的冲击波）。
func explode(pos: Vector2, color: Color, big := false) -> void:
	for k in (2 if big else 1):
		if _emitters.is_empty():
			break
		var e = _emitters[_next]
		_next = (_next + 1) % _emitters.size()
		e.position = pos
		e.modulate = color
		e.speed_scale = 0.7 if (big and k == 1) else 1.0
		e.restart()                       # 一次性发射器：restart() 让它从头再喷一次
	ring(pos, color, 90.0 if big else 42.0, 0.45 if big else 0.3)
	_rings.append([pos, Color(2, 2, 2), 26.0 if big else 12.0, 0.0, 0.12])   # 中心白闪


## 只喷粒子，不画冲击波（命中火花）。
func burst(pos: Vector2, color: Color) -> void:
	if _emitters.is_empty():
		return
	var e = _emitters[_next]
	_next = (_next + 1) % _emitters.size()
	e.position = pos
	e.modulate = color
	e.speed_scale = 1.4
	e.restart()


## 扩散的圆环（冲击波、拾取、护盾破碎）。
func ring(pos: Vector2, color: Color, radius: float, duration := 0.35) -> void:
	_rings.append([pos, color, radius, 0.0, duration])


## 小火花（打中 Boss）。
func spark(pos: Vector2) -> void:
	_rings.append([pos, Color(2.2, 2.0, 1.4), 8.0, 0.0, 0.1])


func active_particles() -> int:
	var n := 0
	for e in _emitters:
		if e.emitting:
			n += particle_amount
	return n


func _process(delta: float) -> void:
	var i := 0
	while i < _rings.size():
		_rings[i][3] += delta
		if _rings[i][3] >= _rings[i][4]:
			_rings.remove_at(i)
		else:
			i += 1
	queue_redraw()


func _draw() -> void:
	for r: Array in _rings:
		var k: float = r[3] / r[4]                      # 0 → 1
		var col: Color = r[1]
		var radius: float = r[2] * (1.0 - pow(1.0 - k, 3.0))   # ease-out：先快后慢地扩张
		draw_arc(r[0], radius, 0, TAU, 48, Color(col, (1.0 - k) * 0.9), 3.0 * (1.0 - k) + 1.0, true)
		if r[4] <= 0.12:
			draw_circle(r[0], radius, Color(col, (1.0 - k) * 0.6))
