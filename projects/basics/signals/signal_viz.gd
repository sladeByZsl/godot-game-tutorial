## 把"谁连接了谁"画出来。连线不是写死的：每帧都用 get_signal_connection_list() 读取真实的连接，
## 所以一次性连接（CONNECT_ONE_SHOT）触发后，连线会自己消失。
## 信号本身是同步的、一瞬间就执行完；这里的脉冲动画只是把执行顺序放慢给你看。
class_name SignalViz
extends Node2D

static var current: SignalViz

const EVENTS_RECT := Rect2(606, 456, 150, 46)
const SIGNAL_COLORS := [Pal.PINK, Pal.ORANGE, Pal.TEAL, Pal.PURPLE, Pal.YELLOW, Pal.BLUE]
const CALL_COLOR := Color("8fa3c8")

@export var pulse_speed := 1.2     ## 脉冲每秒走完多少条线
@export var show_wires := true
@export var show_labels := true

var _nodes: Array[Object] = []
var _watched: Array[Array] = []          # [对象, 信号名]
var _call_links: Array[Dictionary] = []  # 父节点"向下调用"之类的固定连线
var _wires: Array[Dictionary] = []
var _pulses: Array[Dictionary] = []
var _flash := {}                         # 对象 id -> 剩余闪光时间
var _seq_frame := -1
var _seq := 0
var _counts := {}                        # 信号名 -> 发出次数
var _placed: Array[Rect2] = []           # 本帧已经画了标签的位置


func _enter_tree() -> void:
	current = self


func _exit_tree() -> void:
	if current == self:
		current = null


#region watch
## 监视这些对象发出的信号。监视器必须最先连接，这样它总是第一个收到信号，
## 记录下来的顺序才和真实的执行顺序一致。
func watch(nodes: Array) -> void:
	_nodes.assign(nodes)
	for n: Object in nodes:
		for s: Dictionary in _signals_of(n):
			var argc: int = s.args.size()
			var spy: Callable = [_spy0, _spy1, _spy2][argc]
			n.connect(s.name, spy.bind(n, s.name))
			_watched.append([n, s.name])


func _signals_of(n: Object) -> Array:
	if n is BaseButton:
		return [{"name": "pressed", "args": []}]
	var script: Script = n.get_script()
	return script.get_script_signal_list() if script else []
#endregion


func add_call_link(from: Object, to: Object, label: String) -> void:
	_call_links.append({"from": from, "to": to, "label": label})


## 让节点报告一次"直接调用"（不是信号），画成灰色虚线上的脉冲。
static func report(from: Object, to: Object, label: String) -> void:
	if current != null:
		current._add_pulse(from, to, label, CALL_COLOR, true)


func _spy0(n: Object, sig: StringName) -> void:
	_on_emitted(n, sig, [])


func _spy1(a: Variant, n: Object, sig: StringName) -> void:
	_on_emitted(n, sig, [a])


func _spy2(a: Variant, b: Variant, n: Object, sig: StringName) -> void:
	_on_emitted(n, sig, [a, b])


#region on_emitted
func _on_emitted(n: Object, sig: StringName, args: Array) -> void:
	_counts[sig] = _counts.get(sig, 0) + 1
	Tuning.stat("信号 " + sig, _counts[sig])
	var label := "%s(%s)" % [sig, ", ".join(PackedStringArray(args.map(func(a: Variant) -> String: return str(a))))]
	for c: Dictionary in n.get_signal_connection_list(sig):
		var target := (c.callable as Callable).get_object()
		if target == self or not _nodes.has(target):
			continue
		_add_pulse(n, target, label, _color_of(sig), false)
#endregion


func _add_pulse(from: Object, to: Object, label: String, color: Color, is_call: bool) -> void:
	# 同一帧里发生的一连串事件，按发生顺序依次播放
	var frame := Engine.get_process_frames()
	if frame != _seq_frame:
		_seq_frame = frame
		_seq = 0
	_pulses.append({"from": from, "to": to, "label": label, "color": color, "t": 0.0,
		"delay": _seq * 0.85 / pulse_speed, "call": is_call})
	_seq += 1


func _color_of(sig: StringName) -> Color:
	return SIGNAL_COLORS[absi(hash(String(sig))) % SIGNAL_COLORS.size()]


func _rect_of(n: Object) -> Rect2:
	if n == Events:
		return Rect2(to_global(EVENTS_RECT.position), EVENTS_RECT.size)
	if n is Control:
		return (n as Control).get_global_rect()
	if n.has_method("viz_rect"):
		return n.viz_rect()
	return Rect2((n as Node2D).global_position, Vector2.ONE)


