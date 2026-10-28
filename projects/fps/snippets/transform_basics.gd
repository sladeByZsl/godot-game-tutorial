## 第 15 章用到的语法小例子：Transform3D、Basis、欧拉角、四元数、look_at、相机。
## 这个脚本不在场景里使用，只是为了让章节里的代码片段都能通过编译检查。
extends Node3D


#region transform
func transform_parts() -> void:
	# Transform3D = basis（3×3 矩阵：旋转 + 缩放）+ origin（位置）
	var t := global_transform
	var right := t.basis.x        # 物体自己的 +X（右）在世界里指向哪里
	var up := t.basis.y           # 自己的 +Y（上）
	var forward := -t.basis.z     # Godot 约定 -Z 是"前方"
	var pos := t.origin           # 等于 global_position
	# 把局部坐标转成世界坐标：先乘 basis（旋转、缩放），再加 origin（平移）
	var muzzle_local := Vector3(0.2, -0.1, -0.5)
	var muzzle_world := t * muzzle_local          # 等价于 t.basis * muzzle_local + t.origin
	var back_to_local := t.affine_inverse() * muzzle_world
	print(right, up, forward, pos, back_to_local)
#endregion


#region euler
func euler_examples() -> void:
	# rotation 是欧拉角（弧度），rotation_degrees 是同样的值换成度。
	# Godot 默认的旋转顺序是 YXZ：先绕 Y（偏航），再绕 X（俯仰），最后绕 Z（翻滚）。
	rotation_degrees = Vector3(-30, 45, 0)        # 抬头 30°，向左转 45°
	var b := Basis.from_euler(Vector3(deg_to_rad(-30), deg_to_rad(45), 0.0))   # 同样的朝向
	print(b.get_euler())                          # 再从 Basis 读回欧拉角
	# 相对当前朝向再转一点：rotate_y 绕父节点的 Y 轴，rotate_object_local 绕自己的轴
	rotate_y(deg_to_rad(10))
	rotate_object_local(Vector3.RIGHT, deg_to_rad(5))
#endregion


#region quaternion
## 在两个朝向之间平滑过渡：转成四元数做球面插值（slerp），不会出现万向节锁，
## 走的也是最短的弧线。直接对欧拉角做 lerp 可能会"绕远路"。
func turn_towards(target_basis: Basis, weight: float) -> void:
	var from := Quaternion(basis.orthonormalized())
	var to := Quaternion(target_basis.orthonormalized())
	basis = Basis(from.slerp(to, weight))
#endregion


#region look_at
func face_target(target: Node3D) -> void:
	# look_at 让自己的 -Z 指向目标；第二个参数是"上"方向，不能和视线平行
	look_at(target.global_position, Vector3.UP)
	# 只想水平转身（不抬头低头）时，把目标的高度换成自己的高度
	var flat := Vector3(target.global_position.x, global_position.y, target.global_position.z)
	if not flat.is_equal_approx(global_position):
		look_at(flat, Vector3.UP)
#endregion


#region camera
func setup_camera(cam: Camera3D) -> void:
	cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	cam.fov = 75.0                 # 垂直视野角（keep_aspect 默认是 KEEP_HEIGHT）
	cam.near = 0.05                # 近裁剪面：比它近的东西不画
	cam.far = 250.0                # 远裁剪面：near 和 far 的比值越大，深度精度越差
	# 正交相机：没有近大远小，size 是画面的高度（米），常用于等距视角和小地图
	var top_down := Camera3D.new()
	top_down.projection = Camera3D.PROJECTION_ORTHOGONAL
	top_down.size = 40.0
	# 屏幕坐标 ↔ 世界坐标：鼠标拾取、在 3D 物体头顶显示 2D 血条都要用到
	var screen_pos := cam.unproject_position(Vector3(0, 1, -5))
	var ray_dir := cam.project_ray_normal(screen_pos)
	print(screen_pos, ray_dir)
	top_down.free()
#endregion
