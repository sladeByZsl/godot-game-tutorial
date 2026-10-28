## 宝箱：靠近按交互键打开，把 contents 里的物品放进背包。打开过的宝箱记在 Game 里，存档会带上。
extends StaticBody2D

@export var contents: Array[ItemData] = []
@export var coins := 0

@onready var sprite: Sprite2D = $Sprite


func _ready() -> void:
	Game.loaded.connect(_refresh)
	_refresh()


func _refresh() -> void:
	sprite.frame = 1 if is_opened() else 0


func is_opened() -> bool:
	return String(name) in Game.opened_chests


func can_interact() -> bool:
	return not is_opened()


func interact_label() -> String:
	return "打开"


func interact(_player: Player) -> void:
	if is_opened():
		return
	Game.opened_chests.append(String(name))
	_refresh()
	var got: PackedStringArray = []
	for item in contents:
		Game.inventory.add(item)
		got.append(item.display_name)
	if coins > 0:
		Game.add_coins(coins)
		got.append("%d 金币" % coins)
	Game.toast.emit("宝箱里有：" + "、".join(got))
	var tw := create_tween()
	tw.tween_property(sprite, "scale", Vector2(1.2, 0.8), 0.06)
	tw.tween_property(sprite, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK)
