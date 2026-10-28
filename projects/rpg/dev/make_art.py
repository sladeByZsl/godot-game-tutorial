#!/usr/bin/env python3
"""生成俯视角 RPG 示例用到的全部像素图（瓦片集、角色、物品、界面）。

用法：python3 dev/make_art.py   （在 projects/rpg 目录下运行，输出到 art/）
所有图都是 16x16 像素一格，游戏里用 Camera2D 放大 3 倍、最近邻过滤显示。
"""
import random
from pathlib import Path
from PIL import Image

OUT = Path(__file__).resolve().parent.parent / "art"
OUT.mkdir(exist_ok=True)
T = 16

# ---------------------------------------------------------------- 调色板（统一配色）
C = {
    "o": (38, 32, 52), "O": (62, 52, 78),                                  # 描边
    "g0": (92, 156, 74), "g1": (112, 178, 88), "g2": (74, 134, 66), "g3": (138, 200, 104),
    "p0": (216, 186, 132), "p1": (192, 160, 106), "p2": (234, 210, 160),
    "w0": (66, 130, 198), "w1": (98, 160, 222), "w2": (50, 104, 170), "foam": (206, 232, 246),
    "sand": (230, 210, 158),
    "wd0": (156, 102, 60), "wd1": (116, 72, 44), "wd2": (190, 136, 84),
    "l0": (52, 128, 72), "l1": (74, 158, 86), "l2": (36, 96, 62), "l3": (112, 188, 102),
    "pn0": (40, 110, 84), "pn1": (60, 140, 98), "pn2": (28, 80, 66),
    "r0": (186, 76, 68), "r1": (148, 54, 56), "r2": (218, 108, 88),
    "wl0": (238, 222, 188), "wl1": (208, 188, 152),
    "st0": (142, 148, 162), "st1": (104, 108, 126), "st2": (182, 188, 200),
    "red": (228, 86, 92), "yel": (246, 212, 90), "wht": (246, 244, 236), "pink": (240, 150, 170),
    "glass": (140, 210, 240),
}


def rgb(k, a=255):
    return C[k] + (a,)


def new(w, h):
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


def put(img, x, y, k, a=255):
    if 0 <= x < img.width and 0 <= y < img.height:
        img.putpixel((x, y), rgb(k, a) if isinstance(k, str) else k)


def rect(img, x0, y0, x1, y1, k):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            put(img, x, y, k)


def ascii_sprite(rows, pal, img=None, ox=0, oy=0, flip=False):
    """用字符画画像素：pal 把字符映射到颜色，'.' 是透明。"""
    w = max(len(r) for r in rows)
    img = img or new(w, len(rows))
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch == "." or ch == " ":
                continue
            xx = (w - 1 - x) if flip else x
            put(img, ox + xx, oy + y, pal[ch])
    return img


# ---------------------------------------------------------------- 瓦片
def grass(seed, tufts=6):
    rnd = random.Random(seed)
    img = new(T, T)
    rect(img, 0, 0, 15, 15, "g0")
    for _ in range(18):
        put(img, rnd.randrange(16), rnd.randrange(16), rnd.choice(["g1", "g2"]))
    for _ in range(tufts):
        x, y = rnd.randrange(1, 15), rnd.randrange(2, 15)
        put(img, x, y, "g2"); put(img, x, y - 1, "g1"); put(img, x + 1, y, "g2")
    return img


def edge_tile(base_fn, mask, border):
    """mask 的四个位表示上/右/下/左是不是同类瓦片；不是的那一边画过渡边。"""
    img = base_fn()
    rnd = random.Random(mask * 31 + 7)
    for side, bit in (("u", 1), ("r", 2), ("d", 4), ("l", 8)):
        if mask & bit:
            continue
        for i in range(16):
            depth = border + (1 if rnd.random() < 0.35 else 0)
            for d in range(depth):
                x, y = {"u": (i, d), "d": (i, 15 - d), "l": (d, i), "r": (15 - d, i)}[side]
                put(img, x, y, "g0" if d < depth - 1 else "g2")
    return img


