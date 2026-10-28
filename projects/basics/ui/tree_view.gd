## 右侧的"运行中的场景树"面板：每隔一小段时间遍历一次真实的节点树，把它画出来。
## 颜色沿用编辑器的习惯：Node2D 蓝色、Control 绿色、Node3D 红色、普通 Node 灰色。
extends Control

const MAX_LINES := 22
const LINE_H := 19.0

var _root: Node = null
var _lines: Array[Dictionary] = []
var _timer := 0.0


func watch(root: Node) -> void:
	_root = root
	_timer = 0.0


func _process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0 or not visible:
		return
	_timer = 0.25
	_lines.clear()
	if is_instance_valid(_root) and _root.is_inside_tree():
		_collect(_root, 0)
	queue_redraw()


#region walk
func _collect(node: Node, depth: int) -> void:
	if _lines.size() >= MAX_LINES:
		return
	var type := node.get_class()
	var script: Script = node.get_script()
	if script != null and script.get_global_name() != &"":
		type = script.get_global_name()
	var shown_name := String(node.name)
	if node.unique_name_in_owner:
		shown_name = "%" + shown_name          # 场景唯一名称，可以用 %名字 直接取到
	_lines.append({"depth": depth, "name": shown_name, "type": type, "color": _family_color(node)})
	for child in node.get_children():
		_collect(child, depth + 1)
#endregion


func _family_color(node: Node) -> Color:
	if node is Node2D:
		return Color("8da5f3")
	if node is Control:
		return Color("8eef97")
	if node is Node3D:
		return Color("fc7f7f")
	return Color("c9cfdb")


func _draw() -> void:
	var vw := get_viewport_rect().size.x
	var w := 236.0
	var x := vw - w - 12.0
	var h := 40.0 + _lines.size() * LINE_H
	Pal.panel(self, Rect2(x, 10, w, h), Pal.PANEL, Pal.LINE, 10)
	Pal.text(self, Vector2(x + 14, 32), "运行中的场景树", 14, Pal.TEXT2)
	for i in _lines.size():
		var l: Dictionary = _lines[i]
		var y := 52.0 + i * LINE_H
		var lx: float = x + 16.0 + l.depth * 14.0
		if l.depth > 0:
			draw_line(Vector2(lx - 9, y - 10), Vector2(lx - 9, y - 4), Pal.LINE, 1.0)
			draw_line(Vector2(lx - 9, y - 4), Vector2(lx - 3, y - 4), Pal.LINE, 1.0)
		draw_circle(Vector2(lx + 2, y - 5), 3.5, l.color, true, -1.0, true)
		Pal.text(self, Vector2(lx + 10, y), l.name, 13, Pal.TEXT)
		Pal.text(self, Vector2(x + w - 12, y), l.type, 11, Pal.TEXT3, 2)
