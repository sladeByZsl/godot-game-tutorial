## 竞技场关卡：用代码搭出地面、墙、平台、掩体和箱子，然后在运行时烘焙导航网格。
## 本脚本挂在 NavigationRegion3D 上，所有几何体都是它的子节点，
## 这样烘焙时（解析模式 ROOT_NODE_CHILDREN）才会被算进导航网格。
extends NavigationRegion3D

signal baked

const TEX := "res://textures/"

var mats: Dictionary = {}
var _csg_walls: Array[CSGShape3D] = []


func _ready() -> void:
	_make_materials()
	_build()
	_bake()


#region materials
## PBR 材质：albedo（底色/贴图）、metallic（金属度）、roughness（粗糙度）、normal（法线贴图）。
## 用三平面映射（triplanar）后，不管方块多大，贴图都按世界坐标平铺，不会被拉伸。
func _make_materials() -> void:
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_texture = load(TEX + "floor.png")
	floor_mat.roughness = 0.85
	floor_mat.uv1_triplanar = true
	floor_mat.uv1_world_triplanar = true
	floor_mat.uv1_scale = Vector3.ONE * 0.5          # 贴图一张覆盖 2m×2m
	mats.floor = floor_mat

	var wall_mat := StandardMaterial3D.new()
	wall_mat.albedo_texture = load(TEX + "wall.png")
	wall_mat.normal_enabled = true
	wall_mat.normal_texture = load(TEX + "wall_normal.png")
	wall_mat.normal_scale = 1.4
	wall_mat.roughness = 0.9
	wall_mat.uv1_triplanar = true
	wall_mat.uv1_world_triplanar = true
	wall_mat.uv1_scale = Vector3.ONE * 0.25          # 一张覆盖 4m
	mats.wall = wall_mat
	# 墙裙：同一张贴图乘上青绿色，下半截墙像刷过漆
	var paint: StandardMaterial3D = wall_mat.duplicate()
	paint.albedo_color = Color(0.36, 0.62, 0.64)
	paint.roughness = 0.7
	mats.paint = paint

	var metal := StandardMaterial3D.new()
	metal.albedo_texture = load(TEX + "metal.png")
	metal.metallic = 0.85
	metal.roughness = 0.38
	metal.uv1_triplanar = true
	metal.uv1_world_triplanar = true
	mats.metal = metal

	# 集装箱：同一张金属贴图，用 albedo_color 染成不同颜色（贴图颜色 × albedo_color）
	for tint: Array in [["teal", Color(0.35, 0.75, 0.78)], ["orange", Color(1.0, 0.55, 0.28)], ["red", Color(0.85, 0.32, 0.3)]]:
		var m: StandardMaterial3D = metal.duplicate()
		m.albedo_color = tint[1]
		m.metallic = 0.55
		m.roughness = 0.5
		mats[tint[0]] = m

	var hazard := StandardMaterial3D.new()
	hazard.albedo_texture = load(TEX + "hazard.png")
	hazard.roughness = 0.6
	hazard.uv1_triplanar = true
	hazard.uv1_world_triplanar = true
	hazard.uv1_scale = Vector3.ONE * 1.5
	mats.hazard = hazard

	var crate := StandardMaterial3D.new()
	crate.albedo_texture = load(TEX + "crate.png")
	crate.roughness = 0.8
	crate.uv1_triplanar = true                        # 物体空间三平面：每个面正好一张贴图
	crate.uv1_scale = Vector3.ONE / 1.2
	crate.uv1_offset = Vector3.ONE * 0.5
	mats.crate = crate

	var lamp := StandardMaterial3D.new()
	lamp.albedo_color = Color(1.0, 0.8, 0.5)
	lamp.emission_enabled = true                      # 自发光 + glow：灯泡周围会有一圈光晕
	lamp.emission = Color(1.0, 0.7, 0.4)
	lamp.emission_energy_multiplier = 4.0
	mats.lamp = lamp
#endregion


