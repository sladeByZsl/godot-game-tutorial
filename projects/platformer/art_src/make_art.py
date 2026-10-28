#!/usr/bin/env python3
"""生成平台跳跃示例用到的全部图片（不依赖外部美术素材）。

    python3 art_src/make_art.py        # 在工程根目录运行，输出到 art/

所有图都先按 4 倍尺寸画，再缩小，边缘自然有抗锯齿。
瓦片集 tiles.png 的布局（每格 32x32）：
  第 0–3 行 前 4 列：地面地形，16 种"四边是否相连"的组合，序号 = 上1 + 右2 + 下4 + 左8
  第 4 行：单向木平台（单块 / 左端 / 中间 / 右端）、尖刺
  第 5 行：装饰（草丛 ×2、红花、黄花、蘑菇、石头、灌木、路牌）
"""
import math
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

OUT = Path(__file__).resolve().parent.parent / "art"
T = 32          # 瓦片尺寸
S = 4           # 超采样倍数
TS = T * S

OUTLINE = (61, 43, 34, 255)
DIRT = (155, 106, 67, 255)
DIRT_DARK = (128, 84, 52, 255)
DIRT_LIGHT = (178, 128, 84, 255)
GRASS = (108, 192, 74, 255)
GRASS_DARK = (78, 154, 54, 255)
GRASS_LIGHT = (160, 228, 106, 255)


def down(img, size):
    return img.resize(size, Image.LANCZOS)


def mask_rrect(box, r, corners, size=(TS, TS)):
    m = Image.new("L", size, 0)
    ImageDraw.Draw(m).rounded_rectangle(box, r, fill=255, corners=corners)
    return m


# ------------------------------------------------------------------ 地面
def ground_tile(mask_bits: int, seed: int) -> Image.Image:
    up, right, down_, left = ((mask_bits >> i) & 1 for i in range(4))
    ex = {"t": not up, "r": not right, "b": not down_, "l": not left}
    R, W = 7 * S, 3 * S
    corners = (ex["t"] and ex["l"], ex["t"] and ex["r"], ex["b"] and ex["r"], ex["b"] and ex["l"])
    big = 12 * S
    outer = (0 if ex["l"] else -big, 0 if ex["t"] else -big, TS - 1 if ex["r"] else TS + big, TS - 1 if ex["b"] else TS + big)
    inner = (W if ex["l"] else -big, W if ex["t"] else -big, TS - 1 - W if ex["r"] else TS + big, TS - 1 - W if ex["b"] else TS + big)
    m_out = mask_rrect(outer, R, corners)
    m_in = mask_rrect(inner, R - W, corners)

    img = Image.new("RGBA", (TS, TS), (0, 0, 0, 0))
    img.paste(Image.new("RGBA", (TS, TS), OUTLINE), (0, 0), m_out)

    fill = Image.new("RGBA", (TS, TS), DIRT)
    d = ImageDraw.Draw(fill)
    rnd = random.Random(seed)
    # 泥土里的小石子：离瓦片边缘留出空白，拼起来才看不出接缝
    for _ in range(4):
        x, y = rnd.uniform(7, 25) * S, rnd.uniform(9 if ex["t"] else 6, 26) * S
        rw, rh = rnd.uniform(2.0, 3.6) * S, rnd.uniform(1.4, 2.4) * S
        d.ellipse((x - rw, y - rh, x + rw, y + rh), fill=DIRT_DARK)
        d.ellipse((x - rw * 0.6, y - rh * 0.9, x + rw * 0.2, y - rh * 0.1), fill=DIRT_LIGHT)
    if ex["b"]:
        d.rectangle((0, TS - W - 4 * S, TS, TS), fill=DIRT_DARK)
    if ex["t"]:
        gh = 9 * S
        top = W
        d.rectangle((0, 0, TS, top + gh), fill=GRASS)
        # 草皮下沿的波浪：位置按 8px 周期固定，相邻瓦片能接上
        for cx in range(0, TS + 1, 8 * S):
            d.ellipse((cx - 4 * S, top + gh - 3 * S, cx + 4 * S, top + gh + 3 * S), fill=GRASS)
        for cx in range(4 * S, TS + 1, 8 * S):
            d.ellipse((cx - 2 * S, top + gh - 1 * S, cx + 2 * S, top + gh + 2 * S), fill=GRASS_DARK)
        d.rectangle((0, top, TS, top + 2 * S), fill=GRASS_LIGHT)
    img.paste(fill, (0, 0), m_in)
    return down(img, (T, T))


