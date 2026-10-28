## 杂兵：挂在 PathFollow2D 下面，沿 Path2D 飞；按 WaveData 的描述射击。
class_name Enemy
extends Area2D

const LOOK := {   # 外形：边数、半径、颜色（颜色分量大于 1 会在 HDR 下发光）
	WaveData.Kind.DRONE: {"sides": 4, "r": 13.0, "color": Color(2.2, 0.5, 1.6)},
	WaveData.Kind.SHOOTER: {"sides": 6, "r": 15.0, "color": Color(2.4, 1.2, 0.3)},
	WaveData.Kind.TURRET: {"sides": 8, "r": 26.0, "color": Color(1.3, 0.7, 2.6)},
}
const SCORE := {WaveData.Kind.DRONE: 100, WaveData.Kind.SHOOTER: 300, WaveData.Kind.TURRET: 1500}

var data: WaveData
var game: Game
var follow: PathFollow2D
var speed := 150.0
var hp := 3.0
var max_hp := 3.0
var _fire_timer := 0.0
var _spiral := 0.0
var _hold_left := 0.0
var _held := false
var _flash := 0.0
var _t := 0.0
var _look: Dictionary

@onready var shape: CollisionShape2D = $Shape


func setup(w: WaveData, g: Game, f: PathFollow2D, base_speed: float, hp_mult: float) -> void:
	data = w
	game = g
	follow = f
	speed = base_speed * w.speed_scale
	max_hp = w.hp * hp_mult
	hp = max_hp
	_look = LOOK[w.kind]
	_fire_timer = w.fire_interval * randf_range(0.5, 1.0)
	_spiral = randf() * TAU


func _ready() -> void:
	add_to_group("enemies")
	# 场景里的圆半径是 10；按外形大小缩放这个 CollisionShape2D 节点，而不是改共享的 Shape 资源
	shape.scale = Vector2.ONE * (_look["r"] * 0.8 / 10.0)


func _physics_process(delta: float) -> void:
	_t += delta
	_flash = maxf(0.0, _flash - delta)
	#region follow_path
	if _hold_left > 0.0:
		_hold_left -= delta                     # 停在半路射击
	else:
		follow.progress += speed * delta        # progress 是沿曲线走过的像素长度
	if not _held and data.hold_at >= 0.0 and follow.progress_ratio >= data.hold_at:
		_held = true
		_hold_left = data.hold_time
	if follow.progress_ratio >= 1.0:            # 走完整条路径：飞出屏幕，悄悄消失（不加分）
		follow.queue_free()
		return
	#endregion
	_try_fire(delta)
	queue_redraw()


func _try_fire(delta: float) -> void:
	if data.fire == WaveData.Fire.NONE:
		return
	var pos := game.field_pos(self)
	if pos.y < 10.0 or pos.y > 420.0:          # 刚进场或者快到底部时不开火，给玩家留余地
		return
	_fire_timer -= delta
	if _fire_timer > 0.0:
		return
	_fire_timer = data.fire_interval
	var pool := game.enemy_bullets
	var dens := game.director.bullet_density
	var spd := game.director.bullet_speed
	var target := game.player.position
	match data.fire:
		WaveData.Fire.AIMED:
			Danmaku.aimed(pool, pos, target, 1, 0.0, 190.0 * spd)
		WaveData.Fire.FAN:
			Danmaku.aimed(pool, pos, target, maxi(2, roundi(5 * dens)), 0.9, 170.0 * spd)
		WaveData.Fire.RING:
			var n := maxi(4, roundi(18 * dens))
			Danmaku.ring(pool, pos, n, 120.0 * spd, _spiral, Bullet.Kind.PINK)
			_spiral += PI / n                    # 每圈错开半格，两圈的空隙不会对齐
		WaveData.Fire.SPIRAL:
			Danmaku.spiral(pool, pos, _spiral, maxi(1, roundi(3 * dens)), 130.0 * spd)
			_spiral += 0.23
	if data.fire != WaveData.Fire.SPIRAL or randf() < 0.2:
		Audio.play("enemy_shot", -6.0)


func take_hit(dmg: int, _at: Vector2) -> void:
	if hp <= 0.0:
		return
	hp -= dmg
	_flash = 0.06
	if hp <= 0.0:
		game.on_enemy_killed(self, SCORE[data.kind], data.drop_chance)
		follow.queue_free()


func _draw() -> void:
	var sides: int = _look["sides"]
	var r: float = _look["r"]
	var col: Color = _look["color"]
	var spin := _t * (1.5 if data.kind == WaveData.Kind.TURRET else 0.0)
	var pts := PackedVector2Array()
	for i in sides + 1:
		var a := spin + TAU * i / sides + (PI / sides if sides == 6 else 0.0)
		var rr := r * (0.65 if data.kind == WaveData.Kind.DRONE and i % 2 == 1 else 1.0)
		pts.append(Vector2.from_angle(a) * rr)
	var fill := Color(1, 1, 1) if _flash > 0.0 else Color(col.r * 0.08, col.g * 0.08, col.b * 0.1, 0.9)
	draw_colored_polygon(pts.slice(0, -1), fill)   # 闭合点只给描边用
	draw_polyline(pts, Color(col, 0.25), 6.0, true)     # 外圈的半透明粗线 = 柔光
	draw_polyline(pts, col, 2.0, true)
	draw_circle(Vector2.ZERO, r * 0.28, col)               # 核心
	if data.kind == WaveData.Kind.TURRET:
		for i in 4:
			var a := -spin * 2.0 + TAU * i / 4
			draw_line(Vector2.from_angle(a) * r * 0.4, Vector2.from_angle(a) * r * 0.85, col, 2.0)
	if hp < max_hp and data.kind == WaveData.Kind.TURRET:  # 炮台显示血条
		draw_rect(Rect2(-r, r + 6, 2 * r, 3), Color(1, 1, 1, 0.2))
		draw_rect(Rect2(-r, r + 6, 2 * r * hp / max_hp, 3), col)
