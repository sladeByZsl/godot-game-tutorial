## 信号实验室里的主角：一只史莱姆。
## 它不认识血条，也不认识实验室。它只负责管理自己的血量，变化时"喊一声"（发信号）。
class_name Slime
extends Node2D

#region signals
signal health_changed(current: int, maximum: int)   ## 血量变了：新血量、最大血量
signal died                                         ## 血量归零
#endregion

@export var max_health := 100:
	set(value):
		max_health = value
		health = mini(health, max_health)
		health_changed.emit(health, max_health)

var health := 100
var _hit := 0.0          # 受击闪白，1 → 0
var _squash := 0.0       # 受击压扁
var _heal_glow := 0.0


#region take_damage
func take_damage(amount: int) -> void:
	if health <= 0:
		return
	health = maxi(health - amount, 0)
	_hit = 1.0
	_squash = 1.0
	health_changed.emit(health, max_health)   # 发信号：谁关心谁去连，史莱姆自己不管
	if health == 0:
		died.emit()
#endregion


func heal(amount: int) -> void:
	if health <= 0:
		return
	health = mini(health + amount, max_health)
	_heal_glow = 1.0
	health_changed.emit(health, max_health)


func revive() -> void:
	health = max_health
	_heal_glow = 1.0
	health_changed.emit(health, max_health)


## 信号可视化用：这个节点在屏幕上占的矩形（全局坐标）。
func viz_rect() -> Rect2:
	return Rect2(global_position - Vector2(38, 36), Vector2(76, 70))


func _process(delta: float) -> void:
	_hit = move_toward(_hit, 0.0, delta * 3.0)
	_squash = move_toward(_squash, 0.0, delta * 2.5)
	_heal_glow = move_toward(_heal_glow, 0.0, delta * 1.5)
	queue_redraw()


func _draw() -> void:
	var t := Time.get_ticks_msec() / 1000.0
	var dead := health <= 0
	var base := Color("4fd1a5") if not dead else Color("6b7489")
	var body := base.lerp(Color.WHITE, _hit * 0.8)
	var bob := 0.0 if dead else sin(t * 3.0) * 2.0
	var sq := sin(_squash * PI) * 0.25
	var rx := 34.0 * (1.0 + sq)
	var ry := 28.0 * (1.0 - sq) + bob * 0.5
	if _heal_glow > 0.0:
		Pal.glow(self, Vector2(0, -6), 70.0, Color(Pal.GREEN, _heal_glow * 0.6))
	Pal.glow(self, Vector2(0, 0), 60.0, Color(base, 0.18))
	draw_set_transform(Vector2(0, 28), 0.0, Vector2(1.0, 0.25))
	draw_circle(Vector2.ZERO, rx * 0.95, Color(0, 0, 0, 0.35), true, -1.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# 身体：下半边是平的半椭圆
	var pts := PackedVector2Array()
	for i in 33:
		var a := PI + PI * i / 32.0
		var wobble := 0.0 if dead else sin(a * 3.0 + t * 4.0) * 1.2
		pts.append(Vector2(cos(a) * (rx + wobble), 26.0 + sin(a) * (ry * 1.9 + wobble)))
	pts.append(Vector2(rx, 26.0))
	pts.append(Vector2(-rx, 26.0))
	draw_colored_polygon(pts, body)
	draw_polyline(pts, base.darkened(0.35), 2.0, true)
	draw_circle(Vector2(-rx * 0.45, -10), 7.0, Color(1, 1, 1, 0.35), true, -1.0, true)
	# 眼睛
	for side in [-1.0, 1.0]:
		var e := Vector2(side * 11.0, 2.0)
		if dead:
			draw_line(e + Vector2(-4, -4), e + Vector2(4, 4), Color("2a3045"), 2.5, true)
			draw_line(e + Vector2(-4, 4), e + Vector2(4, -4), Color("2a3045"), 2.5, true)
		else:
			draw_circle(e, 5.5, Color.WHITE, true, -1.0, true)
			draw_circle(e + Vector2(1.0, 1.0), 2.8, Color("1b2133"), true, -1.0, true)
