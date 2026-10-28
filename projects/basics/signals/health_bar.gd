## 血条。它只提供一个方法 update_bar()，谁来调用、什么时候调用，它都不关心。
class_name HealthBar
extends Node2D

const SIZE := Vector2(130, 14)

var _ratio := 1.0        # 当前显示的比例（快速追上）
var _trail := 1.0        # 白色"掉血残影"（慢慢追上）
var _target := 1.0
var _text := "HP 100 / 100"
var _flash := 0.0


#region update_bar
func update_bar(current: int, maximum: int) -> void:
	_target = float(current) / maxi(maximum, 1)
	_text = "HP %d / %d" % [current, maximum]
	_flash = 1.0
#endregion


func viz_rect() -> Rect2:
	return Rect2(global_position - Vector2(70, 30), Vector2(140, 54))


func _process(delta: float) -> void:
	_ratio = lerpf(_ratio, _target, 1.0 - exp(-14.0 * delta))
	_trail = lerpf(_trail, _target, 1.0 - exp(-2.5 * delta)) if _trail > _target else _ratio
	_flash = move_toward(_flash, 0.0, delta * 2.0)
	queue_redraw()


func _draw() -> void:
	var r := Rect2(-SIZE * 0.5, SIZE)
	Pal.text(self, Vector2(0, -14), _text, 14, Pal.TEXT.lerp(Color.WHITE, _flash), 1)
	Pal.panel(self, r.grow(3), Color("0a0e1a"), Pal.LINE, 6)
	var col := Pal.RED.lerp(Pal.YELLOW, clampf(_ratio * 2.0, 0, 1)).lerp(Pal.GREEN, clampf(_ratio * 2.0 - 1.0, 0, 1))
	if _trail > _ratio:
		draw_rect(Rect2(r.position, Vector2(r.size.x * _trail, r.size.y)), Color(1, 1, 1, 0.75))
	draw_rect(Rect2(r.position, Vector2(r.size.x * _ratio, r.size.y)), col)
	draw_rect(Rect2(r.position, Vector2(r.size.x * _ratio, r.size.y * 0.4)), Color(1, 1, 1, 0.18))