func _process(delta: float) -> void:
	_rebuild_wires()
	for p in _pulses:
		if p.delay > 0.0:
			p.delay -= delta
			continue
		p.t += delta * pulse_speed
		if p.t >= 1.0:
			_flash[p.to.get_instance_id()] = 1.0
	_pulses = _pulses.filter(func(p: Dictionary) -> bool: return p.t < 1.0)
	for k in _flash.keys():
		_flash[k] -= delta * 2.0
		if _flash[k] <= 0.0:
			_flash.erase(k)
	queue_redraw()


#region rebuild
func _rebuild_wires() -> void:
	_wires.clear()
	for w: Array in _watched:
		var n: Object = w[0]
		for c: Dictionary in n.get_signal_connection_list(w[1]):
			var callable: Callable = c.callable
			var target := callable.get_object()
			if target == self or not _nodes.has(target):
				continue
			_wires.append({"from": n, "to": target, "color": _color_of(w[1]),
				"label": "%s → %s" % [w[1], callable.get_method()],
				"one_shot": (c.flags & CONNECT_ONE_SHOT) != 0})
#endregion


## 两个矩形之间的连线（三次贝塞尔曲线）。bow 越大，弯得越厉害。
func _curve(a: Rect2, b: Rect2, bow: float, offset: float) -> PackedVector2Array:
	var p0: Vector2
	var p1: Vector2
	var c0: Vector2
	var c1: Vector2
	if b.get_center().y < a.position.y - 30:          # 目标在上方
		p0 = to_local(Vector2(a.get_center().x + offset, a.position.y))
		var spread := clampf((a.get_center().x - b.get_center().x) * 0.2, -b.size.x * 0.4, b.size.x * 0.4)
		p1 = to_local(Vector2(b.get_center().x + spread + offset, b.end.y))
		c0 = p0 + Vector2(0, -70)
		c1 = p1 + Vector2(0, 70)
	elif b.position.y > a.end.y + 30:                 # 目标在下方
		var spread := clampf((b.get_center().x - a.get_center().x) * 0.2, -a.size.x * 0.4, a.size.x * 0.4)
		p0 = to_local(Vector2(a.get_center().x + spread + offset, a.end.y))
		p1 = to_local(Vector2(b.get_center().x + offset, b.position.y))
		c0 = p0 + Vector2(0, 50)
		c1 = p1 + Vector2(0, -50)
	else:                                             # 同一排：从底部绕下去
		p0 = to_local(Vector2(a.get_center().x + offset, a.end.y))
		p1 = to_local(Vector2(b.get_center().x - offset, b.end.y))
		var d := 40.0 + bow + absf(p1.x - p0.x) * 0.12
		c0 = p0 + Vector2(0, d)
		c1 = p1 + Vector2(0, d)
	var pts := PackedVector2Array()
	for i in 33:
		pts.append(_bezier(p0, c0, c1, p1, i / 32.0))
	return pts


func _bezier(p0: Vector2, c0: Vector2, c1: Vector2, p1: Vector2, t: float) -> Vector2:
	var u := 1.0 - t
	return u * u * u * p0 + 3.0 * u * u * t * c0 + 3.0 * u * t * t * c1 + t * t * t * p1


## 给每条连线一个稳定的形状：同一个发送方的第 n 条线弯得更深一点，避免重叠。
func _shape(from: Object, to: Object, is_call: bool) -> PackedVector2Array:
	var index := 0
	for w in _wires:
		if w.from == from:
			if w.to == to:
				break
			index += 1
	var offset := 10.0 if is_call else -10.0
	return _curve(_rect_of(from), _rect_of(to), index * 46.0, offset)


