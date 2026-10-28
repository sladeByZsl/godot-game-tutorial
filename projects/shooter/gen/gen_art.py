#!/usr/bin/env python3
"""生成示例用到的几张贴图（子弹、光晕）。运行：python3 gen/gen_art.py（在 projects/shooter 下）。
贴图都是白芯 + 彩色光晕：白芯让子弹在任何背景上都看得清，光晕负责"霓虹"感。"""
import math
from pathlib import Path
from PIL import Image

OUT = Path("art")
OUT.mkdir(exist_ok=True)


def orb(size, color, core=0.32, ring=0.62, name=""):
    """圆形子弹：中心白色 → 彩色环 → 向外渐隐的光晕。"""
    img = Image.new("RGBA", (size, size))
    px = img.load()
    c = (size - 1) / 2
    for y in range(size):
        for x in range(size):
            d = math.hypot(x - c, y - c) / (size / 2)        # 0 中心，1 边缘
            if d < core:
                r, g, b, a = 255, 255, 255, 255
            elif d < ring:
                t = (d - core) / (ring - core)
                r, g, b = [int(255 + (cc - 255) * min(1, t * 1.6)) for cc in color]
                a = 255
            else:
                t = (d - ring) / (1 - ring)
                r, g, b = color
                a = int(255 * max(0.0, 1 - t) ** 2.2 * 0.75)
            px[x, y] = (r, g, b, a)
    img.save(OUT / f"{name}.png")


def rice(w, h, color, name):
    """米粒弹（细长）：用于自机狙，贴图朝右（+X），代码里按速度方向旋转。"""
    img = Image.new("RGBA", (w, h))
    px = img.load()
    cx, cy = (w - 1) / 2, (h - 1) / 2
    for y in range(h):
        for x in range(w):
            d = math.hypot((x - cx) / (w / 2), (y - cy) / (h / 2))
            if d < 0.35:
                px[x, y] = (255, 255, 255, 255)
            elif d < 0.7:
                t = (d - 0.35) / 0.35
                px[x, y] = tuple(int(255 + (cc - 255) * min(1, t * 1.5)) for cc in color) + (255,)
            elif d < 1:
                t = (d - 0.7) / 0.3
                px[x, y] = color + (int(255 * (1 - t) ** 2 * 0.7),)
            else:
                px[x, y] = (0, 0, 0, 0)
    img.save(OUT / f"{name}.png")


def glow(size, name, power=2.0):
    """纯白径向渐变，配合"加法混合"当光晕/粒子用；颜色靠 modulate 染。"""
    img = Image.new("RGBA", (size, size))
    px = img.load()
    c = (size - 1) / 2
    for y in range(size):
        for x in range(size):
            d = min(1.0, math.hypot(x - c, y - c) / (size / 2))
            px[x, y] = (255, 255, 255, int(255 * (1 - d) ** power))
    img.save(OUT / f"{name}.png")


orb(24, (255, 60, 170), name="bullet_pink")
orb(24, (255, 150, 40), name="bullet_orange")
orb(24, (150, 90, 255), name="bullet_violet")
orb(40, (255, 70, 90), core=0.3, ring=0.55, name="bullet_big")
rice(28, 14, (90, 200, 255), "bullet_rice")
rice(30, 10, (80, 255, 230), "shot_player")
glow(64, "glow")
glow(16, "spark", power=1.2)
print("art done")
