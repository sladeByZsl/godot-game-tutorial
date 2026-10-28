## 生命周期场景的根节点：生成一小棵 LifeNode 树，并把日志、时间轴画出来。
## 本节点的 process_mode 是 ALWAYS（暂停时也要继续画界面）；
## 被观察的节点放在 Specimens 下面，它的 process_mode 是 PAUSABLE，会被暂停。
extends Node2D

const TREE_RECT := Rect2(16, 76, 300, 300)
const LOG_RECT := Rect2(328, 76, 616, 300)
const MOTION_RECT := Rect2(16, 386, 928, 56)
const TIME_RECT := Rect2(16, 452, 928, 80)
const STRUCTURE := ["_init", "_enter_tree", "_ready", "_exit_tree", "PREDELETE", ""]
const CB_COLORS := {
	"_init": Pal.TEXT2, "_enter_tree": Pal.BLUE, "_ready": Pal.GREEN, "_process": Pal.ORANGE,
	"_physics_process": Pal.PURPLE, "_exit_tree": Pal.RED, "PREDELETE": Pal.PINK, "": Pal.TEXT3,
}

#region engine_params
@export var physics_ticks := 60:            ## 每秒物理帧数
	set(value):
		physics_ticks = value
		Engine.physics_ticks_per_second = value
@export var time_scale := 1.0:              ## 时间缩放：传给回调的 delta 会乘上它
	set(value):
		time_scale = value
		Engine.time_scale = value
@export var paused := false:                ## 暂停场景树
	set(value):
		paused = value
		if is_inside_tree():
			get_tree().paused = value
@export var physics_interpolation := false: ## 物理插值：让低物理帧率下的移动也显得平滑
	set(value):
		physics_interpolation = value
		if is_inside_tree():
			get_tree().physics_interpolation = value
#endregion
@export var child_count := 2:
	set(value):
		child_count = value
		if is_node_ready():
			respawn()
@export var log_frames := 3:
	set(value):
		log_frames = value
		LifeLog.max_frame_logs = value

var _root: LifeNode = null
var _next_id := 1

@onready var specimens: Node = $Specimens


func _ready() -> void:
	LifeLog.entries.clear()
	LifeLog.max_frame_logs = log_frames
	Tuning.bind(self, "life", ["physics_ticks", "time_scale", "paused", "physics_interpolation", "child_count", "log_frames"])
	_make_buttons()
	respawn()


func _exit_tree() -> void:
	# 离开这个小场景时，把全局设置恢复原样，免得影响别的场景
	Engine.physics_ticks_per_second = 60
	Engine.time_scale = 1.0
	get_tree().paused = false
	get_tree().physics_interpolation = false


func _make_buttons() -> void:
	var specs := [["重新生成", respawn, Pal.BLUE], ["添加子节点", add_child_node, Pal.GREEN],
		["删除子节点", remove_child_node, Pal.RED], ["清空日志", func() -> void: LifeLog.entries.clear(), Pal.TEXT2]]
	for i in specs.size():
		var b := Button.new()
		b.text = specs[i][0]
		b.position = Vector2(476 + i * 118, 20)
		b.size = Vector2(110, 36)
		Pal.style_button(b, specs[i][2])
		b.pressed.connect(specs[i][1])
		add_child(b)


#region spawn
func respawn() -> void:
	if is_instance_valid(_root):
		_root.free()                          # 立即删除：马上触发 _exit_tree
	LifeLog.write("", "", "———— 重新生成 ————")
	_root = LifeNode.new("Root")              # _init() 在这一行被调用，此时还不在场景树里
	_root.name = "Root"
	_root.feeds_timeline = true
	for i in child_count:
		var child := LifeNode.new("Child%d" % (i + 1))
		child.name = child.label
		_root.add_child(child)                # Root 还不在树里，所以这里不会触发 _enter_tree
		if i == 0:
			var grand := LifeNode.new("GrandChild")
			grand.name = grand.label
			child.add_child(grand)
	_next_id = child_count + 1
	specimens.add_child(_root)                # 整棵树一起进树：先 _enter_tree，再 _ready
#endregion


#region add_remove
func add_child_node() -> void:
	if not is_instance_valid(_root):
		return
	LifeLog.write("", "", "———— 添加子节点 ————")
	var child := LifeNode.new("Child%d" % _next_id)
	child.name = child.label
	_next_id += 1
	_root.add_child(child)          # Root 已经在树里，新节点马上 _enter_tree、_ready


