## 第 5 章：向量、坐标与变换 —— 语法示例。
## 每个 #region 都会被章节引用；run_all() 会把结果打印出来，方便核对章节里写的数值。
extends Node2D


#region vec_basic
func vector_basics() -> void:
	var a := Vector2(3, 4)
	var b := Vector2(2, -1)
	print(a + b)              # (5.0, 3.0)    逐个分量相加
	print(a * 2)              # (6.0, 8.0)    数乘：方向不变，长度翻倍
	print(a.length())         # 5.0           勾股定理 √(3² + 4²)
	print(a.normalized())     # (0.6, 0.8)    方向不变，长度变成 1
	print(a.distance_to(b))   # 5.099...      两点之间的距离 √26
	print(a.direction_to(b))  # 从 a 指向 b 的单位向量，等于 (b - a).normalized()
#endregion


#region vec_dot_cross
func dot_and_cross() -> void:
	var facing := Vector2.RIGHT            # 角色朝右
	var to_enemy := Vector2(1, 1).normalized()
	var d := facing.dot(to_enemy)          # 两个单位向量的点积 = cos(夹角)
	print(d)                               # 0.707...  夹角 45°
	print(d > cos(deg_to_rad(60)))         # true      敌人在 ±60° 的视野内
	var c := facing.cross(to_enemy)        # 2D 叉积是一个数：x1*y2 - y1*x2
	print(c > 0)                           # true      在 Godot 里（y 轴朝下）表示"在右手边/顺时针方向"
	print(rad_to_deg(facing.angle_to(to_enemy)))  # 45.0  带符号的夹角，顺时针为正
#endregion


#region vec_project
func projection() -> void:
	var v := Vector2(4, 3)
	var ground := Vector2(1, 0.5)
	var along := v.project(ground)         # v 在 ground 方向上的分量
	var rest := v - along                  # 剩下的部分和 ground 垂直
	print(along, rest)
	print(is_zero_approx(rest.dot(ground)))   # true
	print(v.slide(ground.orthogonal().normalized()))  # 沿着法线为 n 的平面"滑动"，也就是去掉 n 方向的分量
#endregion


#region vec_lerp
func interpolate(delta: float) -> void:
	var from := Vector2(0, 0)
	var to := Vector2(100, 0)
	print(from.lerp(to, 0.25))             # (25.0, 0.0)   按比例插值：走 25%
	print(from.move_toward(to, 30))        # (30.0, 0.0)   按距离走：最多走 30
	print(from.move_toward(to, 500))       # (100.0, 0.0)  不会冲过头
	# 帧率无关的"平滑跟随"：每帧都 lerp 一点，系数用指数算
	position = position.lerp(to, 1.0 - exp(-10.0 * delta))
#endregion


#region angles
func angles() -> void:
	rotation = deg_to_rad(90)              # rotation 用弧度
	rotation_degrees = 90                  # 或者直接用角度版的属性，两行效果一样
	print(rotation)                        # 1.5707...  即 PI / 2
	print(Vector2.RIGHT.rotated(PI / 2))   # (0.0, 1.0)  右转 90° 指向下方（y 轴朝下）
	print(Vector2.from_angle(PI))          # (-1.0, 0.0)
	print(rad_to_deg(Vector2(0, -1).angle()))   # -90.0  指向屏幕上方
	print(rad_to_deg(angle_difference(deg_to_rad(350), deg_to_rad(10))))  # 20.0  最短的转向角
#endregion


#region transform2d
func transform_basics() -> void:
	# Transform2D 就是两根基向量 x、y 加一个原点 origin
	var t := Transform2D(Vector2(2, 0), Vector2(0, 1), Vector2(100, 50))
	print(t * Vector2(10, 10))             # (120.0, 60.0)  = origin + 10*x + 10*y
	print(t.basis_xform(Vector2(10, 10)))  # (20.0, 10.0)   只用基向量，不加原点：变换"方向"用它
	print(t.affine_inverse() * Vector2(120, 60))   # (10.0, 10.0)  逆变换：从外面换算回来
	# 由旋转、缩放、平移组合出来的变换，和直接写基向量是同一个东西
	var r := Transform2D(PI / 2, Vector2(100, 50))
	print(r.x, r.y)                        # x 基向量 ≈ (0, 1)，y 基向量 ≈ (-1, 0)
	print(r.get_rotation(), r.get_scale(), r.origin)
#endregion


#region parent_child
func parent_child() -> void:
	var parent := Node2D.new()
	var child := Node2D.new()
	parent.add_child(child)
	add_child(parent)                     # 这里假设当前节点自己在原点、没有旋转和缩放
	parent.position = Vector2(200, 100)
	parent.rotation = PI / 2
	parent.scale = Vector2(2, 2)
	child.position = Vector2(30, 0)
	# 子节点的全局变换 = 父节点的全局变换 * 子节点的本地变换
	print(child.global_transform == parent.global_transform * child.transform)  # true
	print(child.global_position)                        # (200.0, 160.0)：先缩放、再旋转、再平移
	print(parent.to_global(Vector2(30, 0)))             # 和上一行一样
	print(parent.to_local(Vector2(200, 160)))           # (30.0, 0.0)：反过来换算
	parent.queue_free()
#endregion


func run_all() -> void:
	parent_child()
	vector_basics()
	dot_and_cross()
	projection()
	interpolate(0.016)
	angles()
	transform_basics()
