## 调试绘制：射线、导航路径、导航网格。用 ImmediateMesh 每帧重建线段。
## 其他脚本调用 DebugDraw.line(a, b, 颜色, 持续秒数)；持续时间为 0 表示只画这一帧。
class_name DebugDraw
extends MeshInstance3D

static var show_rays := false
static var show_nav := false
static var _instance: DebugDraw

## 网页参数通过这两个属性改上面的静态开关
@export var rays := false:
	set(v):
		rays = v
		show_rays = v
@export var nav := false:
	set(v):
		nav = v
		show_nav = v
		if _nav_mesh_instance:
			_nav_mesh_instance.visible = v

var _lines: Array = []          # 每项 [起点, 终点, 颜色, 剩余时间]
var _im := ImmediateMesh.new()
var _nav_mesh_instance: MeshInstance3D


func _ready() -> void:
	_instance = self
	mesh = _im
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	material_override = mat
	Tuning.bind(self, "debug", ["rays", "nav"])


static func line(a: Vector3, b: Vector3, color: Color, duration := 0.0) -> void:
	if _instance:
		_instance._lines.append([a, b, color, duration])


static func path(points: PackedVector3Array, color: Color) -> void:
	for i in range(1, points.size()):
		line(points[i - 1] + Vector3.UP * 0.1, points[i] + Vector3.UP * 0.1, color)


func _process(delta: float) -> void:
	_im.clear_surfaces()
	if _lines.is_empty():
		return
	_im.surface_begin(Mesh.PRIMITIVE_LINES)
	var keep: Array = []
	for l: Array in _lines:
		_im.surface_set_color(l[2])
		_im.surface_add_vertex(l[0])
		_im.surface_add_vertex(l[1])
		l[3] -= delta
		if l[3] > 0.0:
			keep.append(l)
	_im.surface_end()
	_lines = keep


#region navmesh_view
## 把烘焙好的导航网格画出来：半透明的面 + 多边形边线。
## NavigationMesh 里存的是顶点数组 + 多边形（每个多边形是若干顶点下标，凸多边形）。
func show_navigation_mesh(nm: NavigationMesh) -> void:
	var verts := nm.get_vertices()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var edges := PackedVector3Array()
	for i in nm.get_polygon_count():
		var poly := nm.get_polygon(i)
		for j in range(1, poly.size() - 1):          # 凸多边形按扇形拆成三角形
			for k: int in [poly[0], poly[j + 1], poly[j]]:
				st.add_vertex(verts[k] + Vector3.UP * 0.04)
		for j in poly.size():
			edges.append(verts[poly[j]] + Vector3.UP * 0.05)
			edges.append(verts[poly[(j + 1) % poly.size()]] + Vector3.UP * 0.05)
	var arr_mesh := st.commit()
	var line_arrays := []
	line_arrays.resize(Mesh.ARRAY_MAX)
	line_arrays[Mesh.ARRAY_VERTEX] = edges
	arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, line_arrays)
	var fill := StandardMaterial3D.new()
	fill.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fill.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fill.albedo_color = Color(0.2, 0.8, 1.0, 0.18)
	fill.cull_mode = BaseMaterial3D.CULL_DISABLED
	var edge := StandardMaterial3D.new()
	edge.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	edge.albedo_color = Color(0.3, 0.9, 1.0)
	arr_mesh.surface_set_material(0, fill)
	arr_mesh.surface_set_material(1, edge)
	if _nav_mesh_instance:
		_nav_mesh_instance.queue_free()
	_nav_mesh_instance = MeshInstance3D.new()
	_nav_mesh_instance.mesh = arr_mesh
	_nav_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_nav_mesh_instance.visible = show_nav
	add_child(_nav_mesh_instance)
#endregion
