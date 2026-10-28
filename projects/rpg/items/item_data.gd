## 物品的静态数据。一种物品只有一份 .tres，所有背包格子、掉落物都引用同一份，
## 所以这里只能放"所有同类物品都一样"的东西（名字、图标、堆叠上限）。
## 每个物品自己的状态（数量、耐久）要放到别处，见 inventory.gd。
#region item_data
class_name ItemData
extends Resource

@export var id: StringName
@export var display_name := ""
@export_multiline var description := ""
@export var icon: Texture2D
@export_range(1, 99) var max_stack := 9
@export var heal := 0        ## 使用后回复多少血（半颗心 = 1）；0 表示不能直接使用
#endregion
