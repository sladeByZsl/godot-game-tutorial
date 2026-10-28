## 子弹对象池。
## 开着池：游戏开始时一次性建好 pool_size 颗子弹，发射时取一颗、飞出屏幕或命中后放回去，循环使用。
## 关掉池：每次发射都 instantiate() 一个新场景，用完 queue_free()——对比两种方式的统计数据。
class_name BulletPool
extends Node2D

static var nodes_created := 0           ## 所有池累计新建的节点数（统计"每秒新建节点"用）

@export var bullet_scene: PackedScene
@export var use_pool := true:
	set(v):
		use_pool = v
		if is_inside_tree():
			_resize()
@export var pool_size := 384:
	set(v):
		pool_size = v
		if is_inside_tree():
			_resize()
@export var bounds := Rect2(-40, -40, 680, 620)    ## 子弹离开这个矩形就回收（Field 的局部坐标）

var active: Array[Bullet] = []          ## 正在飞的子弹
var _free: Array[Bullet] = []           ## 池里空闲、等待复用的子弹
var _owned := 0                         ## 属于池的子弹总数（空闲 + 正在用）


func _ready() -> void:
	_resize()


func free_count() -> int:
	return _free.size()


#region acquire
## 发射一颗子弹。pos/vel 用 Field 的局部坐标。
func spawn(pos: Vector2, vel: Vector2, kind: Bullet.Kind) -> Bullet:
	var b: Bullet
	if use_pool and not _free.is_empty():
		b = _free.pop_back()                 # 有空闲的：直接拿来用，零分配
	else:
		b = _create()                        # 没开池，或池被掏空了：现场新建
		b.from_pool = use_pool
		if use_pool:
			_owned += 1                      # 池不够用时自动扩容（也可以选择丢弃这颗子弹）
	b.setup(pos, vel, kind)
	b.active = true
	b.show()
	b.process_mode = Node.PROCESS_MODE_INHERIT   # 重新加入物理空间，开始参与碰撞
	active.append(b)
	return b
#endregion


#region release
## 回收一颗子弹。命中时它是在物理回调里被调用的，
## 这时不能把 Area2D 移出物理空间，所以真正的"停用"推迟到这一帧末尾。
func release(b: Bullet) -> void:
	if not b.active:
		return
	b.active = false
	b.hide()
	if b.from_pool:
		_park.call_deferred(b)
	else:
		b.queue_free()                       # 不用池：直接销毁，下次再新建


func _park(b: Bullet) -> void:
	# PROCESS_MODE_DISABLED：不再处理，并且（disable_mode 默认是 REMOVE）从物理空间里拿掉。
	b.process_mode = Node.PROCESS_MODE_DISABLED
	if _owned > pool_size and use_pool:
		_owned -= 1                          # 池缩小了：多出来的直接释放
		b.queue_free()
	elif not use_pool:
		_owned -= 1                          # 运行中关掉了池：旧子弹用完就扔
		b.queue_free()
	else:
		_free.append(b)
#endregion


#region move
## 所有活动子弹在这一个循环里移动。被回收的从数组里"交换删除"（和最后一个交换再 pop），O(1)。
func _physics_process(delta: float) -> void:
	var i := 0
	while i < active.size():
		var b := active[i]
		if b.active:
			if b.turn != 0.0:
				b.velocity = b.velocity.rotated(b.turn * delta)
				b.rotation = b.velocity.angle() if b.kind == Bullet.Kind.RICE else 0.0
			if b.accel != 0.0:
				b.velocity += b.velocity.normalized() * b.accel * delta
			b.position += b.velocity * delta
			if not bounds.has_point(b.position):
				release(b)
		if not b.active:
			active[i] = active[active.size() - 1]
			active.pop_back()
			continue
		i += 1
#endregion


## 把所有活动子弹都回收（炸弹、Boss 换阶段时用），返回回收了多少颗。
func clear_all(on_each: Callable = Callable()) -> int:
	var n := 0
	for b in active:
		if b.active:
			if on_each.is_valid():
				on_each.call(b.position)
			release(b)
			n += 1
	return n


func _create() -> Bullet:
	var b: Bullet = bullet_scene.instantiate()
	b.pool = self
	add_child(b)
	nodes_created += 1 + b.get_child_count()    # Area2D + 子节点（Sprite、CollisionShape）
	return b


## 预分配：把池里的子弹补足到 pool_size（或者释放多余的空闲子弹）。
func _resize() -> void:
	if not use_pool:                         # 关掉池：空闲的子弹没用了，全部释放
		_owned -= _free.size()
		for b in _free:
			b.queue_free()
		_free.clear()
		return
	while _owned < pool_size:
		var b := _create()
		b.from_pool = true
		b.hide()
		b.process_mode = Node.PROCESS_MODE_DISABLED
		_free.append(b)
		_owned += 1
	while _owned > pool_size and not _free.is_empty():
		_free.pop_back().queue_free()
		_owned -= 1
