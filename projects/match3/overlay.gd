## 画在宝石上面的东西：选中框、提示箭头，以及"显示逻辑网格"打开时的调试数字。
class_name BoardOverlay
extends Node2D

var view: BoardView
var board: Board
var selected := Board.NO_CELL
var hint: Array = []          # [a, b] 或空
var show_debug := false
var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	if view == null or board == null:
		return
	var cs := view.cell_size
	if selected != Board.NO_CELL:
		var pulse := 0.5 + 0.5 * sin(_t * 7.0)
		var r := Rect2(Vector2(selected) * cs, Vector2.ONE * cs).grow(-2.0 + pulse * 2.0)
		var box := StyleBoxFlat.new()
		box.draw_center = false
		box.border_color = Color(1, 1, 1, 0.75 + 0.25 * pulse)
		box.set_border_width_all(3)
		box.set_corner_radius_all(int(cs * 0.22))
		box.anti_aliasing = true
		draw_style_box(box, r)
	if hint.size() == 2:
		var a := view.cell_to_pixel(hint[0])
		var b := view.cell_to_pixel(hint[1])
		var k := 0.5 + 0.5 * sin(_t * 5.0)
		var col := Color(1.0, 0.93, 0.55, 0.55 + 0.4 * k)
		var dir := (b - a).normalized()
		var p0 := a + dir * cs * 0.28
		var p1 := b - dir * cs * 0.28
		draw_line(p0, p1, col, cs * 0.08, true)
		var n := dir.orthogonal() * cs * 0.13
		draw_colored_polygon(PackedVector2Array([p1 + dir * cs * 0.1, p1 - dir * cs * 0.12 + n, p1 - dir * cs * 0.12 - n]), col)
	if show_debug:
		_draw_debug(cs)


#region debug
## 把逻辑层的数组原样画出来：每格左上角是颜色编号（-1 空，99 同色炸弹），右下角是特殊类型。
## 动画进行中，画面上的宝石可能还在路上，但这里显示的永远是 Board 里的真实数据。
func _draw_debug(cs: float) -> void:
	var font := ThemeDB.fallback_font
	var fs := int(clampf(cs * 0.26, 10, 18))
	for y in board.height:
		for x in board.width:
			var c := Vector2i(x, y)
			var o := Vector2(c) * cs
			draw_rect(Rect2(o, Vector2.ONE * cs), Color(1, 1, 1, 0.25), false, 1.0)
			var k := board.kind_at(c)
			var txt := "R" if k == Board.RAINBOW else str(k)
			draw_string(font, o + Vector2(4, fs + 1), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.BLACK)
			draw_string(font, o + Vector2(3, fs), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
			var sp := board.special_at(c)
			if sp != Board.Special.NONE:
				var tag: String = ["", "H", "V", "B", "C"][sp]
				draw_string(font, o + Vector2(cs - fs * 0.9, cs - 4), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("#ffe066"))
	for x in board.width:
		draw_string(font, Vector2(x * cs + cs * 0.5 - 4, -8), str(x), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.7))
	for y in board.height:
		draw_string(font, Vector2(-fs - 6, y * cs + cs * 0.5 + fs * 0.35), str(y), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.7))
#endregion
