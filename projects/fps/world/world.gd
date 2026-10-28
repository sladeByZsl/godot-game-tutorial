## 光照与环境：太阳（带阴影的平行光）、冷色补光、WorldEnvironment（天空、环境光、色调映射、雾、glow）。
## 这里用代码创建，效果和在检查器里新建 Environment 资源、逐项填写完全一样。
extends Node3D

#region params
@export var fog_density := 0.006:            ## 指数雾密度
	set(v):
		fog_density = v
		if env:
			env.fog_enabled = v > 0.0
			env.fog_density = v
@export var shadows := true:                  ## 太阳阴影开关
	set(v):
		shadows = v
		if sun:
			sun.shadow_enabled = v
@export var time_scale := 1.0:                ## 全局时间缩放（子弹时间）
	set(v):
		time_scale = v
		Engine.time_scale = v
#endregion

var env: Environment
var sun: DirectionalLight3D


func _ready() -> void:
	_make_lights()
	_make_environment()
	Tuning.bind(self, "world", ["fog_density", "shadows", "time_scale"])


#region lights
func _make_lights() -> void:
	# 太阳：DirectionalLight3D 只有方向，没有位置。旋转决定光从哪里来（光沿自身 -Z 方向照射）
	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-38, 32, 0)
	sun.light_color = Color(1.0, 0.86, 0.68)
	sun.light_energy = 1.25
	sun.shadow_enabled = shadows
	sun.shadow_blur = 1.5
	sun.shadow_bias = 0.05
	sun.shadow_normal_bias = 1.6
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS   # 2 级级联，比 4 级省一半绘制
	sun.directional_shadow_max_distance = 40.0     # 阴影只画到 40 米，距离越短阴影越清晰
	add_child(sun)
	# 补光：从反方向打一盏弱的冷色光，不投阴影，让背光面不至于死黑
	var fill := DirectionalLight3D.new()
	fill.name = "Fill"
	fill.rotation_degrees = Vector3(-30, -150, 0)
	fill.light_color = Color(0.55, 0.68, 1.0)
	fill.light_energy = 0.35
	fill.light_specular = 0.0
	fill.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY   # 只照亮场景，不在天空里画出第二个太阳
	add_child(fill)
#endregion


#region environment
func _make_environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.24, 0.42, 0.7)
	sky_mat.sky_horizon_color = Color(0.86, 0.76, 0.66)
	sky_mat.ground_horizon_color = Color(0.86, 0.76, 0.66)
	sky_mat.ground_bottom_color = Color(0.25, 0.23, 0.22)
	var sky := Sky.new()
	sky.sky_material = sky_mat

	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	# 环境光取自天空：朝上的面偏蓝，朝下的面偏暗，比单一颜色的环境光自然得多
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.5        # 一半取自天空，一半取 ambient_light_color
	env.ambient_light_color = Color(0.6, 0.52, 0.45)
	env.ambient_light_energy = 0.45
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	# 色调映射：把 HDR 的亮度压到屏幕能显示的 0~1，高光不会一片死白
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 0.9
	# 雾：指数雾，远处的物体逐渐融进雾色，增加纵深感
	env.fog_enabled = fog_density > 0.0
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_density = fog_density
	env.fog_light_color = Color(0.78, 0.72, 0.66)
	env.fog_sun_scatter = 0.25
	env.fog_aerial_perspective = 0.25
	env.fog_sky_affect = 0.15
	# glow：亮度超过阈值的像素向外扩散（Compatibility 下是简化版实现）
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_hdr_threshold = 1.0
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
#endregion
