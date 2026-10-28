## 成就面板。两种接收方式：
## 1. "首次开箱"：父节点用 CONNECT_ONE_SHOT 把宝箱的 opened 连到这里，只触发一次就自动断开。
## 2. 金币成就：自己在 _ready 里去事件总线 Events 上订阅 gold_changed。
class_name Achievements
extends Node2D

var unlocked := [false, false, false]
var first_chest_calls := 0
var _pop := [0.0, 0.0, 0.0]

const TITLES := ["首次开箱", "攒到 50 金币", "攒到 100 金币"]


#region bus_listen
func _ready() -> void:
	Events.gold_changed.connect(_on_gold_changed)


func _on_gold_changed(total: int) -> void:
	if total >= 50:
		_unlock(1)
	if total >= 100:
		_unlock(2)
#endregion


func on_first_chest(_gold: int) -> void:
	first_chest_calls += 1
	_unlock(0)


func _unlock(i: int) -> void:
	if not unlocked[i]:
		unlocked[i] = true
		_pop[i] = 1.0


func viz_rect() -> Rect2:
	return Rect2(global_position - Vector2(72, 60), Vector2(144, 120))


func _process(delta: float) -> void:
	for i in 3:
		_pop[i] = move_toward(_pop[i], 0.0, delta * 1.5)
	queue_redraw()


func _draw() -> void:
	Pal.panel(self, Rect2(-72, -60, 144, 120), Pal.PANEL, Pal.LINE, 10)
	Pal.text(self, Vector2(-58, -38), "成就", 13, Pal.TEXT2)
	Pal.text(self, Vector2(58, -38), "开箱回调 ×%d" % first_chest_calls, 11, Pal.TEXT3, 2)
	for i in 3:
		var y := -14.0 + i * 28.0
		var on: bool = unlocked[i]
		var c := Pal.YELLOW if on else Pal.TEXT3
		if _pop[i] > 0.0:
			Pal.glow(self, Vector2(-48, y), 26.0 + 20.0 * _pop[i], Color(Pal.YELLOW, _pop[i]))
		draw_circle(Vector2(-48, y), 9.0, c if on else Color(0, 0, 0, 0), true, -1.0, true)
		draw_arc(Vector2(-48, y), 9.0, 0, TAU, 24, c, 1.5, true)
		if on:
			draw_polyline(PackedVector2Array([Vector2(-52, y), Vector2(-49, y + 3), Vector2(-44, y - 3)]), Color("1b2133"), 2.0, true)
		Pal.text(self, Vector2(-32, y + 5), TITLES[i], 13, Pal.TEXT if on else Pal.TEXT3)
