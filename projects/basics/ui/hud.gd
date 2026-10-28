## 左上角的标题卡片。
extends Control

var _title := ""
var _hint := ""


func set_title(title: String, hint: String) -> void:
	_title = title
	_hint = hint
	queue_redraw()


func _draw() -> void:
	if _title.is_empty():
		return
	var w := maxf(Pal.text_width(_title, 17), Pal.text_width(_hint, 13)) + 36.0
	Pal.panel(self, Rect2(12, 10, w, 54), Pal.PANEL, Pal.LINE, 10)
	draw_rect(Rect2(12, 22, 3, 30), Pal.BLUE)
	Pal.text(self, Vector2(26, 33), _title, 17, Pal.TEXT)
	Pal.text(self, Vector2(26, 54), _hint, 13, Pal.TEXT2)