func _draw() -> void:
	_draw_tree()
	_placed.clear()
	for n in _nodes:
		var r := _rect_of(n)
		_placed.append(Rect2(to_local(r.position), r.size))
	if show_wires:
		for l in _call_links:
			var pts := _shape(l.from, l.to, true)
			for i in range(0, pts.size() - 1, 2):
				draw_line(pts[i], pts[i + 1], Color(CALL_COLOR, 0.55), 1.5, true)
			Pal.arrow(self, pts[pts.size() - 3], pts[pts.size() - 1], Color(CALL_COLOR, 0.8), 1.5, 8.0)
		for w in _wires:
			var pts := _shape(w.from, w.to, false)
			draw_polyline(pts, Color(w.color, 0.5), 2.0, true)
			Pal.arrow(self, pts[pts.size() - 3], pts[pts.size() - 1], w.color, 2.0, 9.0)
		if show_labels:
			for w in _wires:
				_pill(_shape(w.from, w.to, false), w.label, w.color, w.one_shot)
			for l in _call_links:
				_pill(_shape(l.from, l.to, true), l.label, CALL_COLOR, false)
	for p in _pulses:
		if p.delay > 0.0:
			continue
		var pts := _shape(p.from, p.to, p.call)
		var f: float = p.t * (pts.size() - 1)
		var i := mini(int(f), pts.size() - 2)
		var pos := pts[i].lerp(pts[i + 1], f - i)
		Pal.glow(self, pos, 26.0, Color(p.color, 0.9))
		draw_circle(pos, 4.5, Color.WHITE, true, -1.0, true)
		var lw := Pal.text_width(p.label, 13) + 12.0
		Pal.panel(self, Rect2(pos + Vector2(10, -26), Vector2(lw, 20)), Color(0.04, 0.05, 0.1, 0.85), Color(p.color, 0.8), 6, 1)
		Pal.text(self, pos + Vector2(16, -11), p.label, 13, Color.WHITE)
	for n in _nodes:
		var k := (n as Object).get_instance_id()
		if _flash.has(k):
			var r := _rect_of(n)
			var a: float = _flash[k]
			draw_rect(Rect2(to_local(r.position), r.size).grow(6.0 + (1.0 - a) * 10.0), Color(1, 1, 1, a * 0.6), false, 2.0)


## 画出 SignalLab 和它的子节点之间的树形连线，以及右下角的事件总线卡片。
func _draw_tree() -> void:
	var lab := get_parent() as Node2D
	var lab_rect := _rect_of(lab)
	var top := to_local(Vector2(lab_rect.get_center().x, lab_rect.end.y))
	var bus_y := top.y + 66.0
	var xs: Array[float] = []
	for n in _nodes:
		if n is Node and n != lab and (n as Node).get_parent() == lab:
			var r := _rect_of(n)
			var x := to_local(r.get_center()).x
			xs.append(x)
			draw_line(Vector2(x, bus_y), Vector2(x, to_local(r.position).y - 4.0), Pal.LINE, 1.5, true)
			Pal.text(self, Vector2(x, to_local(r.end).y + 16.0), String((n as Node).name), 11, Pal.TEXT3, 1)
	if not xs.is_empty():
		draw_line(top, Vector2(top.x, bus_y), Pal.LINE, 1.5, true)
		draw_line(Vector2(xs.min(), bus_y), Vector2(xs.max(), bus_y), Pal.LINE, 1.5, true)
	var lr := Rect2(to_local(lab_rect.position), lab_rect.size)
	Pal.panel(self, lr, Pal.PANEL_HI, Pal.BLUE, 10, 1)
	Pal.text(self, lr.get_center() + Vector2(0, -2), "SignalLab", 15, Pal.TEXT, 1)
	Pal.text(self, lr.get_center() + Vector2(0, 14), "父节点：负责把子节点连起来", 10, Pal.TEXT2, 1)
	Pal.panel(self, EVENTS_RECT, Pal.PANEL_HI, Pal.PURPLE, 10, 1)
	Pal.text(self, EVENTS_RECT.get_center() + Vector2(0, -3), "Events", 15, Pal.TEXT, 1)
	Pal.text(self, EVENTS_RECT.get_center() + Vector2(0, 14), "自动加载 · 事件总线", 10, Pal.TEXT2, 1)


## 在连线上找一个不和别的标签、节点重叠的位置，画一个小标签。
func _pill(pts: PackedVector2Array, text: String, color: Color, one_shot: bool) -> void:
	var s := text + ("  [ONE_SHOT]" if one_shot else "")
	var w := Pal.text_width(s, 11) + 12.0
	var best := Rect2()
	for t: float in [0.5, 0.38, 0.62, 0.28, 0.72, 0.2, 0.8, 0.12, 0.88]:
		var pos := pts[roundi(t * (pts.size() - 1))]
		var r := Rect2(pos - Vector2(w * 0.5, 9), Vector2(w, 18))
		if best == Rect2():
			best = r
		if not _placed.any(func(o: Rect2) -> bool: return o.grow(2).intersects(r)):
			best = r
			break
	_placed.append(best)
	Pal.panel(self, best, Color(0.06, 0.08, 0.14, 0.92), Color(color, 0.6), 9, 1)
	Pal.text(self, best.get_center() + Vector2(0, 4), s, 11, color.lerp(Pal.TEXT, 0.3), 1)
