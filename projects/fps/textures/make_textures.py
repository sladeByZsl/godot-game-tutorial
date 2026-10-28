#!/usr/bin/env python3
"""生成 fps 示例用到的全部贴图（不依赖外部美术素材）。

    python3 textures/make_textures.py     # 在 projects/fps 目录下运行

贴图都是可平铺（tileable）的：噪声用周期性的值噪声，边缘左右、上下能无缝衔接，
配合 StandardMaterial3D 的三平面映射（uv1_triplanar）就能贴到任意大小的方块上。
"""
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

OUT = Path(__file__).resolve().parent
rng = np.random.default_rng(7)


def tile_noise(size, cells, octaves=4):
    """周期性值噪声：在 cells×cells 的格点上取随机值，双三次插值放大，多层叠加。"""
    acc = np.zeros((size, size))
    amp, total = 1.0, 0.0
    for o in range(octaves):
        c = cells * (2 ** o)
        grid = rng.random((c, c))
        img = Image.fromarray((grid * 255).astype(np.uint8))
        # 先在四周补一圈（周期延拓），放大后再裁掉，保证可平铺
        big = np.pad(np.array(img), 2, mode="wrap")
        scale = size / c
        up = Image.fromarray(big).resize((int((c + 4) * scale), int((c + 4) * scale)), Image.BICUBIC)
        off = int(2 * scale)
        acc += np.array(up, dtype=float)[off:off + size, off:off + size] / 255.0 * amp
        total += amp
        amp *= 0.5
    return acc / total


def save(arr, name):
    Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8)).save(OUT / name, optimize=True)
    print("wrote", name)


def colorize(n, dark, light):
    dark, light = np.array(dark, float), np.array(light, float)
    return dark + (light - dark) * n[..., None]


# 1. 地面：浅色水泥 + 每米一条细线（贴图覆盖 2m×2m）+ 2m 一条粗线
S = 512
n = tile_noise(S, 4, 5)
floor = colorize(n, (86, 82, 78), (128, 121, 112))
for i in range(0, S, S // 2):
    floor[:, i:i + 4] *= 0.72
    floor[i:i + 4, :] *= 0.72
for i in range(S // 4, S, S // 2):
    floor[:, i:i + 2] *= 0.86
    floor[i:i + 2, :] *= 0.86
speck = rng.random((S, S)) > 0.995
floor[speck] *= 0.6
save(floor, "floor.png")

# 2. 墙面：竖向混凝土板，板缝 + 模板孔
wall_n = tile_noise(S, 3, 5)
wall = colorize(wall_n, (104, 102, 100), (146, 142, 136))
for x in (0, S // 2):
    wall[:, x:x + 5] *= 0.6
wall[0:5, :] *= 0.65
img = Image.fromarray(wall.astype(np.uint8))
d = ImageDraw.Draw(img)
for x in (S // 8, 3 * S // 8, 5 * S // 8, 7 * S // 8):
    for y in (S // 6, S // 2, 5 * S // 6):
        d.ellipse([x - 6, y - 6, x + 6, y + 6], fill=(92, 94, 98))
save(np.array(img, float), "wall.png")

# 3. 墙面法线贴图：由噪声高度图求梯度（演示 PBR 的 normal_texture）
h = tile_noise(S, 8, 4) * 0.6 + wall_n * 0.4
h[:, 0:5] -= 0.35
h[:, S // 2:S // 2 + 5] -= 0.35
gx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * 6.0
gy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * 6.0
nz = np.ones_like(h)
ln = np.sqrt(gx * gx + gy * gy + nz)
normal = np.stack([(-gx / ln) * 0.5 + 0.5, (gy / ln) * 0.5 + 0.5, (nz / ln) * 0.5 + 0.5], -1) * 255
save(normal, "wall_normal.png")

# 4. 箱子：木框 + 斜撑
C = 256
cn = tile_noise(C, 2, 4)
grain = (np.sin(np.linspace(0, 40, C))[None, :] * 0.5 + 0.5) * 0.25 + cn * 0.75
crate = colorize(grain, (120, 78, 42), (196, 140, 82))
img = Image.fromarray(crate.astype(np.uint8))
d = ImageDraw.Draw(img)
frame = (86, 54, 30)
d.rectangle([0, 0, C - 1, C - 1], outline=frame, width=22)
d.line([(18, 18), (C - 18, C - 18)], fill=frame, width=20)
for p in [(11, 11), (C - 12, 11), (11, C - 12), (C - 12, C - 12)]:
    d.ellipse([p[0] - 4, p[1] - 4, p[0] + 4, p[1] + 4], fill=(60, 60, 64))
save(np.array(img, float), "crate.png")

# 5. 金属：拉丝 + 警示条纹（用于平台边缘、柱脚）
M = 256
brush = tile_noise(M, 2, 3)[:, :1].repeat(M, 1) * 0.5 + tile_noise(M, 16, 2) * 0.5
metal = colorize(brush, (70, 76, 86), (120, 128, 140))
save(metal, "metal.png")
stripe = np.zeros((M, M, 3))
yy, xx = np.mgrid[0:M, 0:M]
band = ((xx + yy) // (M // 4)) % 2 == 0
stripe[band] = (232, 178, 40)
stripe[~band] = (38, 38, 42)
stripe *= (0.85 + 0.15 * tile_noise(M, 4, 3))[..., None]
save(stripe, "hazard.png")

# 6. 弹孔：带透明度的焦黑圆斑（贴在命中点的小四边形上）
B = 64
yy, xx = np.mgrid[0:B, 0:B]
r = np.sqrt((xx - B / 2 + 0.5) ** 2 + (yy - B / 2 + 0.5) ** 2) / (B / 2)
alpha = np.clip((1.0 - r) * 1.8, 0, 1) ** 1.6 * 230
core = r < 0.28
rgb = np.zeros((B, B, 3)) + 30
rgb[core] = 8
alpha[core] = 255
save(np.dstack([rgb, alpha]), "bullet_hole.png")

# 7. 枪口火光：星形 + 径向渐变（加法混合，黑色就是透明）
F = 128
yy, xx = np.mgrid[0:F, 0:F]
dx, dy = (xx - F / 2 + 0.5) / (F / 2), (yy - F / 2 + 0.5) / (F / 2)
r = np.sqrt(dx * dx + dy * dy)
ang = np.arctan2(dy, dx)
star = np.clip(1.0 - r / (0.45 + 0.55 * np.abs(np.cos(ang * 3)) ** 8), 0, 1)
glow = np.clip(1.0 - r, 0, 1) ** 2
v = np.clip(star * 1.2 + glow * 0.6, 0, 1)
flash = np.stack([v * 255, v ** 1.4 * 210, v ** 2.5 * 120], -1)
save(flash, "muzzle_flash.png")
