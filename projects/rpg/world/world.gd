## 地图根节点（y_sort_enabled = true）。地面和装饰层用 z_index 压在下面，
## 障碍层和所有角色都是它的直接子节点，按脚底的 y 坐标排序。
extends Node2D

const MAP_RECT := Rect2(0, 0, 640, 352)   # 40 × 22 格


## 某个位置能不能放下一个角色（用来随机生成敌人）。
func is_free(pos: Vector2) -> bool:
	if not MAP_RECT.grow(-20).has_point(pos):
		return false
	var shape := CircleShape2D.new()
	shape.radius = 8.0
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, pos + Vector2(0, -3))
	query.collision_mask = 0b11          # world + water 两层
	return get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()
