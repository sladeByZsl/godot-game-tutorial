## Boss：三个阶段，血量每掉三分之一换一种弹幕。
##   阶段 1 环形齐射 + 自机狙扇形
##   阶段 2 双螺旋（两组反向旋转）
##   阶段 3 花瓣弹 + 高速自机狙
class_name Boss
extends Area2D

signal phase_changed(phase: int, phase_name: String)
signal defeated

const PHASE_NAMES := ["环形齐射", "双螺旋", "花瓣风暴"]
const BASE_HP := 900.0

var game: Game
var hp := BASE_HP
var max_hp := BASE_HP
var phase := 0
var _t := 0.0
var _state := "enter"         # enter → fight → dying
var _timers := [0.0, 0.0, 0.0]
var _spin := 0.0
var _flash := 0.0
var _invul := 0.0
var _hits := 0


func start(g: Game, start_phase := 0) -> void:
	game = g
	max_hp = BASE_HP * game.director.hp_mult
	hp = max_hp * (1.0 - start_phase / 3.0)
	phase = start_phase
	position = Vector2(300, -90)
	var tw := create_tween()
	tw.tween_property(self, "position", Vector2(300, 110), 2.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void: _state = "fight")
	phase_changed.emit(phase, PHASE_NAMES[phase])


func _physics_process(delta: float) -> void:
	_t += delta
	_flash = maxf(0.0, _flash - delta)
	_invul = maxf(0.0, _invul - delta)
	queue_redraw()
	if _state != "fight":
		return
	# 慢慢画"8"字（利萨如曲线），不要停在一个地方
	position = position.lerp(Vector2(300.0 + sin(_t * 0.6) * 150.0, 110.0 + sin(_t * 1.2) * 28.0),
		1.0 - exp(-2.0 * delta))
	if _invul > 0.0:
		return
	match phase:
		0: _phase_rings(delta)
		1: _phase_spiral(delta)
		2: _phase_flower(delta)


#region phases
func _phase_rings(delta: float) -> void:
	var dens := game.director.bullet_density
	var spd := game.director.bullet_speed
	_timers[0] -= delta
	if _timers[0] <= 0.0:
		_timers[0] = 0.9
		var n := maxi(6, roundi(24 * dens))
		_spin += PI / n                    # 每圈旋转半格
		Danmaku.ring(game.enemy_bullets, position, n, 125.0 * spd, _spin, Bullet.Kind.PINK)
		Audio.play("enemy_shot", -4.0)
	_timers[1] -= delta
	if _timers[1] <= 0.0:
		_timers[1] = 1.7
		Danmaku.aimed(game.enemy_bullets, position, game.player.position, maxi(3, roundi(7 * dens)),
			0.8, 210.0 * spd)


func _phase_spiral(delta: float) -> void:
	var dens := game.director.bullet_density
	var spd := game.director.bullet_speed
	_timers[0] -= delta
	if _timers[0] <= 0.0:
		_timers[0] = 0.07
		var arms := maxi(2, roundi(4 * dens))
		_spin += 0.19
		# 两组螺旋：一组顺时针、一组逆时针，速度不同，交叉出网格
		Danmaku.spiral(game.enemy_bullets, position, _spin, arms, 120.0 * spd, Bullet.Kind.VIOLET)
		Danmaku.spiral(game.enemy_bullets, position, -_spin * 0.8, arms, 95.0 * spd, Bullet.Kind.PINK)
	_timers[1] -= delta
	if _timers[1] <= 0.0:
		_timers[1] = 0.6
		Audio.play("enemy_shot", -8.0)
	_timers[2] -= delta
	if _timers[2] <= 0.0:
		_timers[2] = 4.0
		game.director.spawn_escort()       # 召唤一队护卫机


func _phase_flower(delta: float) -> void:
	var dens := game.director.bullet_density
	var spd := game.director.bullet_speed
	_timers[0] -= delta
	if _timers[0] <= 0.0:
		_timers[0] = 0.55
		_spin += 0.21
		Danmaku.flower(game.enemy_bullets, position, maxi(10, roundi(40 * dens)), 110.0 * spd, 5, 0.45,
			_spin, Bullet.Kind.ORANGE)
		Audio.play("enemy_shot", -4.0)
	_timers[1] -= delta
	if _timers[1] <= 0.0:
		_timers[1] = 0.28
		Danmaku.aimed(game.enemy_bullets, position, game.player.position, 3, 0.25, 260.0 * spd)
	_timers[2] -= delta
	if _timers[2] <= 0.0:
		_timers[2] = 2.2
		Danmaku.ring(game.enemy_bullets, position, maxi(4, roundi(10 * dens)), 70.0 * spd, randf() * TAU,
			Bullet.Kind.BIG)