func remove_child_node() -> void:
	if not is_instance_valid(_root) or _root.get_child_count() == 0:
		return
	var last := _root.get_child(-1)
	LifeLog.write("", "", "———— %s.queue_free() ————" % last.name)
	last.queue_free()               # 不会立刻删除，等这一帧结束才 _exit_tree
#endregion


func _process(_delta: float) -> void:
	queue_redraw()
	Tuning.stat("FPS", Engine.get_frames_per_second())
	Tuning.stat("_process 次/秒", LifeLog.rate(LifeLog.process_times))
	Tuning.stat("_physics_process 次/秒", LifeLog.rate(LifeLog.physics_times))


func _draw() -> void:
	_draw_tree_panel()
	_draw_log_panel()
	_draw_motion_panel()
	_draw_timeline()


func _draw_tree_panel() -> void:
	Pal.panel(self, TREE_RECT, Pal.PANEL, Pal.LINE)
	Pal.text(self, TREE_RECT.position + Vector2(14, 24), "Specimens 下的节点", 13, Pal.TEXT2)
	if is_instance_valid(_root):
		_draw_node_row(_root, 0, [0])


func _draw_node_row(n: Node, depth: int, row: Array) -> void:
	var y: float = TREE_RECT.position.y + 40.0 + row[0] * 40.0
	if y > TREE_RECT.end.y - 30:
		return
	var x := TREE_RECT.position.x + 14.0 + depth * 26.0
	var r := Rect2(x, y, TREE_RECT.end.x - x - 14.0, 30)
	row[0] += 1
	var ln := n as LifeNode
	var col: Color = CB_COLORS.get(ln.last_callback, Pal.TEXT2) if ln else Pal.TEXT2
	var age := (Time.get_ticks_usec() - ln.last_usec) / 1_000_000.0 if ln else 9.0
	var flash := clampf(1.0 - age / 0.6, 0.0, 1.0)
	if depth > 0:
		draw_line(Vector2(x - 14, y - 6), Vector2(x - 14, y + 15), Pal.LINE, 1.5)
		draw_line(Vector2(x - 14, y + 15), Vector2(x, y + 15), Pal.LINE, 1.5)
	if flash > 0.0:
		Pal.glow(self, r.get_center(), r.size.x * 0.6, Color(col, 0.25 * flash))
	Pal.panel(self, r, Pal.PANEL_HI.lerp(col, 0.12 * flash), col.lerp(Pal.LINE, 0.6 - 0.6 * flash), 7)
	draw_circle(Vector2(x + 13, y + 15), 4.0, col, true, -1.0, true)
	Pal.text(self, Vector2(x + 24, y + 20), String(n.name), 14, Pal.TEXT)
	if ln:
		Pal.text(self, Vector2(r.end.x - 10, y + 20), "P %d  F %d" % [ln.process_calls, ln.physics_calls], 11, Pal.TEXT3, 2)
	for c in n.get_children():
		_draw_node_row(c, depth + 1, row)


## 日志分两栏：左边是"结构性"的回调（进树、就绪、离开），从最近一次操作开始显示；
## 右边是每帧都会调用的 _process / _physics_process，显示最新的几条。
func _draw_log_panel() -> void:
	Pal.panel(self, LOG_RECT, Pal.PANEL, Pal.LINE)
	var structural: Array[Dictionary] = []
	var per_frame: Array[Dictionary] = []
	for e in LifeLog.entries:
		if e.cb == "":
			structural.clear()    # 每次操作（标记行）开始一段新的记录
			per_frame.clear()
		if STRUCTURE.has(e.cb):
			structural.append(e)
		else:
			per_frame.append(e)
	var cap := 15
	var half := LOG_RECT.size.x * 0.5
	Pal.text(self, LOG_RECT.position + Vector2(14, 24), "进树 / 就绪 / 离开（按发生顺序）", 13, Pal.TEXT2)
	Pal.text(self, LOG_RECT.position + Vector2(half + 8, 24), "每帧回调（每个节点只记前 %d 次）" % LifeLog.max_frame_logs, 13, Pal.TEXT2)
	draw_line(LOG_RECT.position + Vector2(half - 4, 38), LOG_RECT.position + Vector2(half - 4, LOG_RECT.size.y - 12), Pal.LINE, 1.0)
	for i in mini(structural.size(), cap):
		var more := structural.size() - (cap - 1)
		if i == cap - 1 and more > 1:
			Pal.text(self, LOG_RECT.position + Vector2(14, 52 + i * 16.5), "…… 还有 %d 行" % more, 12, Pal.TEXT3)
			break
		_draw_log_line(structural[i], LOG_RECT.position + Vector2(14, 52 + i * 16.5))
	var start := maxi(0, per_frame.size() - cap)
	for i in range(start, per_frame.size()):
		_draw_log_line(per_frame[i], LOG_RECT.position + Vector2(half + 8, 52 + (i - start) * 16.5))