func _build() -> void:
	# 地面和四面外墙
	_box(Vector3(0, -0.5, 0), Vector3(42, 1, 42), mats.floor)
	for s: int in [-1, 1]:
		_box(Vector3(0, 3, s * 20.5), Vector3(42, 6, 1), mats.wall)
		_box(Vector3(s * 20.5, 3, 0), Vector3(1, 6, 40), mats.wall)
		_box(Vector3(0, 6.15, s * 20.5), Vector3(42.4, 0.3, 1.4), mats.metal, 0.0, false)
		_box(Vector3(s * 20.5, 6.15, 0), Vector3(1.4, 0.3, 42.4), mats.metal, 0.0, false)
		_box(Vector3(0, 0.9, s * 19.97), Vector3(40, 1.8, 0.06), mats.paint, 0.0, false)
		_box(Vector3(s * 19.97, 0.9, 0), Vector3(0.06, 1.8, 40), mats.paint, 0.0, false)
		_box(Vector3(0, 0.15, s * 19.93), Vector3(40, 0.3, 0.1), mats.hazard, 0.0, false)
		_box(Vector3(s * 19.93, 0.15, 0), Vector3(0.1, 0.3, 40), mats.hazard, 0.0, false)
	# 头顶的钢梁：不挡路，但会在地上投下一条条阴影
	for z: float in [-13.0, -6.5, 0.0, 6.5, 13.0]:
		_box(Vector3(0, 6.6, z), Vector3(41, 0.5, 0.35), mats.metal, 0.0, false)

	_build_platform()
	_build_cover()
	_build_arches()


#region platform
func _build_platform() -> void:
	var h := 1.6
	_box(Vector3(0, h / 2, 0), Vector3(8, h, 8), mats.wall)
	_box(Vector3(0, h + 0.05, 0), Vector3(8.2, 0.1, 8.2), mats.metal)
	# 两侧坡道：一个旋转过的薄方块。坡度 = atan(高 / 长) ≈ 17.7°，小于导航网格的最大坡度 45°
	for s: int in [-1, 1]:
		var run := 5.0
		var angle := atan2(h, run)
		var length := sqrt(run * run + h * h)
		var ramp := _box(Vector3.ZERO, Vector3(length, 0.4, 3.2), mats.hazard)
		var top_center := Vector3(s * (4.0 + run / 2.0), h / 2.0, 0)
		ramp.rotation.z = -angle * s                  # 绕 z 轴转：+x 一侧的坡往 -x 方向（平台）升高
		ramp.position = top_center - ramp.basis.y * 0.2
	# 平台四角的灯柱：自发光灯泡 + 不带阴影的点光源做补光
	for c: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var p := Vector3(c.x * 3.6, h, c.y * 3.6)
		_box(p + Vector3(0, 1.1, 0), Vector3(0.18, 2.2, 0.18), mats.metal, 0.0, false)
		var bulb := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.2
		sphere.height = 0.4
		sphere.radial_segments = 12
		sphere.rings = 6
		bulb.mesh = sphere
		bulb.material_override = mats.lamp
		bulb.position = p + Vector3(0, 2.35, 0)
		add_child(bulb)
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.72, 0.45)
		light.light_energy = 1.6
		light.omni_range = 7.0
		light.position = bulb.position
		add_child(light)
#endregion


func _build_cover() -> void:
	# 半人高的掩体墙（蹲下能完全藏住）
	for spec: Array in [[Vector3(-9, 0.6, 11), Vector3(5, 1.2, 0.5), 0.0], [Vector3(9, 0.6, -11), Vector3(5, 1.2, 0.5), 0.0],
			[Vector3(0, 0.6, -14), Vector3(0.5, 1.2, 5), 0.0], [Vector3(0, 0.6, 14), Vector3(0.5, 1.2, 5), 0.0],
			[Vector3(-13, 0.6, -7), Vector3(4, 1.2, 0.5), 0.6], [Vector3(13, 0.6, 7), Vector3(4, 1.2, 0.5), 0.6]]:
		_box(spec[0], spec[1], mats.wall, spec[2])
	# 柱子
	for p: Vector2 in [Vector2(-7, -7), Vector2(7, 7), Vector2(-7, 7), Vector2(7, -7)]:
		_box(Vector3(p.x, 3, p.y), Vector3(1, 6, 1), mats.wall)
		_box(Vector3(p.x, 0.25, p.y), Vector3(1.2, 0.5, 1.2), mats.hazard, 0.0, false)
	# 集装箱
	_box(Vector3(-15.5, 1.3, -14), Vector3(2.5, 2.6, 6.5), mats.teal, 0.25)
	_box(Vector3(15.5, 1.3, 14), Vector3(2.5, 2.6, 6.5), mats.orange, 0.25)
	_box(Vector3(15.8, 1.3, -3), Vector3(6.5, 2.6, 2.5), mats.red, -0.1)
	_box(Vector3(15.8, 3.9, -3.2), Vector3(6.5, 2.6, 2.5), mats.teal, -0.05)
	# 箱子堆：每个稍微转一点角度，看起来不那么整齐
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for stack: Array in [[Vector3(-15, 0, 15), 3], [Vector3(14, 0, -15), 3], [Vector3(-4.5, 0, 9), 2],
			[Vector3(5, 0, -8.5), 2], [Vector3(-16, 0, 3), 2], [Vector3(10, 0, 16), 1]]:
		var base: Vector3 = stack[0]
		for i: int in stack[1]:
			var off := Vector3(rng.randf_range(-0.1, 0.1) + (i % 2) * 1.3, 0.6, rng.randf_range(-0.1, 0.1))
			_box(base + off, Vector3.ONE * 1.2, mats.crate, rng.randf_range(-0.3, 0.3))
		if stack[1] >= 2:
			_box(base + Vector3(0.6, 1.8, 0), Vector3.ONE * 1.2, mats.crate, rng.randf_range(-0.4, 0.4))


