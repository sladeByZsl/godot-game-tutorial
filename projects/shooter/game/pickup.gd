## 道具：P 火力升级、S 护盾、B 炸弹。碰撞层是 pickup（第 5 层），自己不检测任何东西，
## 由玩家身上的 PickupArea（mask 只勾第 5 层）来发现它。
class_name Pickup
extends Area2D

enum Type { POWER, SHIELD, BOMB }

const FONT := preload("res://fonts/ui_font.ttf")

const INFO := {
	Type.POWER: {"letter": "P", "color": Color(2.4, 0.5, 0.6)},
	Type.SHIELD: {"letter": "S", "color": Color(0.4, 1.6, 2.6)},
	Type.BOMB: {"letter": "B", "color": Color(0.6, 2.4, 0.8)},
}

var type := Type.POWER
var game: Game
var _vel := Vector2(0, -120)
var _t := 0.0


func _physics_process(delta: float) -> void:
	_t += delta
	_vel.y = minf(_vel.y + 220.0 * delta, 90.0)     # 先往上弹一下，再慢慢落下
	position += _vel * delta
	if position.y > 580.0:
		queue_free()
	queue_redraw()


func collect(player: Player) -> void:
	match type:
		Type.POWER:
			player.add_power()
		Type.SHIELD:
			player.shield = true
		Type.BOMB:
			game.bombs = mini(game.bombs + 1, Game.MAX_BOMBS)
	game.score += 500
	game.fx.ring(position, INFO[type]["color"], 40.0)
	Audio.play("pickup")
	queue_free()


func _draw() -> void:
	var col: Color = INFO[type]["color"]
	var pts := PackedVector2Array()
	for i in 7:
		pts.append(Vector2.from_angle(_t * 2.0 + TAU * i / 6) * 13.0)
	draw_colored_polygon(pts.slice(0, -1), Color(0.02, 0.02, 0.05, 0.9))
	draw_polyline(pts, col, 2.0, true)
	var font := FONT
	var letter: String = INFO[type]["letter"]
	draw_string(font, Vector2(-6, 6), letter, HORIZONTAL_ALIGNMENT_CENTER, 12, 15, Color(2, 2, 2))
