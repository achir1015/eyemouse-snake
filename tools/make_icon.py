"""產生程式圖示：icon.png（1024）、platform/icon_*.png、platform/icon.ico、docs/icon.png
資料助秘系列的深藍到青綠圓角方塊；背景是彎曲的 3D 空間經緯網格，中間一條立體綠蛇盤旋、
右上角紅蘋果與藍金寶石，上方「貪吃蛇」標題列，左下角「資料助秘」標籤，右下角眼睛徽章（眼動鼠）。
用法：python -I tools/make_icon.py
"""
import math
import os

from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
S = 1024


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(len(a)))


def font(size):
    for p in [os.path.join(HERE, "assets", "fonts", "NotoSansTC.ttf")]:
        try:
            f = ImageFont.truetype(p, size)
            try:
                f.set_variation_by_name("Black")
            except Exception:
                pass
            return f
        except Exception:
            pass
    return ImageFont.load_default()


def main():
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    grad = Image.new("RGBA", (S, S))
    gd = ImageDraw.Draw(grad)
    c1, c2 = (15, 60, 110), (14, 150, 120)
    for y in range(S):
        gd.line([(0, y), (S, y)], fill=lerp(c1, c2, y / S) + (255,))
    gl = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    gd = ImageDraw.Draw(gl)
    # 彎曲空間：球面經緯線（對稱）
    cx, cy, R = 512, 560, 430
    for k in range(-5, 6):
        a = k / 6 * math.pi / 2
        rx = abs(R * math.cos(a)) if k else R
        gd.ellipse([cx - R * math.cos(a) * 0 - rx, cy - R, cx + rx, cy + R], outline=(120, 220, 230, 46), width=3)
        yy = cy + R * math.sin(a)
        ry = R * math.cos(a)
        gd.ellipse([cx - ry, yy - ry * 0.22, cx + ry, yy + ry * 0.22], outline=(120, 220, 230, 46), width=3)
    # 星點
    import random
    rnd = random.Random(3)
    for _ in range(90):
        x, y = rnd.uniform(60, 964), rnd.uniform(60, 964)
        r = rnd.choice([2, 2, 3, 4])
        gd.ellipse([x - r, y - r, x + r, y + r], fill=(220, 245, 255, rnd.randint(90, 200)))
    grad = Image.alpha_composite(grad, gl)
    mask = Image.new("L", (S, S), 0)
    ImageDraw.Draw(mask).rounded_rectangle([40, 40, S - 40, S - 40], radius=220, fill=255)
    img.paste(grad, (0, 0), mask)
    gloss = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    ImageDraw.Draw(gloss).ellipse([-200, -520, S + 200, 420], fill=(255, 255, 255, 30))
    img = Image.alpha_composite(img, Image.composite(gloss, Image.new("RGBA", (S, S)), mask))

    # 立體蛇：沿螺旋曲線畫圓（尾細頭粗），每顆圓用徑向漸層做出圓柱光影
    snake = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    sd = ImageDraw.Draw(snake)
    pts = []
    N = 260
    for i in range(N):
        u = i / (N - 1)
        ang = 3.6 * math.pi * (1 - u) + 0.2
        rad = 90 + 230 * u
        x = 500 + rad * math.cos(ang) * 1.0
        y = 600 + rad * math.sin(ang) * 0.62 - 120 * u
        pts.append((x, y, 18 + 50 * u))
    # 陰影
    sh = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    shd = ImageDraw.Draw(sh)
    for x, y, r in pts:
        shd.ellipse([x - r + 14, y - r + 30, x + r + 14, y + r + 30], fill=(0, 20, 30, 120))
    img = Image.alpha_composite(img, sh.filter(ImageFilter.GaussianBlur(18)))
    for i, (x, y, r) in enumerate(pts):
        band = (i // 9) % 2
        base = (40, 150, 70) if band == 0 else (28, 118, 58)
        for k in range(6, 0, -1):
            t = k / 6
            col = lerp((210, 255, 190), base, t ** 0.6)
            rr = r * t
            ox, oy = -r * 0.28 * (1 - t), -r * 0.34 * (1 - t)
            sd.ellipse([x - rr + ox, y - rr + oy, x + rr + ox, y + rr + oy], fill=col + (255,))
        if i % 9 == 0:
            sd.arc([x - r, y - r, x + r, y + r], 200, 340, fill=(12, 70, 40, 255), width=3)
    # 頭
    hx, hy, hr = pts[-1][0] + 40, pts[-1][1] - 18, 78
    sd.ellipse([hx - hr * 1.25, hy - hr, hx + hr * 1.25, hy + hr], fill=(36, 140, 66, 255), outline=(12, 70, 40, 255), width=4)
    sd.ellipse([hx - hr * 0.9, hy - hr * 0.75, hx + hr * 0.4, hy - hr * 0.05], fill=(120, 210, 120, 255))
    for ex in (-34, 34):
        sd.ellipse([hx + ex - 20, hy - 46, hx + ex + 20, hy - 6], fill=(255, 245, 180, 255), outline=(10, 40, 20, 255), width=3)
        sd.ellipse([hx + ex - 6, hy - 42, hx + ex + 6, hy - 10], fill=(10, 10, 10, 255))
        sd.ellipse([hx + ex - 9, hy - 40, hx + ex - 3, hy - 34], fill=(255, 255, 255, 255))
    tx, ty = hx + hr * 1.2, hy + 18
    sd.line([(tx - 10, ty), (tx + 46, ty + 6)], fill=(220, 40, 60, 255), width=8)
    sd.line([(tx + 46, ty + 6), (tx + 66, ty - 6)], fill=(220, 40, 60, 255), width=7)
    sd.line([(tx + 46, ty + 6), (tx + 64, ty + 22)], fill=(220, 40, 60, 255), width=7)
    img = Image.alpha_composite(img, snake)

    d = ImageDraw.Draw(img)
    # 蘋果（右上）
    ax, ay, ar = 812, 342, 66
    for k in range(8, 0, -1):
        t = k / 8
        d.ellipse([ax - ar * t - 10 * (1 - t), ay - ar * t * 0.92 - 14 * (1 - t), ax + ar * t - 10 * (1 - t), ay + ar * t * 0.92 - 14 * (1 - t)],
                  fill=lerp((255, 170, 160), (200, 20, 35), t ** 0.5) + (255,))
    d.line([(ax, ay - ar * 0.8), (ax + 8, ay - ar * 1.25)], fill=(90, 60, 30, 255), width=9)
    d.ellipse([ax + 8, ay - ar * 1.3, ax + 58, ay - ar * 1.05], fill=(60, 170, 60, 255))
    # 藍金寶石方塊（左側）
    gx, gy, gs = 190, 430, 46
    d.polygon([(gx, gy - gs), (gx + gs, gy - gs * 0.5), (gx, gy), (gx - gs, gy - gs * 0.5)], fill=(255, 220, 90, 255))
    d.polygon([(gx - gs, gy - gs * 0.5), (gx, gy), (gx, gy + gs), (gx - gs, gy + gs * 0.5)], fill=(40, 120, 230, 255))
    d.polygon([(gx + gs, gy - gs * 0.5), (gx, gy), (gx, gy + gs), (gx + gs, gy + gs * 0.5)], fill=(20, 80, 190, 255))
    glow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse([gx - 90, gy - 90, gx + 90, gy + 90], fill=(140, 200, 255, 70))
    img = Image.alpha_composite(img, glow.filter(ImageFilter.GaussianBlur(24)))
    d = ImageDraw.Draw(img)

    # 標題列「貪吃蛇」
    d.rounded_rectangle([210, 110, 650, 250], radius=50, fill=(30, 77, 140, 255), outline=(120, 170, 230, 255), width=6)
    d.text((430, 178), "貪吃蛇", font=font(96), fill=(255, 255, 255, 255), anchor="mm")
    # 左下「資料助秘」
    d.rounded_rectangle([110, 800, 450, 880], radius=40, fill=(255, 255, 255, 255))
    d.text((280, 838), "資料助秘", font=font(58), fill=(30, 70, 130, 255), anchor="mm")
    # 右下眼睛徽章（眼動鼠）
    bx, by = 820, 820
    d.ellipse([bx - 92, by - 92, bx + 92, by + 92], fill=(255, 210, 80, 255), outline=(255, 240, 180, 255), width=8)
    d.ellipse([bx - 64, by - 36, bx + 64, by + 36], fill=(255, 255, 255, 255), outline=(30, 50, 90, 255), width=6)
    d.ellipse([bx - 28, by - 28, bx + 28, by + 28], fill=(60, 90, 200, 255))
    d.ellipse([bx - 13, by - 13, bx + 13, by + 13], fill=(10, 10, 20, 255))
    d.ellipse([bx - 20, by - 22, bx - 8, by - 10], fill=(255, 255, 255, 255))

    out = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    out.paste(img, (0, 0), mask)
    out.save(os.path.join(HERE, "icon.png"))
    os.makedirs(os.path.join(HERE, "platform"), exist_ok=True)
    for s in [16, 32, 48, 57, 64, 128, 180, 192, 256, 512, 1024]:
        out.resize((s, s), Image.LANCZOS).save(os.path.join(HERE, "platform", f"icon_{s}.png"))
    out.save(os.path.join(HERE, "platform", "icon.ico"), sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])
    os.makedirs(os.path.join(HERE, "docs"), exist_ok=True)
    out.resize((256, 256), Image.LANCZOS).save(os.path.join(HERE, "docs", "icon.png"))
    print("icon ok")


if __name__ == "__main__":
    main()