#region csg_arch
## 带拱门的隔墙：CSG 做布尔运算，一个方块减去一个圆柱和一个方块，就挖出了门洞。
## CSG 适合快速搭原型（白盒）。它也能自带碰撞（use_collision），但导航烘焙解析 CSG 时
## 要把网格从显卡读回来，很慢；所以这里等 CSG 算完后，把形状烘焙成一个普通的静态碰撞体。
func _build_arches() -> void:
	for s: int in [-1, 1]:
		var wall := CSGBox3D.new()
		wall.size = Vector3(0.8, 4.0, 9.0)
		wall.position = Vector3(s * 10.5, 2.0, 0)
		wall.material = mats.wall
		var door := CSGBox3D.new()
		door.operation = CSGShape3D.OPERATION_SUBTRACTION
		door.size = Vector3(2.0, 2.2, 2.8)
		door.position = Vector3(0, -0.9, 0)          # 相对墙中心：门洞底部贴地
		wall.add_child(door)
		var round_top := CSGCylinder3D.new()
		round_top.operation = CSGShape3D.OPERATION_SUBTRACTION
		round_top.radius = 1.4
		round_top.height = 2.0
		round_top.sides = 20
		round_top.rotation.z = PI / 2                # 圆柱默认沿 y 轴，转 90° 让它横穿墙体
		round_top.position = Vector3(0, 0.2, 0)
		wall.add_child(round_top)
		add_child(wall)
		_csg_walls.append(wall)


## CSG 的结果 → ConcavePolygonShape3D（三角形网格碰撞）→ 挂到一个 StaticBody3D 上。
func _csg_to_static_body(csg: CSGShape3D) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	shape.shape = csg.bake_collision_shape()
	body.add_child(shape)
	body.transform = csg.transform
	add_child(body)
#endregion


#region box_helper
## 造一个带碰撞的方块：StaticBody3D（碰撞层 1 = 世界）+ BoxShape3D + 同样大小的 BoxMesh。
func _box(pos: Vector3, size: Vector3, mat: Material, yaw := 0.0, collide := true) -> Node3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	if not collide:
		mi.position = pos
		mi.rotation.y = yaw
		add_child(mi)
		return mi
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.add_child(mi)
	body.position = pos
	body.rotation.y = yaw
	add_child(body)
	return body
#endregion


#region bake
## 运行时烘焙导航网格。NavigationMesh 的几个关键参数：
##   agent_radius：把障碍物"加粗"这么多，敌人的中心沿网格走就不会蹭墙
##   agent_height / agent_max_climb / agent_max_slope：多矮的洞钻不过去、多高的台阶迈得上、多陡的坡爬得上
##   cell_size / cell_height：体素大小，必须和导航地图的设置一致（默认 0.25）
func _bake() -> void:
	var nm := NavigationMesh.new()
	nm.agent_radius = 0.5
	nm.agent_height = 1.75                        # 取 cell_height 的整数倍，否则会被向上取整并打警告
	nm.agent_max_climb = 0.5
	nm.agent_max_slope = 40.0
	nm.cell_size = 0.25
	nm.cell_height = 0.25
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_collision_mask = 1                 # 只把"世界"层的碰撞体当作地形
	navigation_mesh = nm
	# CSG 的布尔运算在本帧末尾才执行，等一帧再取它的形状，然后再等物理服务器登记好新碰撞体
	await get_tree().process_frame
	for csg in _csg_walls:
		_csg_to_static_body(csg)
	await get_tree().physics_frame
	var t0 := Time.get_ticks_msec()
	bake_navigation_mesh(false)                   # false = 在主线程同步烘焙（Web 版没有线程）
	print("导航网格烘焙完成：%d 个多边形，用时 %d ms" % [nm.get_polygon_count(), Time.get_ticks_msec() - t0])
	baked.emit()
#endregion
