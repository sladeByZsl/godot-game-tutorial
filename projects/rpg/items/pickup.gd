## 地上的掉落物：金币、爱心、或者一件 ItemData。玩家碰到就捡起来。
extends Area2D

const ATLAS := preload("res://art/items.png")

@export_enum("coin", "heart", "item") var kind := "coin"
@export var item: ItemData

@onready var sprite: Sprite2D = $Sprite


func setup(what: String) -> void:
	if what == "coin" or what == "heart":
		kind = what
	else:
		kind = "item"
		item = Game.ITEMS[StringName(what)]


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	if kind == "item":
		sprite.texture = item.icon
	else:
		var tex := AtlasTexture.new()
		tex.atlas = ATLAS
		tex.region = Rect2(0 if kind == "coin" else 64, 0, 16, 16)
		sprite.texture = tex
	# 掉出来时弹一下
	var tw := create_tween()
	tw.tween_property(sprite, "position:y", -18.0, 0.18).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(sprite, "position:y", -8.0, 0.25).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BOUNCE)


func _process(_delta: float) -> void:
	sprite.scale.x = 0.85 + 0.15 * cos(Time.get_ticks_msec() * 0.005) if kind == "coin" else 1.0


func _on_body_entered(body: Node2D) -> void:
	if not body is Player:
		return
	match kind:
		"coin":
			Game.add_coins(1)
		"heart":
			Game.change_hp(2)
		"item":
			if Game.inventory.add(item) > 0:
				Game.toast.emit("背包满了")
				return
			Game.toast.emit("获得 %s" % item.display_name)
	set_deferred("monitoring", false)
	var tw := create_tween()
	tw.tween_property(sprite, "position:y", -22.0, 0.15)
	tw.parallel().tween_property(self, "modulate:a", 0.0, 0.15)
	tw.tween_callback(queue_free)