# ------------------------------------------------------------------ 单向木平台
def wood_tile(kind: str) -> Image.Image:
    img = Image.new("RGBA", (TS, TS), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    x0 = 2 * S if kind in ("single", "left") else -10 * S
    x1 = TS - 2 * S if kind in ("single", "right") else TS + 10 * S
    h = 12 * S
    # 阴影
    d.rounded_rectangle((x0 + S, h - 2 * S, x1 - S, h + 4 * S), 3 * S, fill=(30, 20, 40, 70))
    d.rounded_rectangle((x0, 0, x1, h), 4 * S, fill=OUTLINE)
    d.rounded_rectangle((x0 + 2 * S, 2 * S, x1 - 2 * S, h - 2 * S), 3 * S, fill=(201, 140, 82, 255))
    d.rectangle((x0 + 2 * S, 2 * S, x1 - 2 * S, 4 * S), fill=(232, 178, 112, 255))
    d.line((x0, 7 * S, x1, 7 * S), fill=(160, 104, 58, 255), width=S)
    for bx in (6 * S, TS - 6 * S):
        if x0 < bx < x1:
            d.ellipse((bx - S * 1.3, 4.5 * S, bx + S * 1.3, 7.1 * S), fill=(110, 78, 60, 255))
    if kind in ("left", "right", "single"):
        # 两端下面的支撑木条
        for sx in ([6 * S] if kind == "left" else [TS - 6 * S] if kind == "right" else [6 * S, TS - 6 * S]):
            d.polygon([(sx - 2 * S, h), (sx + 2 * S, h), (sx, h + 7 * S)], fill=OUTLINE)
    return down(img, (T, T))


def spike_tile() -> Image.Image:
    img = Image.new("RGBA", (TS, TS), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    base = TS
    d.rounded_rectangle((S, base - 5 * S, TS - S, base), 2 * S, fill=OUTLINE)
    for i in range(3):
        cx = (5.5 + i * 10.5) * S
        top = base - 20 * S
        d.polygon([(cx - 5.5 * S, base - 3 * S), (cx + 5.5 * S, base - 3 * S), (cx, top - 2 * S)], fill=OUTLINE)
        d.polygon([(cx - 3.8 * S, base - 4.5 * S), (cx + 3.8 * S, base - 4.5 * S), (cx, top + 1 * S)], fill=(214, 220, 234, 255))
        d.polygon([(cx, base - 4.5 * S), (cx + 3.8 * S, base - 4.5 * S), (cx, top + 1 * S)], fill=(160, 170, 192, 255))
    d.rounded_rectangle((2 * S, base - 4 * S, TS - 2 * S, base - S), S, fill=(120, 118, 140, 255))
    return down(img, (T, T))


# ------------------------------------------------------------------ 装饰
def decor_tile(kind: str, seed: int) -> Image.Image:
    img = Image.new("RGBA", (TS, TS), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    rnd = random.Random(seed)
    B = TS  # 底边（贴着下面的地面）
    if kind.startswith("grass"):
        n = 5 if kind == "grass1" else 7
        for i in range(n):
            x = (6 + i * (20 / (n - 1))) * S + rnd.uniform(-1, 1) * S
            hgt = rnd.uniform(7, 13) * S
            lean = rnd.uniform(-3, 3) * S
            col = GRASS_DARK if i % 2 else GRASS
            d.polygon([(x - 2 * S, B), (x + 2 * S, B), (x + lean, B - hgt)], fill=col)
    elif kind.startswith("flower"):
        petal = (238, 86, 96, 255) if kind == "flower_r" else (250, 204, 64, 255)
        for i, (x, hgt) in enumerate([(11, 15), (21, 11)]):
            x *= S
            hgt *= S
            d.line((x, B, x, B - hgt), fill=GRASS_DARK, width=int(1.6 * S))
            d.ellipse((x - 4 * S, B - 4 * S, x, B - 1 * S), fill=GRASS)
            cy = B - hgt
            for a in range(5):
                ang = a / 5 * math.tau
                px, py = x + math.cos(ang) * 3 * S, cy + math.sin(ang) * 3 * S
                d.ellipse((px - 2.4 * S, py - 2.4 * S, px + 2.4 * S, py + 2.4 * S), fill=petal)
            d.ellipse((x - 1.8 * S, cy - 1.8 * S, x + 1.8 * S, cy + 1.8 * S), fill=(255, 240, 200, 255))
    elif kind == "mushroom":
        d.rounded_rectangle((13 * S, B - 11 * S, 19 * S, B), 2 * S, fill=OUTLINE)
        d.rounded_rectangle((14 * S, B - 10 * S, 18 * S, B - S), 1.5 * S, fill=(246, 232, 210, 255))
        d.pieslice((6 * S, B - 21 * S, 26 * S, B - 3 * S), 180, 360, fill=OUTLINE)
        d.pieslice((7.5 * S, B - 19.5 * S, 24.5 * S, B - 4.5 * S), 180, 360, fill=(226, 72, 70, 255))
        for (x, y, r) in [(12, -15, 2), (19, -16, 1.6), (16, -18.5, 1.2)]:
            d.ellipse(((x - r) * S, B + (y - r) * S, (x + r) * S, B + (y + r) * S), fill=(255, 245, 235, 255))
    elif kind == "rock":
        d.rounded_rectangle((7 * S, B - 12 * S, 25 * S, B), 6 * S, fill=OUTLINE)
        d.rounded_rectangle((8.5 * S, B - 10.5 * S, 23.5 * S, B - 1 * S), 5 * S, fill=(150, 156, 172, 255))
        d.ellipse((11 * S, B - 9 * S, 17 * S, B - 6 * S), fill=(190, 196, 210, 255))
    elif kind == "bush":
        for (x, y, r) in [(9, -8, 8), (23, -8, 8), (16, -13, 10)]:
            d.ellipse(((x - r - 1.5) * S, B + (y - r - 1.5) * S, (x + r + 1.5) * S, B + (y + r + 1.5) * S), fill=OUTLINE)
        for (x, y, r) in [(9, -8, 8), (23, -8, 8), (16, -13, 10)]:
            d.ellipse(((x - r) * S, B + (y - r) * S, (x + r) * S, B + (y + r) * S), fill=GRASS_DARK)
        for (x, y, r) in [(13, -16, 4), (21, -11, 3)]:
            d.ellipse(((x - r) * S, B + (y - r) * S, (x + r) * S, B + (y + r) * S), fill=GRASS)
        d.rectangle((0, B - 1.5 * S, TS, B), fill=(0, 0, 0, 0))
    elif kind == "sign":
        d.rectangle((14 * S, B - 16 * S, 18 * S, B), fill=OUTLINE)
        d.rectangle((15 * S, B - 16 * S, 17 * S, B), fill=(170, 112, 66, 255))
        d.polygon([(4 * S, B - 26 * S), (22 * S, B - 26 * S), (28 * S, B - 20.5 * S), (22 * S, B - 15 * S), (4 * S, B - 15 * S)], fill=OUTLINE)
        d.polygon([(5.5 * S, B - 24.5 * S), (21.5 * S, B - 24.5 * S), (26 * S, B - 20.5 * S), (21.5 * S, B - 16.5 * S), (5.5 * S, B - 16.5 * S)], fill=(214, 160, 98, 255))
        d.polygon([(10 * S, B - 22 * S), (17 * S, B - 22 * S), (17 * S, B - 24 * S), (21 * S, B - 20.5 * S), (17 * S, B - 17 * S), (17 * S, B - 19 * S), (10 * S, B - 19 * S)], fill=(110, 70, 44, 255))
    return down(img, (T, T))


def make_tiles():
    atlas = Image.new("RGBA", (8 * T, 6 * T), (0, 0, 0, 0))
    for m in range(16):
        atlas.paste(ground_tile(m, 100 + m), ((m % 4) * T, (m // 4) * T))
    for i, k in enumerate(["single", "left", "mid", "right"]):
        atlas.paste(wood_tile(k), (i * T, 4 * T))
    atlas.paste(spike_tile(), (4 * T, 4 * T))
    for i, k in enumerate(["grass1", "grass2", "flower_r", "flower_y", "mushroom", "rock", "bush", "sign"]):
        atlas.paste(decor_tile(k, 7 + i), (i * T, 5 * T))
    atlas.save(OUT / "tiles.png")


# ------------------------------------------------------------------ 视差背景（水平方向首尾相接）
def wrap_draw(draw_fn, W):
    for off in (-W, 0, W):
        draw_fn(off)


def make_mountains():
    W, H = 1024, 300
    img = Image.new("RGBA", (W * S, H * S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    rnd = random.Random(3)
    ranges = [((178, 196, 232, 255), 7, 150, 250), ((150, 172, 218, 255), 6, 110, 200)]
    for col, n, hmin, hmax in ranges:
        peaks = [(i * W / n + rnd.uniform(-40, 40), rnd.uniform(hmin, hmax), rnd.uniform(150, 230)) for i in range(n)]
        for (px, ph, half) in peaks:
            def tri(off, px=px, ph=ph, half=half, col=col):
                x = (px + off) * S
                top = (H - ph) * S
                d.polygon([(x - half * S, H * S), (x - 14 * S, top + 10 * S), (x, top), (x + 14 * S, top + 10 * S), (x + half * S, H * S)], fill=col)
                # 雪顶
                k = 0.22
                d.polygon([(x - half * k * S, top + ph * k * S), (x - 14 * S * 0.9, top + 9 * S), (x, top), (x + 14 * S * 0.9, top + 9 * S),
                           (x + half * k * S, top + ph * k * S), (x + half * k * 0.4 * S, top + ph * k * 0.8 * S),
                           (x, top + ph * k * 1.1 * S), (x - half * k * 0.5 * S, top + ph * k * 0.75 * S)], fill=(246, 249, 255, 255))
            wrap_draw(tri, W)
    down(img, (W, H)).save(OUT / "bg_mountains.png")


def make_hills():
    W, H = 1024, 280
    img = Image.new("RGBA", (W * S, H * S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    rnd = random.Random(5)

    def hill_poly(base, amps, col):
        pts = []
        for xi in range(0, W * S + 1, S * 4):
            x = xi / S
            y = base + sum(a * math.sin(2 * math.pi * k * x / W + ph) for a, k, ph in amps)
            pts.append((xi, y * S))
        pts += [(W * S, H * S), (0, H * S)]
        d.polygon(pts, fill=col)
        return lambda x: base + sum(a * math.sin(2 * math.pi * k * x / W + ph) for a, k, ph in amps)

    back = hill_poly(120, [(26, 2, 0.5), (14, 5, 1.7), (6, 9, 0.2)], (120, 190, 140, 255))
    # 后排的圆形小树
    for i in range(14):
        tx = i * W / 14 + rnd.uniform(-20, 20)
        r = rnd.uniform(14, 22)

        def tree(off, tx=tx, r=r):
            x = tx + off
            ty = back(tx % W) + 6
            d.rectangle(((x - 2.5) * S, (ty - r) * S, (x + 2.5) * S, (ty + 6) * S), fill=(86, 120, 100, 255))
            d.ellipse(((x - r) * S, (ty - r * 2.4) * S, (x + r) * S, (ty - r * 0.4) * S), fill=(92, 168, 118, 255))
            d.ellipse(((x - r * 0.5) * S, (ty - r * 2.1) * S, (x + r * 0.2) * S, (ty - r * 1.4) * S), fill=(128, 200, 146, 255))
        wrap_draw(tree, W)
    hill_poly(175, [(22, 3, 2.0), (10, 7, 0.9)], (96, 172, 112, 255))
    down(img, (W, H)).save(OUT / "bg_hills.png")


def make_clouds():
    W, H = 1024, 200
    img = Image.new("RGBA", (W * S, H * S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    rnd = random.Random(9)
    for i in range(6):
        cx, cy = i * W / 6 + rnd.uniform(-30, 30), rnd.uniform(50, 150)
        sc = rnd.uniform(0.7, 1.25)
        blobs = [(-34, 6, 20), (-12, -8, 26), (16, -4, 24), (38, 8, 17), (0, 10, 22)]

        def cloud(off, cx=cx, cy=cy, sc=sc, blobs=blobs):
            for (bx, by, r) in blobs:
                x, y, rr = cx + off + bx * sc, cy + by * sc + 4, r * sc
                d.ellipse(((x - rr) * S, (y - rr) * S, (x + rr) * S, (y + rr) * S), fill=(205, 222, 240, 255))
            for (bx, by, r) in blobs:
                x, y, rr = cx + off + bx * sc, cy + by * sc, r * sc
                d.ellipse(((x - rr) * S, (y - rr) * S, (x + rr) * S, (y + rr) * S), fill=(255, 255, 255, 255))
        wrap_draw(cloud, W)
    down(img, (W, H)).save(OUT / "bg_clouds.png")


def make_particles():
    n = 64
    img = Image.new("RGBA", (n, n), (255, 255, 255, 0))
    a = Image.new("L", (n, n), 0)
    ImageDraw.Draw(a).ellipse((8, 8, n - 8, n - 8), fill=255)
    a = a.filter(ImageFilter.GaussianBlur(3))
    img.putalpha(a)
    down(img, (16, 16)).save(OUT / "dot.png")
    star = Image.new("RGBA", (n, n), (255, 255, 255, 0))
    d = ImageDraw.Draw(star)
    c = n / 2
    pts = []
    for i in range(8):
        r = c - 2 if i % 2 == 0 else c * 0.28
        ang = i / 8 * math.tau - math.pi / 2
        pts.append((c + math.cos(ang) * r, c + math.sin(ang) * r))
    d.polygon(pts, fill=(255, 255, 255, 255))
    down(star, (16, 16)).save(OUT / "star.png")


if __name__ == "__main__":
    OUT.mkdir(exist_ok=True)
    make_tiles()
    make_mountains()
    make_hills()
    make_clouds()
    make_particles()
    print("ok ->", OUT)
