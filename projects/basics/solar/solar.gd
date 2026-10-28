## 太阳系场景的根节点：负责星空背景、轨道和轨迹线，并把参数绑定到三个天体上。
extends Node2D

const SUN_CENTER := Vector2(480, 290)

@export var show_trails := true
@export var show_orbits := true
@export var show_axes := true:
	set(value):
		show_axes = value
		for body: CelestialBody in [sun, earth, moon]:
			if body != null:
				body.show_axes = value

var _stars: Array[Vector4] = []                  # x, y, 大小, 闪烁相位
var _earth_trail := PackedVector2Array()
var _moon_trail := PackedVector2Array()
var _overlay := Node2D.new()                     # 画在最上层的标签

#region nodes
@onready var sun: CelestialBody = $Sun            # 直接子节点
@onready var earth: CelestialBody = $Sun/Earth    # 用路径往下找
@onready var moon: CelestialBody = %Moon          # 场景唯一名称，不管藏多深都能直接拿到
#endregion


#region bind
func _ready() -> void:
	sun.position = SUN_CENTER
	Tuning.bind(sun, "sun", ["spin_speed", "body_scale"])
	Tuning.bind(earth, "earth", ["spin_speed", "distance", "detach"])
	Tuning.bind(moon, "moon", ["spin_speed", "distance"])
	Tuning.bind(self, "solar", ["show_axes", "show_trails", "show_orbits"])
	Tuning.action_triggered.connect(_on_action)
	_make_stars()
#endregion
	_overlay.name = "Labels"
	_overlay.z_index = 10
	_overlay.draw.connect(_draw_labels)
	add_child(_overlay)


func _make_stars() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in 170:
		_stars.append(Vector4(rng.randf_range(-260, 1220), rng.randf_range(-200, 740),
			rng.randf_range(0.6, 1.9), rng.randf() * TAU))


func _on_action(action_name: String) -> void:
	if action_name == "reset":
		_earth_trail.clear()
		_moon_trail.clear()


func _process(_delta: float) -> void:
	_push(_earth_trail, to_local(earth.global_position), 320)
	_push(_moon_trail, to_local(moon.global_position), 900)
	queue_redraw()
	_overlay.queue_redraw()
	#region stats
	Tuning.stat("地球 position", _fmt(earth.position))
	Tuning.stat("地球 global_position", _fmt(earth.global_position - get_parent().global_position))
	Tuning.stat("月亮 global_rotation", "%d°" % roundi(fposmod(moon.global_rotation_degrees, 360.0)))
	#endregion


func _push(trail: PackedVector2Array, p: Vector2, max_points: int) -> void:
	if not trail.is_empty() and trail[trail.size() - 1].distance_to(p) > 40.0:
		trail.clear()    # 参数突变导致位置跳变时，旧轨迹就不连上了
	if trail.is_empty() or trail[trail.size() - 1].distance_to(p) > 1.5:
		trail.append(p)
	if trail.size() > max_points:
		trail.remove_at(0)


func _fmt(v: Vector2) -> String:
	return "(%d, %d)" % [roundi(v.x), roundi(v.y)]


func _draw() -> void:
	var t := Time.get_ticks_msec() / 1000.0
	for s in _stars:
		var a := 0.35 + 0.35 * sin(t * 1.3 + s.w)
		draw_circle(Vector2(s.x, s.y), s.z, Color(0.8, 0.86, 1.0, a), true, -1.0, true)
	if show_orbits:
		var sun_p := to_local(sun.global_position)
		var earth_p := to_local(earth.global_position)
		if not earth.top_level:
			draw_arc(sun_p, earth.distance * sun.global_scale.x, 0, TAU, 128, Color(Pal.BLUE, 0.22), 1.0, true)
		draw_arc(earth_p, moon.distance * earth.global_scale.x, 0, TAU, 64, Color(Pal.TEXT2, 0.22), 1.0, true)
	if show_trails:
		_draw_trail(_earth_trail, Pal.BLUE, 2.0)
		_draw_trail(_moon_trail, Color("d8dcef"), 1.5)


func _draw_trail(trail: PackedVector2Array, color: Color, width: float) -> void:
	if trail.size() < 2:
		return
	var colors := PackedColorArray()
	colors.resize(trail.size())
	for i in trail.size():
		colors[i] = Color(color, 0.75 * float(i) / trail.size())
	draw_polyline_colors(trail, colors, width, true)


func _draw_labels() -> void:
	for body: CelestialBody in [sun, earth, moon]:
		var lines := body.label_lines()
		var h := 6.0 + 15.0 * lines.size()
		var gap := body.radius * body.global_scale.x + 8.0
		# 地球的标签放在上方，太阳和月亮的放在下方，尽量不互相挡住
		var p := to_local(body.global_position) + Vector2(0, -gap - h if body == earth else gap)
		var w := 0.0
		for l in lines:
			w = maxf(w, Pal.text_width(l, 12))
		Pal.panel(_overlay, Rect2(p.x - w * 0.5 - 7, p.y, w + 14, h), Color(0.05, 0.07, 0.13, 0.72), Color(0, 0, 0, 0), 5, 0)
		for i in lines.size():
			Pal.text(_overlay, Vector2(p.x, p.y + 15 + 15 * i), lines[i], 13 if i == 0 else 11,
				Pal.TEXT if i == 0 else Pal.TEXT2, 1)