def path_base():
    rnd = random.Random(3)
    img = new(T, T)
    rect(img, 0, 0, 15, 15, "p0")
    for _ in range(14):
        put(img, rnd.randrange(16), rnd.randrange(16), rnd.choice(["p1", "p2"]))
    return img


def path_tile(mask):
    img = edge_tile(path_base, mask, 3)
    # 草地边缘再撒几根草，过渡更自然
    rnd = random.Random(mask)
    for _ in range(4):
        x, y = rnd.randrange(16), rnd.randrange(16)
        if img.getpixel((x, y))[:3] == C["g0"]:
            put(img, x, y, "g1")
    return img


def water_tile(mask):
    rnd = random.Random(mask + 100)
    img = new(T, T)
    rect(img, 0, 0, 15, 15, "w0")
    for _ in range(10):
        put(img, rnd.randrange(16), rnd.randrange(16), "w2")
    for _ in range(2):   # 波纹
        x, y = rnd.randrange(2, 11), rnd.randrange(3, 13)
        for i in range(4):
            put(img, x + i, y - (1 if i in (1, 2) else 0), "w1")
    for side, bit in (("u", 1), ("r", 2), ("d", 4), ("l", 8)):
        if mask & bit:
            continue
        for i in range(16):
            for d, k in enumerate(["g0", "g2", "sand", "w1" if (i // 2) % 2 else "foam"]):
                x, y = {"u": (i, d), "d": (i, 15 - d), "l": (d, i), "r": (15 - d, i)}[side]
                put(img, x, y, k)
    return img


def fence_tile(mask):
    img = new(T, T)
    if mask & 8: rect(img, 0, 6, 7, 7, "wd0"); rect(img, 0, 10, 7, 10, "wd0"); rect(img, 0, 8, 7, 8, "wd1"); rect(img, 0, 11, 7, 11, "wd1")
    if mask & 2: rect(img, 8, 6, 15, 7, "wd0"); rect(img, 8, 10, 15, 10, "wd0"); rect(img, 8, 8, 15, 8, "wd1"); rect(img, 8, 11, 15, 11, "wd1")
    if mask & 1: rect(img, 7, 0, 8, 4, "wd0"); put(img, 6, 0, "wd1")
    if mask & 4: rect(img, 7, 12, 8, 15, "wd0"); rect(img, 9, 12, 9, 15, "wd1")
    # 柱子
    rect(img, 5, 3, 10, 13, "o")
    rect(img, 6, 4, 9, 12, "wd0")
    rect(img, 6, 4, 7, 12, "wd2")
    rect(img, 6, 12, 9, 12, "wd1")
    put(img, 6, 3, "o"); put(img, 9, 3, "o")
    return img


def bridge():
    img = new(T, T)
    rect(img, 0, 0, 15, 15, "wd0")
    for x in range(0, 16, 4):
        rect(img, x, 0, x, 15, "wd1")
        rect(img, x + 1, 0, x + 1, 15, "wd2")
    rect(img, 0, 0, 15, 1, "o"); rect(img, 0, 2, 15, 2, "wd1")
    rect(img, 0, 14, 15, 15, "o"); rect(img, 0, 13, 15, 13, "wd1")
    return img


def deco_flowers(col, seed):
    rnd = random.Random(seed)
    img = new(T, T)
    for (x, y) in [(3, 4), (10, 6), (6, 11), (12, 12)][: 3 + seed % 2]:
        x += rnd.randrange(-1, 2)
        put(img, x, y + 2, "g2"); put(img, x, y + 1, "g2")
        for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
            put(img, x + dx, y + dy, col)
        put(img, x, y, "yel" if col != "yel" else "wht")
    return img


def deco_tuft():
    img = new(T, T)
    for x, h in [(5, 3), (6, 5), (7, 4), (8, 6), (9, 3), (10, 4)]:
        for y in range(12 - h, 12):
            put(img, x, y, "g2" if y > 12 - h else "g3")
    return img


def deco_pebbles():
    img = new(T, T)
    for x, y in [(4, 5), (10, 9), (6, 12)]:
        rect(img, x, y, x + 1, y, "st0"); put(img, x, y - 1, "st2"); put(img, x + 1, y + 1, "st1")
    return img


def shadow_on(img, cx, cy, rx, ry, a=70):
    for y in range(cy - ry, cy + ry + 1):
        for x in range(cx - rx, cx + rx + 1):
            if ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1 and 0 <= x < img.width and 0 <= y < img.height:
                if img.getpixel((x, y))[3] == 0:
                    img.putpixel((x, y), (20, 30, 30, a))


def blob(img, cx, cy, rx, ry, k_out, k_fill, k_hi=None, k_lo=None):
    for y in range(int(cy - ry - 1), int(cy + ry + 2)):
        for x in range(int(cx - rx - 1), int(cx + rx + 2)):
            d = ((x + .5 - cx) / rx) ** 2 + ((y + .5 - cy) / ry) ** 2
            d2 = ((x + .5 - cx) / (rx + 1)) ** 2 + ((y + .5 - cy) / (ry + 1)) ** 2
            if d <= 1:
                k = k_fill
                if k_lo and (y - cy) / ry + (x - cx) / rx * .3 > .45:
                    k = k_lo
                if k_hi and (y - cy) / ry < -.35 and (x - cx) / rx < .1:
                    k = k_hi
                put(img, x, y, k)
            elif d2 <= 1:
                put(img, x, y, k_out)


def rock():
    img = new(T, T)
    shadow_on(img, 8, 13, 6, 2)
    blob(img, 8, 9.5, 5.5, 4.5, "o", "st0", "st2", "st1")
    return img


def bush():
    img = new(T, T)
    shadow_on(img, 8, 13, 7, 2)
    for cx, cy, r in [(5, 9, 4), (11, 9, 4), (8, 7, 4.5)]:
        blob(img, cx, cy, r, r * .9, "o", "l1", "l3", "l0")
    for cx, cy, r in [(5, 9, 3), (11, 9, 3), (8, 7, 3.5)]:
        blob(img, cx, cy, r, r * .9, "l1", "l1", "l3", "l0")
    put(img, 6, 6, "red"); put(img, 11, 8, "red"); put(img, 8, 10, "red")
    return img


def stump():
    img = new(T, T)
    shadow_on(img, 8, 13, 6, 2)
    rect(img, 3, 7, 12, 12, "o"); rect(img, 4, 8, 11, 12, "wd0"); rect(img, 4, 8, 5, 12, "wd2"); rect(img, 10, 8, 11, 12, "wd1")
    blob(img, 8, 6.5, 4.5, 2.2, "o", "wd2")
    put(img, 7, 6, "wd0"); put(img, 8, 6, "wd0")
    return img


def sign():
    img = new(T, T)
    shadow_on(img, 8, 14, 4, 1)
    rect(img, 7, 9, 8, 14, "wd1")
    rect(img, 2, 3, 13, 10, "o"); rect(img, 3, 4, 12, 9, "wd2")
    rect(img, 4, 5, 10, 5, "wd1"); rect(img, 4, 7, 11, 7, "wd1")
    return img


def tree_round():
    img = new(T, 2 * T)
    shadow_on(img, 8, 29, 7, 2, 80)
    rect(img, 6, 20, 9, 29, "o"); rect(img, 7, 20, 8, 28, "wd0"); put(img, 7, 22, "wd2"); put(img, 7, 25, "wd2")
    blob(img, 8, 11, 7.5, 9.5, "o", "l0", "l3", "l2")
    for cx, cy in [(5, 8), (10, 12), (6, 15), (11, 6)]:
        put(img, cx, cy, "l1"); put(img, cx + 1, cy, "l1"); put(img, cx, cy + 1, "l2")
    return img


def tree_pine():
    img = new(T, 2 * T)
    shadow_on(img, 8, 29, 6, 2, 80)
    rect(img, 6, 23, 9, 29, "o"); rect(img, 7, 23, 8, 28, "wd1")
    for i, (y0, w) in enumerate([(2, 2), (6, 4), (10, 5), (14, 6), (18, 7)]):
        for y in range(y0, y0 + 6):
            half = max(1, int(w * (y - y0 + 1) / 6))
            for x in range(8 - half, 8 + half):
                k = "pn0" if x >= 8 else "pn1"
                if y == y0 + 5:
                    k = "pn2"
                put(img, x, y, k)
            put(img, 8 - half - 1, y, "o"); put(img, 8 + half, y, "o")
    rect(img, 7, 1, 8, 1, "o")
    return img


def house():
    img = new(4 * T, 4 * T)
    W, H = 64, 64
    shadow_on(img, 32, 61, 30, 3, 70)
    # 墙
    rect(img, 4, 30, 59, 61, "o")
    rect(img, 5, 31, 58, 60, "wl0")
    rect(img, 5, 31, 58, 33, "wl1")
    for x in range(12, 58, 12):
        rect(img, x, 34, x, 60, "wl1")
    rect(img, 5, 58, 58, 60, "st1"); rect(img, 5, 57, 58, 57, "st0")
    # 门
    rect(img, 26, 41, 37, 61, "o"); rect(img, 27, 42, 36, 60, "wd1"); rect(img, 28, 43, 35, 60, "wd0")
    rect(img, 31, 43, 32, 60, "wd1"); put(img, 34, 51, "yel")
    # 窗
    for wx in (10, 44):
        rect(img, wx, 40, wx + 10, 49, "o"); rect(img, wx + 1, 41, wx + 9, 48, "glass")
        rect(img, wx + 5, 41, wx + 5, 48, "o"); rect(img, wx + 1, 44, wx + 9, 44, "o")
        rect(img, wx + 1, 41, wx + 3, 42, "wht")
        rect(img, wx - 1, 50, wx + 11, 51, "wd1")
    # 屋顶（梯形，带瓦片纹）
    for y in range(2, 34):
        t = (y - 2) / 31
        half = int(18 + 14 * t)
        for x in range(32 - half, 32 + half):
            k = "r0"
            if (y - 2) % 5 == 4:
                k = "r1"
            elif ((x + (y // 5) * 3) % 6) == 0:
                k = "r1"
            if y < 6:
                k = "r2"
            put(img, x, y, k)
        put(img, 32 - half - 1, y, "o"); put(img, 32 + half, y, "o")
    rect(img, 13, 1, 50, 1, "o")
    rect(img, 0, 33, 63, 34, "o"); rect(img, 1, 33, 62, 33, "r1")
    # 烟囱
    rect(img, 44, 0, 50, 10, "o"); rect(img, 45, 1, 49, 9, "st0"); rect(img, 45, 1, 49, 2, "st2")
    return img


def build_tiles():
    atlas = new(8 * T, 12 * T)

    def place(img, cx, cy):
        atlas.alpha_composite(img, (cx * T, cy * T))

    for i in range(4):
        place(grass(i, tufts=3 + i * 2), i, 0)
    place(deco_flowers("red", 1), 4, 0)
    place(deco_flowers("yel", 2), 5, 0)
    place(deco_tuft(), 6, 0)
    place(deco_pebbles(), 7, 0)
    for m in range(16):
        place(path_tile(m), m % 8, 1 + m // 8)
        place(water_tile(m), m % 8, 3 + m // 8)
        place(fence_tile(m), m % 8, 5 + m // 8)
    for i, fn in enumerate([bridge, rock, bush, stump, sign]):
        place(fn(), i, 7)
    place(tree_round(), 0, 8)
    place(tree_pine(), 1, 8)
    place(house(), 4, 8)
    atlas.save(OUT / "tiles.png")


# ---------------------------------------------------------------- 角色
HERO = {"o": rgb("o"), "h": (124, 72, 44, 255), "H": (164, 104, 62, 255), "s": (246, 204, 164, 255),
        "S": (220, 168, 130, 255), "e": rgb("o"), "b": (64, 120, 204, 255), "B": (44, 86, 160, 255),
        "l": (120, 78, 46, 255), "y": rgb("yel"), "p": (70, 62, 90, 255), "k": (96, 60, 40, 255), "w": rgb("wht")}

HERO_DOWN = [
    "................",
    ".....oooooo.....",
    "....ohhHHhho....",
    "...ohhHhhhhho...",
    "...ohhhhhhhho...",
    "...ohsssssho....",
    "...osesssseso...",
    "...osssssssso...",
    "....oSssssSo....",
    "...obbbbbbbbo...",
    "..osobbbbbbosoo.",
    "..osoBllylBoso..",
    "...oobbbbbboo...",
]
HERO_UP = [
    "................",
    ".....oooooo.....",
    "....ohhHHhho....",
    "...ohhHHHhhho...",
    "...ohhhhhhhho...",
    "...ohhhhhhhho...",
    "...ohhhhhhhho...",
    "...oShhhhhhSo...",
    "....oSSSSSSo....",
    "...obbbbbbbbo...",
    "..osobbBBbbosoo.",
    "..osoBllllBoso..",
    "...oobbbbbboo...",
]
HERO_SIDE = [
    "................",
    ".....ooooo......",
    "....ohhHHho.....",
    "...ohhHHhhho....",
    "...ohhhhhhhso...",
    "...ohhhhssso....",
    "...ohhhsssesoo..",
    "...ohhhssssss o.",
    "....ohSssssoo...",
    "....obbbbbbo....",
    "....obbsobbo....",
    "....oBlslllo....",
    "....obbbbbbo....",
]
LEGS_FRONT = [
    ["....oppppppo....", "....opo..opo....", "....oko..oko....", ".....o....o....."],
    ["....oppppppo....", "....opo..opo....", "....oko...oo....", ".....o..........".replace(".....o", ".....o")],
    ["....oppppppo....", "....opo..opo....", "....oko..oko....", ".....o....o....."],
    ["....oppppppo....", "....opo..opo....", "....oo...oko....", "..........o....."],
]
LEGS_SIDE = [
    ["....opppppo.....", ".....opppo......", ".....okkko......", "......ooo......."],
    ["....opppppo.....", "....opo.opo.....", "...oko...oko....", "....o.....o....."],
    ["....opppppo.....", ".....opppo......", ".....okkko......", "......ooo......."],
    ["....opppppo.....", ".....oppo.......", "....okopko......", ".....o.oo......."],
]


def hero_frame(top, legs, bob, lean=0):
    img = new(T, T)
    ascii_sprite([r.replace(" ", ".") for r in top], HERO, img, lean, 0 + bob)
    ascii_sprite(legs, HERO, img, 0, 12)
    return img


def build_player():
    sheet = new(5 * T, 3 * T)
    for row, (top, legs) in enumerate([(HERO_DOWN, LEGS_FRONT), (HERO_UP, LEGS_FRONT), (HERO_SIDE, LEGS_SIDE)]):
        for f in range(4):
            sheet.alpha_composite(hero_frame(top, legs[f], 1 if f in (1, 3) else 0), (f * T, row * T))
        # 攻击帧：身体前倾
        lean = (0, 0, 1)[row]
        atk = hero_frame(top, legs[1], 0, lean)
        sheet.alpha_composite(atk, (4 * T, row * T))
    sheet.save(OUT / "player.png")


def build_slime():
    sheet = new(4 * T, T)
    for f, (rx, ry, cy) in enumerate([(6.5, 5, 10.5), (7.2, 4.4, 11), (6.5, 5, 10.5), (5.8, 5.8, 9.8)]):
        img = new(T, T)
        shadow_on(img, 8, 14, 6, 1, 80)
        blob(img, 8, cy, rx, ry, "o", (96, 204, 150, 255), (190, 246, 210, 255), (60, 160, 126, 255))
        ey = int(cy)
        for ex in (6, 10):
            put(img, ex, ey, "o"); put(img, ex, ey - 1, "o")
        put(img, 8, ey + 2, "o")
        put(img, 5, int(cy - ry + 2), "wht")
        sheet.alpha_composite(img, (f * T, 0))
    sheet.save(OUT / "slime.png")


BAT_PAL = {"o": rgb("o"), "b": (126, 92, 170, 255), "B": (92, 64, 132, 255), "w": (164, 130, 206, 255),
           "e": (255, 230, 120, 255), "f": rgb("wht")}
BAT_UP = [
    "................",
    ".oo..........oo.",
    ".owo...oo...owo.",
    ".owwo.obbo.owwo.",
    "..owwobbbbowwo..",
    "..owwwbebeBwwo..",
    "...owwbbbbBwo...",
    "....ooBbbBoo....",
    "......oBBo......",
    ".......oo.......",
]
BAT_DOWN = [
    "................",
    "................",
    "................",
    "......obbo......",
    ".....obbbbo.....",
    "..ooowbebeBwooo.",
    ".owwwwbbbbBwwwwo",
    ".owwwoBbbBowwwo.",
    "..owo.oBBo.owo..",
    "...o...oo...o...",
]


def build_bat():
    sheet = new(4 * T, T)
    for f, (rows, dy) in enumerate([(BAT_UP, 1), (BAT_DOWN, 2), (BAT_UP, 2), (BAT_DOWN, 1)]):
        img = new(T, T)
        ascii_sprite(rows, BAT_PAL, img, 0, dy)
        sheet.alpha_composite(img, (f * T, 0))
    sheet.save(OUT / "bat.png")


NPC_BASE = [
    "................",
    ".....oooooo.....",
    "....ohhhhhho....",
    "...ohhhhhhhho...",
    "...ohssssssho...",
    "...osesssseso...",
    "...osssssssso...",
    "....oSmmmmSo....",
    "...occcccccco...",
    "..oscccccccsco..",
    "..oscccdccccso..",
    "...occccccccoo..",
    "...occccccccdo..",
    "...occccccccco..",
    "....oooooooooo..",
    "................",
]


def build_npcs():
    chief = {"o": rgb("o"), "h": (232, 232, 236, 255), "s": (240, 196, 156, 255), "S": (214, 162, 126, 255),
             "e": rgb("o"), "m": (232, 232, 236, 255), "c": (176, 64, 72, 255), "d": (246, 212, 90, 255)}
    girl = {"o": rgb("o"), "h": (226, 132, 64, 255), "s": (250, 210, 172, 255), "S": (224, 176, 138, 255),
            "e": rgb("o"), "m": (250, 210, 172, 255), "c": (88, 168, 110, 255), "d": (246, 244, 236, 255)}
    sheet = new(2 * T, 2 * T)
    for row, pal in enumerate([chief, girl]):
        for f in range(2):
            img = new(T, T)
            rows = list(NPC_BASE)
            if row == 0:   # 村长：白胡子
                rows[7] = "....ommmmmmo...."
                rows[8] = "...ocmmmmmmco..."
                rows[9] = "..oscmmmmmmcso.."
            else:          # 村民：马尾
                rows[3] = "...ohhhhhhhhoo.."
                rows[4] = "...ohssssssshho."
                rows[5] = "...osesssseso.ho"
            if f == 1:   # 第二帧：上半身下沉一像素，做呼吸感
                rows = rows[:1] + ["................"] + rows[1:7] + rows[8:]
            ascii_sprite(rows[:16], pal, img)
            shadow_on(img, 8, 15, 5, 1, 70)
            sheet.alpha_composite(img, (f * T, row * T))
    sheet.save(OUT / "npcs.png")


# ---------------------------------------------------------------- 物品 / 界面
HEART = [
    ".ooo...ooo.",
    "orrwo.orrro",
    "orwrrorrrro",
    "orrrrrrrrRo",
    "orrrrrrrrRo",
    ".orrrrrrRo.",
    "..orrrrRo..",
    "...orrRo...",
    "....oRo....",
    ".....o.....",
]


def build_ui():
    hearts = new(3 * T, T)
    full = {"o": rgb("o"), "r": rgb("red"), "R": (176, 52, 70, 255), "w": rgb("wht")}
    empty = {"o": rgb("o"), "r": (70, 62, 90, 255), "R": (56, 48, 74, 255), "w": (90, 82, 112, 255)}
    ascii_sprite(HEART, full, hearts, 2, 3)
    ascii_sprite(HEART, empty, hearts, 2 * T + 2, 3)
    half = new(T, T)
    ascii_sprite(HEART, empty, half, 2, 3)
    left = new(T, T)
    ascii_sprite(HEART, full, left, 2, 3)
    for y in range(T):
        for x in range(7):
            px = left.getpixel((x, y))
            if px[3]:
                half.putpixel((x, y), px)
    hearts.alpha_composite(half, (T, 0))
    hearts.save(OUT / "hearts.png")

    items = new(6 * T, T)
    coin = new(T, T)
    blob(coin, 8, 8, 5, 6, "o", "yel", "wht", (210, 160, 60, 255))
    rect(coin, 8, 5, 8, 10, (210, 160, 60, 255))
    items.alpha_composite(coin, (0, 0))
    potion = ascii_sprite([
        "......oooo......", ".....owwwwo.....", "......owwo......", "......owwo......",
        ".....orrrro.....", "....orwrrrro....", "...orwrrrrrro...", "...orrrrrrrRo...",
        "...orrrrrrrRo...", "....orrrrrRo....", ".....oooooo.....",
    ], {"o": rgb("o"), "w": rgb("wht"), "r": rgb("red"), "R": (176, 52, 70, 255)}, new(T, T), 0, 3)
    items.alpha_composite(potion, (T, 0))
    apple = new(T, T)
    blob(apple, 8, 9.5, 5.5, 5, "o", "red", "pink", (176, 52, 70, 255))
    rect(apple, 8, 2, 8, 4, "wd1"); rect(apple, 9, 2, 11, 3, "l1"); put(apple, 9, 3, "l0")
    items.alpha_composite(apple, (2 * T, 0))
    gel = new(T, T)
    blob(gel, 8, 10, 5.5, 4, "o", (96, 204, 150, 255), (190, 246, 210, 255), (60, 160, 126, 255))
    items.alpha_composite(gel, (3 * T, 0))
    small = new(T, T)
    ascii_sprite(HEART, full, small, 2, 3)
    items.alpha_composite(small, (4 * T, 0))
    key = ascii_sprite([
        "....ooo.........", "...oyyyo........", "...oyoyo........", "...oyyyo........",
        "....oyo.........", "....oyo.........", "....oyoo........", "....oyyo........",
        "....oyo.........", "....oyoo........", "....oyyo........", ".....oo.........",
    ], {"o": rgb("o"), "y": rgb("yel")}, new(T, T), 3, 2)
    items.alpha_composite(key, (5 * T, 0))
    items.save(OUT / "items.png")

    chest = new(2 * T, T)
    for f in range(2):
        img = new(T, T)
        shadow_on(img, 8, 15, 7, 1, 80)
        rect(img, 1, 6, 14, 14, "o"); rect(img, 2, 7, 13, 13, "wd0"); rect(img, 2, 12, 13, 13, "wd1")
        rect(img, 2, 9, 13, 9, (210, 160, 60, 255))
        if f == 0:
            rect(img, 1, 2, 14, 8, "o"); rect(img, 2, 3, 13, 7, "wd2"); rect(img, 2, 7, 13, 7, "wd1")
            rect(img, 7, 6, 8, 9, "yel"); put(img, 7, 8, "o")
        else:
            rect(img, 1, 0, 14, 4, "o"); rect(img, 2, 1, 13, 3, "wd1")
            rect(img, 2, 5, 13, 8, (40, 26, 20, 255)); rect(img, 4, 6, 6, 7, "yel")
        chest.alpha_composite(img, (f * T, 0))
    chest.save(OUT / "chest.png")

    sword = ascii_sprite([
        ".......oo.......", "......owwo......", "......owwo......", "......owSo......",
        "......owSo......", "......owSo......", "......owSo......", "......owSo......",
        "......owSo......", "....oooooooo....", "....oyyyyyyo....", "....oooooooo....",
        "......olko......", "......olko......", "......oyyo......", ".......oo.......",
    ], {"o": rgb("o"), "w": rgb("wht"), "S": (180, 196, 214, 255), "y": rgb("yel"), "l": rgb("wd2"), "k": rgb("wd1")})
    sword.save(OUT / "sword.png")


if __name__ == "__main__":
    build_tiles()
    build_player()
    build_slime()
    build_bat()
    build_npcs()
    build_ui()
    print("art →", OUT)
