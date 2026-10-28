## 弹幕图案。全部是静态函数：给一个池、一个发射点，按极坐标算出每颗子弹的速度。
##   速度向量 = (cos θ, sin θ) × 速率，也就是 Vector2.from_angle(θ) * speed
## Godot 的 2D 坐标 y 轴向下，所以 θ = 0 朝右、θ = PI/2 朝下。
class_name Danmaku
extends RefCounted


#region ring
## 环形：n 颗子弹均匀分布在一整圈上，第 i 颗的角度 θᵢ = offset + i × (2π / n)。
static func ring(pool: BulletPool, origin: Vector2, n: int, speed: float,
		offset := 0.0, kind := Bullet.Kind.PINK) -> void:
	for i in n:
		var theta := offset + TAU * i / n
		pool.spawn(origin, Vector2.from_angle(theta) * speed, kind)
#endregion


#region aimed
## 自机狙：先求出从发射点指向玩家的角度 base = atan2(dy, dx)，
## 再在 base 两边均匀张开 spread 弧度的扇形（n = 1 时就是正对玩家的一颗）。
static func aimed(pool: BulletPool, origin: Vector2, target: Vector2, n: int, spread: float,
		speed: float, kind := Bullet.Kind.RICE) -> void:
	var base := (target - origin).angle()          # 等价于 atan2(target.y - origin.y, target.x - origin.x)
	for i in n:
		var t := 0.0 if n == 1 else float(i) / (n - 1) - 0.5    # -0.5 … +0.5
		pool.spawn(origin, Vector2.from_angle(base + t * spread) * speed, kind)
#endregion


#region spiral
## 螺旋：每次只发 arms 颗（均匀分布），但发射角 angle 由调用者每帧累加。
## 子弹沿直线飞，不同时刻发出的子弹排在一起，看起来就是一条旋转的螺旋臂。
static func spiral(pool: BulletPool, origin: Vector2, angle: float, arms: int, speed: float,
		kind := Bullet.Kind.VIOLET) -> void:
	ring(pool, origin, arms, speed, angle, kind)
#endregion


#region flower
## 花瓣：仍是一圈，但速率随角度变化 v(θ) = v₀ × (1 + depth × sin(petals × θ))，
## 跑得快的方向形成"花瓣尖"。
static func flower(pool: BulletPool, origin: Vector2, n: int, speed: float, petals: int,
		depth: float, offset := 0.0, kind := Bullet.Kind.ORANGE) -> void:
	for i in n:
		var theta := offset + TAU * i / n
		var v := speed * (1.0 + depth * sin(petals * (theta - offset)))
		pool.spawn(origin, Vector2.from_angle(theta) * v, kind)
#endregion