#endregion


func take_hit(dmg: int, at: Vector2) -> void:
	if _state != "fight" or _invul > 0.0:
		return
	hp -= dmg
	_flash = 0.04
	game.score += 10
	_hits += 1
	if _hits % 6 == 0:              # 每 6 发溅一次火花粒子
		game.fx.burst(game.field.to_local(at), Color(1.3, 0.7, 0.3))
	elif _hits % 3 == 0:
		game.fx.spark(game.field.to_local(at))
	var new_phase := 3 - ceili(hp / max_hp * 3.0)     # 血量 100%~67% → 0，67%~33% → 1，其余 → 2
	if hp <= 0.0:
		_die()
	elif new_phase > phase:
		_next_phase(new_phase)


func _next_phase(p: int) -> void:
	phase = p
	_invul = 1.4
	_timers = [0.5, 1.0, 1.5]
	game.cancel_enemy_bullets()            # 换阶段时清屏，把子弹变成分数
	game.fx.ring(position, Color(2.5, 0.6, 1.8), 160.0)
	game.shake(12.0)
	game.spawn_pickup(position, Pickup.Type.POWER if p == 1 else Pickup.Type.BOMB)
	phase_changed.emit(phase, PHASE_NAMES[phase])


func _die() -> void:
	_state = "dying"
	game.cancel_enemy_bullets()
	# 用一条 Tween 串起连锁爆炸：Tween 绑定在 Boss 上，Boss 被释放或游戏暂停时它也跟着停
	var tw := create_tween()
	for i in 6:
		var off := Vector2(randf_range(-50, 50), randf_range(-35, 35))
		tw.tween_callback(_boom.bind(off, false))
		tw.tween_interval(0.18)
	tw.tween_interval(0.25)
	tw.tween_callback(_boom.bind(Vector2.ZERO, true))
	tw.tween_callback(defeated.emit)
	tw.tween_callback(queue_free)


func _boom(offset: Vector2, final: bool) -> void:
	game.fx.explode(position + offset, Color(2.5, 2.0, 1.0) if final else Color(2.5, 0.8, 1.6), true)
	game.shake(24.0 if final else 10.0)


func _draw() -> void:
	var col := Color(2.6, 0.5, 1.6) if _flash <= 0.0 else Color(3, 3, 3)
	var dim := Color(0.06, 0.01, 0.05, 0.95)
	var a := _t * 0.6
	# 外环：12 边形，缓慢旋转
	var outer := PackedVector2Array()
	for i in 13:
		var r := 58.0 if i % 2 == 0 else 46.0
		outer.append(Vector2.from_angle(a + TAU * i / 12) * r)
	draw_colored_polygon(outer.slice(0, -1), dim)   # 填充用的多边形不能首尾重复
	draw_polyline(outer, Color(col, 0.22), 8.0, true)
	draw_polyline(outer, col, 2.0, true)
	# 两侧机翼
	for s in [-1.0, 1.0]:
		var wing := PackedVector2Array([Vector2(40 * s, -6), Vector2(96 * s, 8), Vector2(84 * s, 26), Vector2(44 * s, 18), Vector2(40 * s, -6)])
		draw_colored_polygon(wing.slice(0, -1), dim)
		draw_polyline(wing, Color(1.4, 0.6, 2.6), 2.0, true)
	# 内核：反向旋转的三角 + 发光核心
	var inner := PackedVector2Array()
	for i in 4:
		inner.append(Vector2.from_angle(-a * 2.0 + TAU * i / 3) * 26.0)
	draw_polyline(inner, Color(2.6, 1.8, 0.6), 2.0, true)
	var pulse := 10.0 + sin(_t * 8.0) * 2.0
	draw_circle(Vector2.ZERO, pulse + 6.0, Color(2.6, 0.5, 1.4, 0.3))
	draw_circle(Vector2.ZERO, pulse, Color(3.0, 1.6, 2.2))
