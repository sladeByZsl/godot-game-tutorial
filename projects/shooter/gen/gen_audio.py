#!/usr/bin/env python3
"""程序化生成全部音效（wav）和背景音乐（ogg）。
运行：python3 gen/gen_audio.py（在 projects/shooter 下；需要 numpy，生成 ogg 需要 ffmpeg）。
每个音效 = 振荡器（波形）× 包络（ADSR）+ 可选的音高滑动 / 噪声 / 滤波。"""
import subprocess, wave
from pathlib import Path
import numpy as np

SR = 44100          # 采样率
OUT = Path("audio")
OUT.mkdir(exist_ok=True)
rng = np.random.default_rng(7)


#region adsr
def adsr(n, a, d, s, r, sr=SR):
    """ADSR 包络：起音 a 秒升到 1 → 衰减 d 秒降到持续电平 s → 保持 → 最后 r 秒释放到 0。
    n 是总采样数；返回长度为 n 的增益曲线。"""
    A, D, R = int(a * sr), int(d * sr), int(r * sr)
    S = max(0, n - A - D - R)                       # 持续段占剩下的时间
    env = np.concatenate([
        np.linspace(0, 1, A, endpoint=False),        # Attack
        np.linspace(1, s, D, endpoint=False),        # Decay
        np.full(S, s),                               # Sustain
        np.linspace(s, 0, R),                        # Release
    ])
    return np.pad(env, (0, max(0, n - len(env))))[:n]
#endregion


#region osc
def osc(kind, freq, n, sr=SR):
    """振荡器。freq 可以是常数，也可以是逐采样的数组（用来做音高滑动）。
    相位 = 频率的累加，所以变频时波形是连续的，不会"咔哒"响。"""
    f = np.broadcast_to(np.asarray(freq, dtype=float), (n,))
    phase = np.cumsum(f / sr) % 1.0
    if kind == "sine":
        return np.sin(2 * np.pi * phase)
    if kind == "square":
        return np.where(phase < 0.5, 1.0, -1.0)
    if kind == "saw":
        return 2 * phase - 1
    if kind == "triangle":
        return 1 - 4 * np.abs(phase - 0.5)
    if kind == "noise":
        return rng.uniform(-1, 1, n)
    raise ValueError(kind)
#endregion


def lowpass(x, cutoff, sr=SR):
    """一阶低通（cutoff 可以是数组，做"扫频"）。"""
    c = np.broadcast_to(np.asarray(cutoff, dtype=float), x.shape)
    alpha = 1 - np.exp(-2 * np.pi * c / sr)
    y = np.empty_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc += alpha[i] * (x[i] - acc)
        y[i] = acc
    return y


def sweep(f0, f1, n, curve=1.0):
    """从 f0 滑到 f1 的频率曲线（指数插值听起来更自然）。"""
    t = np.linspace(0, 1, n) ** curve
    return f0 * (f1 / f0) ** t


