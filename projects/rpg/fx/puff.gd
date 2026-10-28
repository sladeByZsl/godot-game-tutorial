## 一次性的烟雾粒子，播完自动删除。
extends CPUParticles2D


func _ready() -> void:
	emitting = true
	finished.connect(queue_free)
