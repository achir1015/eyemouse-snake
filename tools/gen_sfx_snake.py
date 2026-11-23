"""貪吃蛇專用音效（原創合成）→ assets/sfx/*.wav
用法：python -I tools/gen_sfx_snake.py
eat 咬蘋果、gem 寶石方塊、hurt 咬到尾巴、heal 恢復生命、ring 穿越光環、wall 碰到邊界、
start 開始、over 遊戲結束、hum 量子嗡鳴（循環）、space 太空底噪（循環）、garden 花園蟲鳴微風（循環）
"""
import os
import wave

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "sfx")
SR = 22050
rng = np.random.default_rng(11)


def save(name, x, loop=False):
    x = np.asarray(x, dtype=np.float64)
    if loop:
        n = int(SR * 0.25)
        head = x[:n].copy()
        x = x[n:]
        x[-n:] = x[-n:] * np.linspace(1, 0, n) + head * np.linspace(0, 1, n)
    peak = np.max(np.abs(x)) or 1.0
    x = x / peak * 0.85
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((x * 32767).astype(np.int16).tobytes())


def t(sec):
    return np.arange(int(SR * sec)) / SR


def env(n, a=0.005, r=0.1):
    e = np.ones(n)
    na, nr = int(SR * a), int(SR * r)
    if na:
        e[:na] = np.linspace(0, 1, na)
    if nr:
        e[-nr:] *= np.linspace(1, 0, nr)
    return e


def lp(x, k):
    return np.convolve(x, np.ones(k) / k, mode="same")


def noise(sec):
    return rng.uniform(-1, 1, int(SR * sec))


def tone(f, sec, decay=6.0):
    tt = t(sec)
    return np.sin(2 * np.pi * f * tt) * np.exp(-tt * decay)


os.makedirs(OUT, exist_ok=True)

# 咬蘋果：兩下清脆的咔滋（帶通雜訊＋短促下滑音）
x = np.zeros(int(SR * 0.35))
for k, off in enumerate([0.0, 0.09]):
    n = noise(0.12) * np.exp(-t(0.12) * 38)
    n = n - lp(n, 6)
    s = int(SR * off)
    x[s:s + len(n)] += n * (1.0 if k == 0 else 0.7)
tt = t(0.35)
x += 0.35 * np.sin(2 * np.pi * (900 - 500 * tt) * tt) * np.exp(-tt * 14)
save("eat", x)

# 寶石方塊：上行琶音＋泛音閃爍
x = np.zeros(int(SR * 1.2))
for k, f in enumerate([659.3, 830.6, 987.8, 1318.5, 1661.2]):
    s = int(SR * k * 0.07)
    y = tone(f, 1.2 - k * 0.07, 3.5) + 0.4 * tone(f * 2.01, 1.2 - k * 0.07, 6)
    x[s:s + len(y)] += y
save("gem", x)

# 恢復生命：溫暖和弦漸強
tt = t(1.6)
x = sum(np.sin(2 * np.pi * f * tt) for f in [261.6, 329.6, 392.0, 523.3]) * np.minimum(tt * 2.5, 1) * np.exp(-np.maximum(tt - 0.8, 0) * 4)
save("heal", x)

# 咬到尾巴：低沉撞擊＋下滑
tt = t(0.7)
x = np.sin(2 * np.pi * (220 * np.exp(-tt * 3)) * tt) * np.exp(-tt * 5) + 0.6 * lp(noise(0.7), 8) * np.exp(-tt * 12)
save("hurt", x)

# 碰到邊界：電場嗡聲
tt = t(0.5)
x = (np.sign(np.sin(2 * np.pi * 110 * tt)) * 0.4 + np.sin(2 * np.pi * 55 * tt)) * np.exp(-tt * 6)
save("wall", lp(x, 4))

# 穿越光環：呼嘯
tt = t(0.8)
n = noise(0.8)
x = (lp(n, 3) - lp(n, 20)) * np.sin(np.pi * tt / 0.8) ** 2 + 0.3 * np.sin(2 * np.pi * (400 + 900 * tt) * tt) * np.sin(np.pi * tt / 0.8)
save("ring", x)

# 開始：上行三音
x = np.concatenate([tone(f, 0.18, 8) for f in [392, 523.3]] + [tone(784, 0.6, 4)])
save("start", x)

# 遊戲結束：下行
x = np.concatenate([tone(f, 0.3, 5) for f in [523.3, 440, 349.2]] + [tone(261.6, 0.9, 3)])
save("over", x)

# 量子嗡鳴（循環）：慢速拍頻的和聲
tt = t(8.0)
x = sum(np.sin(2 * np.pi * f * tt) * (0.6 + 0.4 * np.sin(2 * np.pi * 0.25 * tt + k)) for k, f in enumerate([55, 82.5, 110.25, 165]))
x += 0.15 * lp(noise(8.0), 30)
save("hum", x, loop=True)

# 太空底噪（循環）
x = lp(noise(8.0), 60) * (0.7 + 0.3 * np.sin(2 * np.pi * 0.125 * tt)) + 0.2 * np.sin(2 * np.pi * 41.2 * tt)
save("space", x, loop=True)

# 花園微風與蟲鳴（循環）
x = lp(noise(8.0), 40) * (0.6 + 0.4 * np.sin(2 * np.pi * 0.25 * tt))
for k in range(6):
    s = rng.uniform(0, 7.0)
    m = (tt > s) & (tt < s + 0.9)
    x += 0.12 * m * np.sin(2 * np.pi * 4200 * tt) * (np.sin(2 * np.pi * 28 * tt) > 0.2)
save("garden", x, loop=True)
print("ok")