def save_wav(name, x, gain=0.8):
    x = np.clip(x / max(1e-9, np.max(np.abs(x))) * gain, -1, 1)
    data = (x * 32767).astype("<i2")
    with wave.open(str(OUT / f"{name}.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())
    print(f"{name}.wav  {len(x) / SR:.2f}s")


def sec(t):
    return int(t * SR)


#region sfx
def make_shoot():
    n = sec(0.09)
    tone = osc("square", sweep(1400, 520, n, 0.6), n) * 0.5 + osc("noise", 0, n) * 0.15
    return tone * adsr(n, 0.002, 0.04, 0.25, 0.04)


def make_explosion(length=0.55, low=55):
    n = sec(length)
    noise = lowpass(osc("noise", 0, n), sweep(5000, 180, n, 0.5))
    thump = osc("sine", sweep(160, low, n, 0.4), n)
    return (noise * 1.2 + thump * 0.9) * adsr(n, 0.003, length * 0.35, 0.35, length * 0.6)


def make_pickup():
    notes = [523.25, 659.25, 783.99, 1046.5]          # C5 E5 G5 C6 琶音
    parts = []
    for f in notes:
        n = sec(0.065)
        parts.append((osc("square", f, n) * 0.4 + osc("sine", f * 2, n) * 0.3) * adsr(n, 0.002, 0.03, 0.6, 0.02))
    return np.concatenate(parts)


def make_hurt():
    n = sec(0.42)
    tone = osc("saw", sweep(520, 70, n, 0.7), n) * 0.7 + osc("noise", 0, n) * 0.25
    return lowpass(tone, 2400) * adsr(n, 0.004, 0.12, 0.5, 0.25)


def make_enemy_shot():
    n = sec(0.07)
    return osc("triangle", sweep(900, 600, n), n) * adsr(n, 0.002, 0.03, 0.3, 0.03)


def make_ui_move():
    n = sec(0.035)
    return osc("square", 1200, n) * adsr(n, 0.001, 0.015, 0.2, 0.015)


def make_ui_ok():
    a, b = sec(0.06), sec(0.11)
    return np.concatenate([osc("square", 880, a) * adsr(a, 0.001, 0.02, 0.6, 0.02),
                           osc("square", 1320, b) * adsr(b, 0.001, 0.03, 0.5, 0.07)])
#endregion


# ---------------------------------------------------------------- 背景音乐
BPM = 140
BEAT = 60 / BPM
STEP = BEAT / 4                       # 16 分音符
CHORDS = [  # 每小节一个和弦（A 小调 i–VI–III–VII），根音频率 + 三个和弦音
    (110.00, [440.00, 523.25, 659.25]),   # Am
    (87.31, [349.23, 440.00, 523.25]),    # F
    (130.81, [392.00, 523.25, 659.25]),   # C
    (98.00, [392.00, 493.88, 587.33]),    # G
]


def place(buf, start, x):
    end = min(len(buf), start + len(x))
    buf[start:end] += x[:end - start]
    if start + len(x) > len(buf):          # 尾巴绕回开头，循环时无缝
        rest = x[end - start:]
        buf[:len(rest)] += rest


def make_bgm(bars=8):
    total = sec(bars * 4 * BEAT)
    L = np.zeros(total)
    R = np.zeros(total)
    for bar in range(bars):
        root, chord = CHORDS[bar % 4]
        t0 = bar * 4 * BEAT
        for step in range(16):
            t = t0 + step * STEP
            s = sec(t)
            # 低音：八分音符跳八度
            if step % 2 == 0:
                n = sec(STEP * 1.8)
                f = root * (2 if step % 4 == 2 else 1)
                b = lowpass(osc("saw", f, n), 900) * adsr(n, 0.004, 0.08, 0.5, 0.06) * 0.55
                place(L, s, b); place(R, s, b)
            # 琶音：十六分音符在和弦音里循环，左右声道交替
            n = sec(STEP * 0.9)
            f = chord[step % 3] * (2 if (step // 3) % 2 and bar >= 4 else 1)
            a = osc("square", f, n) * adsr(n, 0.002, 0.05, 0.25, 0.04) * 0.16
            if step % 2:
                place(L, s, a * 0.4); place(R, s, a)
            else:
                place(L, s, a); place(R, s, a * 0.4)
            # 鼓：底鼓 1、3 拍，军鼓 2、4 拍，踩镲每个八分音符
            if step % 8 == 0:
                n = sec(0.25)
                k = osc("sine", sweep(150, 42, n, 0.3), n) * adsr(n, 0.001, 0.1, 0.3, 0.12) * 0.9
                place(L, s, k); place(R, s, k)
            if step % 8 == 4:
                n = sec(0.18)
                sn = lowpass(osc("noise", 0, n), 4000) * adsr(n, 0.001, 0.06, 0.2, 0.1) * 0.45
                place(L, s, sn); place(R, s, sn)
            if step % 2 == 0:
                n = sec(0.04)
                nz = osc("noise", 0, n)
                h = (nz - lowpass(nz, 6000)) * adsr(n, 0.001, 0.02, 0.1, 0.015) * 0.18   # 噪声减去低频 = 高通
                place(L, s, h * 0.7); place(R, s, h)
    st = np.stack([L, R], 1)
    st = st / np.max(np.abs(st)) * 0.8
    tmp = OUT / "_bgm.wav"
    with wave.open(str(tmp), "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((st * 32767).astype("<i2").tobytes())
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(tmp), "-c:a", "libvorbis", "-q:a", "3",
                    str(OUT / "bgm.ogg")], check=True)
    tmp.unlink()
    print(f"bgm.ogg  {total / SR:.2f}s  {(OUT / 'bgm.ogg').stat().st_size // 1024} KB")


if __name__ == "__main__":
    save_wav("shoot", make_shoot(), 0.5)
    save_wav("explosion", make_explosion(), 0.9)
    save_wav("big_explosion", make_explosion(1.4, 35), 1.0)
    save_wav("pickup", make_pickup(), 0.6)
    save_wav("hurt", make_hurt(), 0.85)
    save_wav("enemy_shot", make_enemy_shot(), 0.35)
    save_wav("ui_move", make_ui_move(), 0.4)
    save_wav("ui_ok", make_ui_ok(), 0.5)
    make_bgm()
