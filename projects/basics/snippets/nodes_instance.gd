## 第 2 章片段：把场景当"预制体"用——加载、实例化、加进树、删除。
extends Node2D

#region preload_scene
## preload 在脚本编译时就加载好；路径必须是写死的字符串常量。
const SOLAR_SCENE := preload("res://solar/solar.tscn")

## 也可以在检查器里把 .tscn 拖到这个属性上，不用在代码里写路径。
@export var bullet_scene: PackedScene
#endregion


#region instantiate
func spawn_solar_system(at: Vector2) -> Node2D:
	var solar := SOLAR_SCENE.instantiate() as Node2D   # 造出一棵新的节点树（还不在场景树里）
	solar.position = at                                # 进树之前就可以设置属性
	add_child(solar)                                   # 进树：这之后它的 _ready() 才会执行
	return solar
#endregion


#region free
func remove_it(node: Node) -> void:
	node.queue_free()        # 推荐：本帧结束时再删除，当前正在执行的代码不受影响
	# node.free()            # 立刻删除；如果别处还在用它，会出错
#endregion


#region reparent
func move_under(node: Node2D, new_parent: Node) -> void:
	node.reparent(new_parent)            # 默认保持全局变换不变：屏幕上看位置不跳
	# node.reparent(new_parent, false)   # 保持本地变换：position 数值不变，屏幕位置会跳
#endregion


#region owner
## owner 决定"这个节点属于哪个场景文件"。代码里新建的节点，owner 默认是 null，
## 用 PackedScene.pack() 保存时会被漏掉；想把它一起存下来，就要手动设置 owner。
func save_with_marker(path: String) -> Error:
	var root := Node2D.new()
	root.name = "Saved"
	var marker := Marker2D.new()
	marker.name = "SpawnPoint"
	root.add_child(marker)
	marker.owner = root                  # 不设这一行，保存出的场景里就没有 SpawnPoint
	var packed := PackedScene.new()
	packed.pack(root)                    # 只打包 root 本身和 owner == root 的节点
	root.free()
	return ResourceSaver.save(packed, path)
#endregion
