## 计分板：收到金币就累加，然后把新总数广播到事件总线上。
class_name ScoreBoard
extends Node2D

var gold := 0
var _shown := 0.0
var _pop := 0.0


#region add_gold
func add_gold(amount: int) -> void:
	gold += amount
	_pop = 1.0
	SignalViz.report(self, Events, "gold_changed.emit(%d)" % gold)   # 只为了在画面上画出这次调用
	Events.gold_changed.emit(gold)   # 通过事件总线广播，不需要知道谁在听
#endregion


func viz_rect() -> Rect2:
	return Rect2(global_position - Vector2(56, 32), Vector2(112, 64))


func _process(delta: float) -> void:
	_shown = lerpf(_shown, gold, 1.0 - exp(-8.0 * delta))
	_pop = move_toward(_pop, 0.0, delta * 3.0)
	queue_redraw()


func _draw() -> void:
	var r := Rect2(-56, -32, 112, 64)
	Pal.panel(self, r, Pal.PANEL, Pal.YELLOW.lerp(Pal.LINE, 1.0 - _pop), 10, 1)
	draw_circle(Vector2(-32, 2), 11.0, Color("f2c14e"), true, -1.0, true)
	draw_circle(Vector2(-32, 2), 7.0, Color("ffd866"), true, -1.0, true)
	Pal.text(self, Vector2(-14, -10), "金币", 12, Pal.TEXT2)
	Pal.text(self, Vector2(-14, 16), str(roundi(_shown)), int(22 + _pop * 6), Pal.TEXT)
