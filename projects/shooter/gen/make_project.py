#!/usr/bin/env python3
"""生成 project.godot（主要是输入映射：键盘 + 手柄写起来很长，用脚本拼）。
用法：python3 gen/make_project.py   （在 projects/shooter 目录下运行）"""
from pathlib import Path

KEYS = {"A": 65, "D": 68, "W": 87, "S": 83, "J": 74, "K": 75, "Z": 90, "X": 88, "P": 80,
        "Space": 32, "Left": 4194319, "Up": 4194320, "Right": 4194321, "Down": 4194322,
        "Escape": 4194305, "Shift": 4194325}


def key(name):
    return ('Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,'
            '"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,'
            f'"keycode":0,"physical_keycode":{KEYS[name]},"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)')


def joy_btn(i):
    return ('Object(InputEventJoypadButton,"resource_local_to_scene":false,"resource_name":"","device":-1,'
            f'"button_index":{i},"pressure":0.0,"pressed":true,"script":null)')


def joy_axis(axis, value):
    return ('Object(InputEventJoypadMotion,"resource_local_to_scene":false,"resource_name":"","device":-1,'
            f'"axis":{axis},"axis_value":{value:.1f},"script":null)')


# 手柄按键编号：A=0 B=1 X=2 Y=3 Start=6 LB=9 RB=10 十字键 上11 下12 左13 右14
ACTIONS = {
    "move_left":  [key("A"), key("Left"), joy_btn(13), joy_axis(0, -1)],
    "move_right": [key("D"), key("Right"), joy_btn(14), joy_axis(0, 1)],
    "move_up":    [key("W"), key("Up"), joy_btn(11), joy_axis(1, -1)],
    "move_down":  [key("S"), key("Down"), joy_btn(12), joy_axis(1, 1)],
    "shoot":      [key("Space"), key("J"), key("Z"), joy_btn(0), joy_btn(10)],
    "bomb":       [key("X"), key("K"), joy_btn(1)],
    "focus":      [key("Shift"), joy_btn(9)],
    "pause":      [key("Escape"), key("P"), joy_btn(6)],
}

HEAD = '''; Godot 4.7 项目文件。用 Godot 4.7.x 打开本文件夹即可。

config_version=5

[application]

config/name="太空射击 Neon Strike"
config/description="《Godot 4.7 互动教程》配套示例：对象池、碰撞层、弹幕、粒子、UI 与音频。"
run/main_scene="res://ui/title.tscn"
config/features=PackedStringArray("4.7", "GL Compatibility")

[audio]

buses/default_bus_layout="res://audio/bus_layout.tres"

[autoload]

Tuning="*res://tuning.gd"
Audio="*res://core/audio.gd"
Flow="*res://core/flow.gd"

[display]

window/size/viewport_width=960
window/size/viewport_height=540
window/stretch/mode="canvas_items"
window/stretch/aspect="keep"

[gui]

theme/custom="res://ui/theme.tres"
theme/custom_font="res://fonts/ui_font.ttf"

'''

TAIL = '''
[layer_names]

2d_physics/layer_1="player"
2d_physics/layer_2="player_bullet"
2d_physics/layer_3="enemy"
2d_physics/layer_4="enemy_bullet"
2d_physics/layer_5="pickup"

[physics]

common/physics_ticks_per_second=60

[rendering]

renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
environment/defaults/default_clear_color=Color(0.02, 0.02, 0.06, 1)
viewport/hdr_2d=true
'''

out = [HEAD, "[input]\n\n"]
for name, evs in ACTIONS.items():
    out.append(f'{name}={{\n"deadzone": 0.3,\n"events": [' + "\n, ".join(evs) + "\n]\n}\n")
out.append(TAIL)
Path("project.godot").write_text("".join(out))
print("project.godot written")