func _draw_log_line(e: Dictionary, p: Vector2) -> void:
	if e.cb == "":
		Pal.text(self, p, e.extra, 12, Pal.TEXT3)
		return
	var col: Color = CB_COLORS.get(e.cb, Pal.TEXT)
	Pal.text(self, p, "帧%d" % e.frame, 11, Pal.TEXT3)
	Pal.text(self, p + Vector2(42, 0), e.who, 12, Pal.TEXT)
	draw_rect(Rect2(p + Vector2(124, -10), Vector2(3, 12)), col)
	Pal.text(self, p + Vector2(132, 0), e.cb, 12, col)
	if e.cb.begins_with("_p"):
		Pal.text(self, p + Vector2(296, 0), e.extra.trim_prefix("delta = "), 11, Pal.TEXT3, 2)


func _draw_motion_panel() -> void:
	Pal.panel(self, MOTION_RECT, Pal.PANEL, Pal.LINE)
	for i in 2:
		var y := MOTION_RECT.position.y + 17.0 + i * 22.0
		draw_line(Vector2(MOTION_RECT.position.x + 200, y), Vector2(MOTION_RECT.end.x - 16, y), Pal.LINE, 2.0)
		Pal.text(self, Vector2(MOTION_RECT.position.x + 14, y + 5), ["在 _process 里移动", "在 _physics_process 里移动"][i], 12, [Pal.ORANGE, Pal.PURPLE][i])


func _draw_timeline() -> void:
	Pal.panel(self, TIME_RECT, Pal.PANEL, Pal.LINE)
	var now := Time.get_ticks_usec()
	var x0 := TIME_RECT.position.x + 200.0
	var x1 := TIME_RECT.end.x - 16.0
	var head := "时间轴（真实时间，每条竖线是 Root 的一次回调）"
	if get_tree().paused:
		head += "  · 场景树已暂停"
	Pal.text(self, TIME_RECT.position + Vector2(14, 20), head, 12, Pal.TEXT2 if not get_tree().paused else Pal.RED)
	for s in 4:   # 每 0.5 秒一条刻度
		var x := x1 - s * 0.5 / 1.5 * (x1 - x0)
		draw_line(Vector2(x, TIME_RECT.position.y + 30), Vector2(x, TIME_RECT.end.y - 6), Color(Pal.LINE, 0.7), 1.0)
		if s > 0:
			Pal.text(self, Vector2(x - 4, TIME_RECT.position.y + 20), "-%.1fs" % (s * 0.5), 10, Pal.TEXT3, 2)
	var lanes := [[LifeLog.process_times, "_process", Pal.ORANGE, LifeLog.last_process_delta],
		[LifeLog.physics_times, "_physics_process", Pal.PURPLE, LifeLog.last_physics_delta]]
	for i in 2:
		var y := TIME_RECT.position.y + 42.0 + i * 22.0
		var lane: Array = lanes[i]
		Pal.text(self, Vector2(TIME_RECT.position.x + 14, y + 5), lane[1], 12, lane[2])
		Pal.text(self, Vector2(x0 - 8, y + 5), "%d 次/秒" % LifeLog.rate(lane[0]), 11, Pal.TEXT3, 2)
		draw_line(Vector2(x0, y), Vector2(x1, y), Color(lane[2], 0.12), 12.0)
		for t: int in lane[0]:
			var x := x1 - float(now - t) / LifeLog.WINDOW_USEC * (x1 - x0)
			if x >= x0:
				draw_line(Vector2(x, y - 6), Vector2(x, y + 6), lane[2], 2.0)
