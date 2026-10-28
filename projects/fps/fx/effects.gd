## 命中特效：弹孔、火花、伤害数字、敌人的弹道、爆开的碎片。
## 场景里只有一个 Effects 节点，其他脚本通过静态函数 Effects.spark(...) 调用。
class_name Effects
extends Node3D

const MAX_HOLES := 48

static var _instance: Effects

var _holes: Array[MeshInstance3D] = []
var _next_hole := 0
var _hole_mesh: QuadMesh
var _sparks: Array[CPUParticles3D] = []
var _next_spark := 0
var _tracer_mat: StandardMaterial3D


func _ready() -> void:
	_instance = self
	_hole_mesh = QuadMesh.new()
	_hole_mesh.size = Vector2(0.14, 0.14)
	var hole_mat := StandardMaterial3D.new()
	hole_mat.albedo_texture = load("res://textures/bullet_hole.png")
	hole_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hole_mat.roughness = 1.0
	_hole_mesh.material = hole_mat
	for i in 8:
		_sparks.append(_make_spark())
	_tracer_mat = StandardMaterial3D.new()
	_tracer_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_tracer_mat.albedo_color = Color(1.0, 0.45, 0.2)
	_tracer_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA


#region bullet_hole
## 弹孔。Compatibility 渲染器不支持 Decal 节点（实测放上去什么都不显示），
## 所以用一个贴着表面的小四边形代替：位置沿法线抬起 5 毫米防止和墙面"打架"（z-fighting），
## 朝向让四边形的 +Z（正面）对准法线。用对象池循环复用，最多同时存在 48 个。
static func bullet_hole(pos: Vector3, normal: Vector3) -> void:
	if _instance:
		_instance._add_hole(pos, normal)


func _add_hole(pos: Vector3, normal: Vector3) -> void:
	var hole: MeshInstance3D
	if _holes.size() < MAX_HOLES:
		hole = MeshInstance3D.new()
		hole.mesh = _hole_mesh
		hole.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(hole)
		_holes.append(hole)
	else:
		hole = _holes[_next_hole]        # 池满了就覆盖最旧的那个
		_next_hole = (_next_hole + 1) % MAX_HOLES
	var up := Vector3.UP if absf(normal.y) < 0.99 else Vector3.RIGHT
	# looking_at 让 -Z 指向给定方向；我们要 +Z 朝外（= 法线），所以让 -Z 指向 -normal
	hole.global_basis = Basis.looking_at(-normal, up)
	hole.rotate_object_local(Vector3.BACK, randf() * TAU)
	hole.global_position = pos + normal * 0.005
#endregion


static func spark(pos: Vector3, normal: Vector3, color: Color) -> void:
	if _instance:
		var p := _instance._sparks[_instance._next_spark]
		_instance._next_spark = (_instance._next_spark + 1) % _instance._sparks.size()
		p.global_position = pos + normal * 0.03
		p.direction = normal
		p.color = color
		p.restart()


func _make_spark() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.emitting = false
	p.one_shot = true
	p.amount = 10
	p.lifetime = 0.35
	p.explosiveness = 1.0
	p.spread = 50.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 5.0
	p.gravity = Vector3(0, -12, 0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.0
	var m := BoxMesh.new()
	m.size = Vector3(0.03, 0.03, 0.03)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true     # 粒子的 color 通过顶点色传进来
	m.material = mat
	p.mesh = m
	add_child(p)
	return p


#region damage_number
## 伤害数字：Label3D 设成 billboard（永远面向相机）、no_depth_test（不被墙挡住），
## 往上飘 0.8 米并淡出，然后自己删掉。爆头用更大的黄色字。
static func damage_number(pos: Vector3, amount: float, headshot: bool) -> void:
	if not _instance:
		return
	var label := Label3D.new()
	label.text = ("爆头 %d" if headshot else "%d") % roundi(amount)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.fixed_size = true                  # 远近都一样大
	label.pixel_size = 0.0012
	label.font_size = 40 if headshot else 30
	label.outline_size = 10
	label.modulate = Color(1.0, 0.85, 0.2) if headshot else Color(1, 1, 1)
	label.outline_modulate = Color(0.1, 0.05, 0.05, 0.8)
	_instance.add_child(label)
	label.global_position = pos + Vector3(randf_range(-0.2, 0.2), 0.2, 0)
	var tw := label.create_tween().set_parallel()
	tw.tween_property(label, "global_position:y", label.global_position.y + 0.8, 0.7).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(label, "modulate:a", 0.0, 0.7).set_delay(0.25)
	tw.chain().tween_callback(label.queue_free)
#endregion


## 敌人的弹道：一根很细的发光长方体，0.12 秒内淡出。让玩家看清子弹从哪里来。
static func tracer(from: Vector3, to: Vector3) -> void:
	if not _instance or from.distance_to(to) < 0.1:
		return
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.025, 0.025, from.distance_to(to))
	mi.mesh = box
	var mat: StandardMaterial3D = _instance._tracer_mat.duplicate()
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_instance.add_child(mi)
	mi.global_position = (from + to) / 2.0
	mi.look_at(to, Vector3.UP if absf((to - from).normalized().y) < 0.99 else Vector3.RIGHT)
	var tw := mi.create_tween()
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.12)
	tw.tween_callback(mi.queue_free)


#region explode
## 敌人死亡时"爆开"：把身体上的每个网格换成一个 RigidBody3D 碎片，给一个向外的冲量。
## 碎片在第 4 层（碎片层），只和世界、碎片碰撞，不会挡住玩家和子弹。3 秒后缩小消失。
static func explode(parts: Array[MeshInstance3D], center: Vector3, push: Vector3) -> void:
	if not _instance:
		return
	for part in parts:
		var body := RigidBody3D.new()
		body.collision_layer = 8
		body.collision_mask = 1 | 8
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = part.get_aabb().size.max(Vector3.ONE * 0.08)
		shape.shape = box
		shape.position = part.get_aabb().get_center()
		body.add_child(shape)
		var mi := MeshInstance3D.new()
		mi.mesh = part.mesh
		mi.material_override = part.get_active_material(0)
		body.add_child(mi)
		_instance.add_child(body)
		body.global_transform = part.global_transform
		var out := (part.global_position - center).normalized()
		body.apply_central_impulse((out * 2.5 + push * 2.0 + Vector3.UP * 2.5) * body.mass)
		body.angular_velocity = Vector3(randf_range(-8, 8), randf_range(-8, 8), randf_range(-8, 8))
		var tw := body.create_tween()
		tw.tween_interval(3.0)
		tw.tween_property(mi, "scale", Vector3.ZERO, 0.4)
		tw.tween_callback(body.queue_free)
#endregion
