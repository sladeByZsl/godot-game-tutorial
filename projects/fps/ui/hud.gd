## HUD：准星（随散布张开）、命中标记、伤害方向指示、血条、弹药、击杀数。
## 图形部分在 _draw() 里画，文字用 Label。整个 HUD 不接收鼠标（mouse_filter = IGNORE）。
extends Control

var player: Player
var weapons: WeaponManager

var _hit_time := 0.0
var _hit_kill := false
var _hurt := 0.0
var _damage_marks: Array = []     # 每项 [攻击者位置, 剩余时间]
var _message_time := 0.0
var _health_shown := 1.0

@onready var ammo_label: Label = $Ammo
@onready var weapon_label: Label = $WeaponName
@onready var health_label: Label = $Health
@onready var kills_label: Label = $Kills
@onready var fps_label: Label = $Fps
@onready var message_label: Label = $Message
@onready var hint_label: Label = $Hint


func setup(p: Player, w: WeaponManager) -> void:
	player = p
	weapons = w
	weapons.ammo_changed.connect(_on_ammo_changed)
	weapons.hit_landed.connect(_on_hit)
	player.damaged.connect(_on_damaged)
	player.health_changed.connect(func(hp: float, max_hp: float) -> void:
		health_label.text = "%d" % ceili(hp))
	health_label.text = "%d" % ceili(player.health)
	message_label.text = ""


func set_kills(n: int) -> void:
	kills_label.text = "击杀 %d" % n


func show_message(text: String, seconds: float) -> void:
	message_label.text = text
	_message_time = seconds


func set_hint(text: String) -> void:
	hint_label.text = text


func _on_ammo_changed(weapon_name: String, ammo: int, mag: int, reloading: bool) -> void:
	ammo_label.text = "%d / %d" % [ammo, mag]
	weapon_label.text = weapon_name + ("  · 换弹中…" if reloading else "")
	ammo_label.modulate = Color(1.0, 0.45, 0.35) if ammo <= mag / 5 else Color.WHITE


func _on_hit(killed: bool, _headshot: bool) -> void:
	_hit_time = 0.25 if not killed else 0.45
	_hit_kill = killed


func _on_damaged(from_position: Vector3, _amount: float) -> void:
	_hurt = 1.0
	_damage_marks.append([from_position, 1.6])


func _process(delta: float) -> void:
	_hit_time = maxf(_hit_time - delta, 0.0)
	_hurt = maxf(_hurt - delta * 2.0, 0.0)
	for m: Array in _damage_marks:
		m[1] -= delta
	_damage_marks = _damage_marks.filter(func(m: Array) -> bool: return m[1] > 0.0)
	if _message_time > 0.0:
		_message_time -= delta
		if _message_time <= 0.0:
			message_label.text = ""
	if player:
		_health_shown = lerpf(_health_shown, player.health / player.max_health, 1.0 - exp(-10.0 * delta))
	fps_label.text = "%d FPS" % Engine.get_frames_per_second()
	queue_redraw()


func _draw() -> void:
	if not player:
		return
	var c := size / 2.0
	if _hurt > 0.0:
		_draw_vignette(Color(0.8, 0.05, 0.05, _hurt * 0.35))
	_draw_crosshair(c)
	_draw_hit_marker(c)
	_draw_damage_marks(c)
	_draw_health_bar()


#region crosshair
## 散布是"角度"，准星是"像素"。相机的垂直视野角是 fov，屏幕半高对应 fov/2，
## 所以偏离中心 θ 角的点，在屏幕上离中心 tan(θ) / tan(fov/2) × 半高 个像素。
func spread_to_pixels(spread_deg: float) -> float:
	var half_fov := deg_to_rad(player.camera.fov / 2.0)
	return tan(deg_to_rad(spread_deg)) / tan(half_fov) * (size.y / 2.0)


func _draw_crosshair(c: Vector2) -> void:
	var gap := 4.0 + spread_to_pixels(weapons.current_spread())
	var length := 9.0
	var col := Color(1, 1, 1, 0.9)
	var shadow := Color(0, 0, 0, 0.5)
	for d: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		var a := c + d * gap
		var b := c + d * (gap + length)
		draw_line(a + Vector2(1, 1), b + Vector2(1, 1), shadow, 2.0)
		draw_line(a, b, col, 2.0)
	draw_circle(c, 1.5, col)
#endregion


func _draw_hit_marker(c: Vector2) -> void:
	if _hit_time <= 0.0:
		return
	var col := Color(1.0, 0.25, 0.2) if _hit_kill else Color(1, 1, 1)
	col.a = clampf(_hit_time / 0.2, 0.0, 1.0)
	var s := 14.0 if _hit_kill else 10.0
	for d: Vector2 in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
		draw_line(c + d * 5.0, c + d * s, col, 2.5)


#region damage_direction
## 伤害方向指示：把"攻击者位置"转换到玩家自己的坐标系里（乘 basis 的逆），
## 只看水平面：local.x 是右，-local.z 是前。atan2 得到相对正前方的角度，顺时针为正。
func _draw_damage_marks(c: Vector2) -> void:
	for m: Array in _damage_marks:
		var local: Vector3 = player.global_basis.inverse() * (m[0] - player.global_position)
		var angle := atan2(local.x, -local.z)
		var screen_angle := angle - PI / 2.0        # draw_arc 的 0 度在右边，屏幕"上"是 -90°
		var col := Color(1.0, 0.2, 0.15, clampf(m[1], 0.0, 1.0) * 0.85)
		draw_arc(c, 110.0, screen_angle - 0.32, screen_angle + 0.32, 20, col, 7.0, true)
#endregion


func _draw_health_bar() -> void:
	var pos := Vector2(24, size.y - 34)
	var w := 220.0
	draw_rect(Rect2(pos, Vector2(w, 12)), Color(0, 0, 0, 0.45))
	var frac := clampf(_health_shown, 0.0, 1.0)
	var col := Color(0.35, 0.85, 0.5) if frac > 0.35 else Color(1.0, 0.35, 0.3)
	draw_rect(Rect2(pos + Vector2(2, 2), Vector2((w - 4) * frac, 8)), col)


func _draw_vignette(col: Color) -> void:
	var edge := 70.0
	var clear := Color(col, 0.0)
	var r := Rect2(Vector2.ZERO, size)
	# 四条边各画一个从红到透明的渐变（draw_polygon 支持逐顶点颜色）
	draw_polygon([r.position, Vector2(r.end.x, 0), Vector2(r.end.x, edge), Vector2(0, edge)], [col, col, clear, clear])
	draw_polygon([Vector2(0, r.end.y - edge), Vector2(r.end.x, r.end.y - edge), r.end, Vector2(0, r.end.y)], [clear, clear, col, col])
	draw_polygon([Vector2.ZERO, Vector2(edge, 0), Vector2(edge, r.end.y), Vector2(0, r.end.y)], [col, clear, clear, col])
	draw_polygon([Vector2(r.end.x - edge, 0), Vector2(r.end.x, 0), r.end, Vector2(r.end.x - edge, r.end.y)], [clear, col, col, clear])
