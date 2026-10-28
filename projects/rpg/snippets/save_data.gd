## 演示用：用自定义 Resource 当存档格式（配合 save_resource.gd）。
class_name SaveData
extends Resource

@export var player_position := Vector2.ZERO   # Vector2 可以直接存，不用拆成 x/y
@export var hp := 6
@export var coins := 0
@export var flags: Dictionary = {}
@export var items: Array[ItemData] = []        # 资源引用也能直接存
