## 枪的模型（第一人称视角下看到的那把枪）。只负责枪口火光。
extends Node3D

var _flash_left := 0.0

@onready var flash_mesh: MeshInstance3D = $Muzzle/Flash
@onready var flash_light: OmniLight3D = $Muzzle/FlashLight


func _ready() -> void:
	flash_mesh.visible = false
	flash_light.visible = false


#region muzzle_flash
## 枪口火光：一个加法混合的星形面片 + 一盏很短命的点光源（照亮周围的墙和枪身）。
## 每次随机转一个角度、缩放一点，连射时就不会看起来是同一张图在闪。
func flash() -> void:
	_flash_left = 0.05
	flash_mesh.visible = true
	flash_light.visible = true
	flash_mesh.rotation.z = randf() * TAU
	flash_mesh.scale = Vector3.ONE * randf_range(0.8, 1.2)


func _process(delta: float) -> void:
	if _flash_left > 0.0:
		_flash_left -= delta
		if _flash_left <= 0.0:
			flash_mesh.visible = false
			flash_light.visible = false
#endregion
