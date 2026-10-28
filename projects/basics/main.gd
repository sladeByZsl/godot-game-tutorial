## 入门示例的总入口：根据网页上的参数 demo.scene，在 Stage 下面换上不同的小场景。
## 三个小场景都按 960x540 设计，窗口比例不同时整体居中。
extends Node2D

const DESIGN_SIZE := Vector2(960, 540)

#region scenes
## 场景名 -> [场景文件, 标题, 操作提示]
const SCENES := {
	"太阳系": ["res://solar/solar.tscn", "太阳系：父子节点与变换继承", "太阳 → 地球 → 月亮，每个节点只管自己转"],
	"信号实验室": ["res://signals/signal_lab.tscn", "信号实验室：谁连接了谁", "点按钮、点宝箱，看信号沿着连线流动"],
	"生命周期": ["res://lifecycle/lifecycle.tscn", "生命周期：回调的先后顺序", "点右上角的按钮增删节点，看日志和时间轴"],
}
#endregion

#region switch
## 当前显示哪个小场景。网页上切换时，Tuning 会直接给它赋值，setter 负责换场景。
@export_enum("太阳系", "信号实验室", "生命周期") var scene := "太阳系":
	set(value):
		scene = value
		if is_node_ready():
			_load_scene()
#endregion

## 是否在右侧显示"运行中的场景树"面板。
@export var show_tree := false:
	set(value):
		show_tree = value
		if is_node_ready():
			tree_view.visible = value

var _current: Node = null

@onready var stage: Node2D = $Stage
@onready var hud: Control = $HUD/Hud
@onready var tree_view: Control = $HUD/TreeView


func _ready() -> void:
	Tuning.bind(self, "demo", ["scene", "show_tree"])
	Tuning.action_triggered.connect(_on_action)
	tree_view.visible = show_tree
	if _current == null:
		_load_scene()


func _process(_delta: float) -> void:
	# 窗口比例变化时，让 960x540 的设计区域保持在正中间
	stage.position = ((get_viewport_rect().size - DESIGN_SIZE) * 0.5).floor()
	Tuning.stat("节点总数", get_tree().get_node_count())


#region instance
func _load_scene() -> void:
	var info: Array = SCENES.get(scene, SCENES["太阳系"])
	if _current != null:
		_current.queue_free()          # 旧场景在这一帧结束时才真正删除
	var packed: PackedScene = load(info[0])
	_current = packed.instantiate()    # 实例化：照着"模板"造出一棵新的节点树
	stage.add_child(_current)          # 加进场景树后，它的 _ready() 才会被调用
	hud.set_title(info[1], info[2])
	tree_view.watch(_current)
	Tuning.stat("当前场景", scene)
#endregion


func _on_action(action_name: String) -> void:
	if action_name == "reset":
		_load_scene()
