"""Procedural tower and wall sprites in the style of the painted hex tiles.

Style taken from the tile art (assets/third_party/hex_terrain_basic):
- muted, earthy palette (olive greens, grey-green stone, sandy browns)
- light from the top left, soft shading, painterly noise instead of hard edges
- 3/4 view: ground circles are squashed to 0.866, vertical faces to 0.5

Output (art space, same scale as a 256 px wide tile):
- assets/generated/towers/<type>_<biome>.png   256x320, anchor (128, 240) = tile centre
- assets/generated/towers/barrel_<biome>.png   128x128, pivot in the centre, pointing right

Run:  python tools/generate_tower_art.py        (needs Pillow and numpy)
"""

import os
import sys

import numpy as np
from PIL import Image

SS = 2                      # supersampling
W, H = 256 * SS, 320 * SS   # tower canvas
ANCHOR = (128 * SS, 240 * SS)
GROUND = 0.866              # squash of ground circles
WALL_Y = 0.5                # squash of vertical faces
LIGHT = np.array([-0.62, -0.5, 0.6])
LIGHT = LIGHT / np.linalg.norm(LIGHT)

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "generated", "towers")


def hexc(s):
    s = s.lstrip("#")
    return np.array([int(s[i:i + 2], 16) / 255.0 for i in (0, 2, 4)])


# Materials per biome: body, mortar/joints, top, accent, metal.
MATERIALS = {
    "neutral": dict(body="a28c5f", joint="6b5a3a", top="b59c6d", accent="7b6c48", metal="5b4a32", style="stone"),
    "mountain": dict(body="8f918a", joint="4b5046", top="b8b9ab", accent="eff4f7", metal="3a3d40", style="stone"),
    "forest": dict(body="6e4b2a", joint="3b2814", top="5d6023", accent="90953a", metal="7a5a2a", style="wood"),
    "plains": dict(body="d2c08c", joint="9a875a", top="e6d8ab", accent="c9a24a", metal="b8913c", style="stone"),
    "swamp": dict(body="4e4a3a", joint="26241b", top="5f6030", accent="a77be0", metal="2e2a24", style="stone"),
    "lake": dict(body="5f7f8c", joint="2f4652", top="8aa7b0", accent="67a7d0", metal="3d5560", style="stone"),
}


# --- helpers --------------------------------------------------------------

def noise(w, h, scale, seed, octaves=4):
    rng = np.random.default_rng(seed)
    total = np.zeros((h, w))
    amp, freq, norm = 1.0, 1.0, 0.0
    for _ in range(octaves):
        gw, gh = max(2, int(w / scale * freq)), max(2, int(h / scale * freq))
        grid = (rng.random((gh, gw)) * 255).astype(np.uint8)
        layer = np.array(Image.fromarray(grid).resize((w, h), Image.BICUBIC)) / 255.0
        total += layer * amp
        norm += amp
        amp *= 0.5
        freq *= 2.0
    return total / norm


def blank(w=W, h=H):
    return np.zeros((h, w, 4))


def put(canvas, mask, rgb, alpha=1.0):
    """Alpha-composite rgb (HxWx3 or 3) onto canvas where mask (0..1) is set."""
    a = np.clip(mask, 0, 1) * alpha
    rgb = np.broadcast_to(rgb, canvas.shape[:2] + (3,))
    out_a = a + canvas[..., 3] * (1 - a)
    safe = np.where(out_a > 0, out_a, 1)
    canvas[..., :3] = (rgb * a[..., None] + canvas[..., :3] * canvas[..., 3:4] * (1 - a[..., None])) / safe[..., None]
    canvas[..., 3] = out_a


def grid(w=W, h=H):
    return np.meshgrid(np.arange(w, dtype=float), np.arange(h, dtype=float))


def soft(mask, edge=1.2 * SS):
    """Turn a signed-distance-like field (>0 inside) into an antialiased mask."""
    return np.clip(mask / edge + 0.5, 0, 1)


def shade(base, brightness, tex, amount=0.18):
    """Colour from base, brightness (0..1.4) and a noise texture for painterly variation."""
    col = base[None, None, :] * brightness[..., None]
    col *= (1 - amount / 2 + amount * tex)[..., None]
    return np.clip(col, 0, 1)


def ground_shadow(canvas, cx, cy, rx):
    X, Y = grid(canvas.shape[1], canvas.shape[0])
    d = ((X - cx - rx * 0.12) / (rx * 1.15)) ** 2 + ((Y - cy - rx * 0.05) / (rx * 1.15 * GROUND)) ** 2
    put(canvas, np.clip(1 - d, 0, 1) ** 1.5, np.zeros(3), 0.45)


# --- shapes ---------------------------------------------------------------

def cylinder(canvas, cx, base_y, rx, height, mat, seed, top=True):
    """Upright cylinder in 3/4 view with stone courses or wooden planks."""
    X, Y = grid()
    ry = rx * GROUND
    h = height * WALL_Y
    ty = base_y - h
    u = (X - cx) / rx
    inside_u = np.clip(1 - u * u, 0, 1)
    bottom = base_y + ry * np.sqrt(inside_u)
    body = soft(np.minimum(np.minimum(rx - np.abs(X - cx), Y - ty), bottom - Y))
    nz = np.sqrt(inside_u)
    lit = np.clip(LIGHT[0] * u + LIGHT[2] * nz, 0, 1)
    bright = 0.42 + 0.7 * lit
    bright *= 1 - 0.35 * np.clip((Y - (base_y - 6 * SS)) / (12 * SS), 0, 1)   # ambient occlusion at the foot
    tex = noise(W, H, 18 * SS, seed)
    base = hexc(mat["body"])
    col = shade(base, bright, tex)
    v = Y - ty
    arc = np.arcsin(np.clip(u, -1, 1)) * rx
    joint = hexc(mat["joint"])
    if mat["style"] == "wood":
        plank = (arc + 400) % (9 * SS) < 1.6 * SS
        jmask = plank.astype(float)
        moss = (noise(W, H, 10 * SS, seed + 3) > 0.62) & (v > h * 0.45)
        col = np.where(moss[..., None], shade(hexc(mat["accent"]), bright, tex, 0.3), col)
    else:
        row_h = 11 * SS
        row = np.floor(v / row_h)
        course = (v % row_h) < 1.6 * SS
        brick = ((arc + row * 9 * SS + 400) % (19 * SS)) < 1.6 * SS
        jmask = (course | brick).astype(float)
    col = col * (1 - jmask[..., None]) + shade(joint, bright, tex)[...] * jmask[..., None]
    put(canvas, body, col)
    if top:
        top_mask = soft((1 - ((X - cx) / rx) ** 2 - ((Y - ty) / ry) ** 2) * rx * 0.5)
        tcol = shade(hexc(mat["top"]), 1.05 - 0.15 * (Y - ty + ry) / (2 * ry), noise(W, H, 12 * SS, seed + 1), 0.25)
        put(canvas, top_mask, tcol)
    return ty, ry


def merlons(canvas, cx, ty, rx, ry, mat, seed, count=10, size=9):
    """Crenellations around a rim; back ones first, then front ones."""
    angles = [2 * np.pi * k / count + 0.2 for k in range(count)]
    angles.sort(key=lambda a: np.sin(a))
    for a in angles:
        mx = cx + np.cos(a) * rx * 0.86
        my = ty + np.sin(a) * ry * 0.86
        block(canvas, mx, my, size * SS * 0.6, size * SS, mat, seed + int(a * 10), facing=np.cos(a))


def block(canvas, cx, base_y, half_w, height, mat, seed, facing=0.0):
    X, Y = grid()
    h = height * WALL_Y * 1.6
    ty = base_y - h
    m = soft(np.minimum(np.minimum(half_w - np.abs(X - cx), Y - ty), base_y - Y))
    bright = 0.75 - 0.25 * facing + 0.15 * np.clip((ty + 3 * SS - Y) / (3 * SS), -1, 1)
    col = shade(hexc(mat["body"]), np.full(X.shape, 1.0) * bright, noise(W, H, 8 * SS, seed), 0.2)
    cap = soft(np.minimum(np.minimum(half_w - np.abs(X - cx), Y - (ty - 2 * SS)), ty + 2.5 * SS - Y))
    put(canvas, m, col)
    put(canvas, cap, shade(hexc(mat["top"]), np.full(X.shape, 1.1), noise(W, H, 6 * SS, seed + 1), 0.2))


def dome(canvas, cx, cy, r, color, seed):
    X, Y = grid()
    dx, dy = (X - cx) / r, (Y - cy) / (r * 0.9)
    d2 = dx * dx + dy * dy
    m = soft((1 - d2) * r * 0.5)
    nz = np.sqrt(np.clip(1 - d2, 0, 1))
    lit = np.clip(LIGHT[0] * dx + LIGHT[1] * dy + LIGHT[2] * nz, 0, 1)
    col = shade(color, 0.35 + 0.85 * lit, noise(W, H, 6 * SS, seed), 0.12)
    spec = np.clip((lit - 0.85) * 6, 0, 1)[..., None]
    col = col * (1 - spec * 0.6) + spec * 0.6
    put(canvas, m, col)


def leafy_crown(canvas, cx, cy, r, mat, seed):
    """Clumps of leaves like the painted trees (Forest roofs and hedges)."""
    rng = np.random.default_rng(seed)
    dark, mid, light = hexc("38411a"), hexc(mat["top"]), hexc(mat["accent"])
    for i in range(26):
        a, d = rng.random() * 2 * np.pi, np.sqrt(rng.random()) * r
        x, y = cx + np.cos(a) * d, cy + np.sin(a) * d * GROUND
        rr = r * (0.28 + rng.random() * 0.18)
        dome(canvas, x, y, rr, dark if i < 8 else (mid if i < 20 else light), seed + i)


def hex_rampart(canvas, mat, seed, scale=0.86, height=26):
    """Low hexagonal fortification filling the tile: the Wall tower."""
    X, Y = grid()
    cx, cy = ANCHOR
    rx, ry = 128 * SS * scale, 128 * SS * scale    # art hex: 256 wide, 256 tall
    h = height * SS * WALL_Y * 1.6
    top = [(cx, cy - ry - h), (cx + rx, cy - ry / 2 - h), (cx + rx, cy + ry / 2 - h),
           (cx, cy + ry - h), (cx - rx, cy + ry / 2 - h), (cx - rx, cy - ry / 2 - h)]
    tex = noise(W, H, 14 * SS, seed)

    def poly_mask(pts):
        from PIL import ImageDraw
        img = Image.new("L", (W, H), 0)
        ImageDraw.Draw(img).polygon([(float(x), float(y)) for x, y in pts], fill=255)
        return np.array(img) / 255.0

    # Two visible side faces (down-left lit more than down-right), then the top.
    faces = [((top[3], top[4]), 0.78), ((top[2], top[3]), 0.58)]
    for (a, b), bright in faces:
        quad = [a, b, (b[0], b[1] + h), (a[0], a[1] + h)]
        m = poly_mask(quad)
        v = Y - np.minimum(a[1], b[1])
        col = shade(hexc(mat["body"]), np.full(X.shape, bright), tex)
        if mat["style"] == "wood":
            joints = ((X + 400) % (8 * SS) < 1.5 * SS)
        else:
            joints = ((v % (10 * SS)) < 1.5 * SS) | (((X + np.floor(v / (10 * SS)) * 9 * SS + 400) % (18 * SS)) < 1.5 * SS)
        col = np.where(joints[..., None], shade(hexc(mat["joint"]), np.full(X.shape, bright), tex), col)
        put(canvas, m, col)
    top_mask = poly_mask(top)
    put(canvas, top_mask, shade(hexc(mat["top"]), 1.0 - 0.12 * (Y - top[0][1]) / (2 * ry), noise(W, H, 10 * SS, seed + 2), 0.28))
    # Inner courtyard a bit lower and darker, so it reads as a rampart, not a plinth.
    inner = [(cx + (x - cx) * 0.72, cy - h + (y - cy + h) * 0.72) for x, y in top]
    put(canvas, poly_mask(inner), shade(hexc(mat["top"]) * 0.78, np.full(X.shape, 1.0), noise(W, H, 9 * SS, seed + 4), 0.3))
    return top


# --- assets ---------------------------------------------------------------

def attack_tower(biome):
    mat = MATERIALS[biome]
    c = blank()
    cx, by = ANCHOR
    seed = hash(biome) % 10000
    ground_shadow(c, cx, by, 62 * SS)
    ty, ry = cylinder(c, cx, by, 46 * SS, 70 * SS, mat, seed)
    if mat["style"] == "wood":
        leafy_crown(c, cx, ty - 4 * SS, 52 * SS, mat, seed + 5)
        dome(c, cx, ty - 10 * SS, 18 * SS, hexc(mat["metal"]), seed + 7)
    else:
        merlons(c, cx, ty, 46 * SS, ry, mat, seed)
        dome(c, cx, ty - 6 * SS, 20 * SS, hexc(mat["metal"]), seed + 7)
        if biome == "mountain":
            snow = noise(W, H, 6 * SS, seed + 9)
            X, Y = grid()
            cap = ((X - cx) / (48 * SS)) ** 2 + ((Y - ty) / (ry * 1.05)) ** 2 < 1
            put(c, (cap & (snow > 0.6)).astype(float), hexc(mat["accent"]), 0.85)
        if biome == "swamp":
            X, Y = grid()
            glow = np.clip(1 - (((X - cx) / (30 * SS)) ** 2 + ((Y - ty + 8 * SS) / (24 * SS)) ** 2), 0, 1)
            put(c, glow ** 2, hexc(mat["accent"]), 0.5)
    return c


def wall_tower(biome):
    mat = MATERIALS[biome]
    c = blank()
    seed = hash(biome) % 10000 + 50
    cx, cy = ANCHOR
    ground_shadow(c, cx, cy, 110 * SS)
    top = hex_rampart(c, mat, seed)
    if mat["style"] == "wood":
        # Hedge of leaf clumps along the rim.
        for i, (x, y) in enumerate(top):
            nx, ny = top[(i + 1) % 6]
            for t in np.linspace(0, 1, 4, endpoint=False):
                leafy_crown(c, x + (nx - x) * t, y + (ny - y) * t - 6 * SS, 16 * SS, mat, seed + i * 10 + int(t * 7))
    else:
        rim = sorted(range(6), key=lambda i: top[i][1])
        for i in rim:
            x, y = top[i]
            nx, ny = top[(i + 1) % 6]
            for t in np.linspace(0, 1, 4, endpoint=False):
                block(c, x + (nx - x) * t, y + (ny - y) * t, 6 * SS, 8, mat, seed + i * 10 + int(t * 9))
    return c


def barrel(biome):
    mat = MATERIALS[biome]
    size = 128 * SS
    c = np.zeros((size, size, 4))
    X, Y = np.meshgrid(np.arange(size, dtype=float), np.arange(size, dtype=float))
    cx = cy = size / 2
    length, r = 52 * SS, 7 * SS
    m = soft(np.minimum(np.minimum(X - cx, cx + length - X), r - np.abs(Y - cy)))
    ny = (Y - cy) / r
    lit = np.clip(-LIGHT[1] * -ny + LIGHT[2] * np.sqrt(np.clip(1 - ny * ny, 0, 1)), 0, 1)
    metal = hexc(mat["metal"])
    col = np.clip(metal[None, None, :] * (0.4 + 0.9 * lit)[..., None], 0, 1)
    band = (np.abs(X - (cx + length - 5 * SS)) < 3 * SS)
    col = np.where(band[..., None], np.clip(col * 1.35, 0, 1), col)
    put(c, m, col)
    return c


# --- connected walls --------------------------------------------------------
# Ground space: regular hex grid, neighbour centres 256 apart. Screen = (x, y * GROUND).
# Direction order matches HexMath.DIRECTIONS: E, NE, NW, W, SW, SE.
DIRECTIONS = [(1.0, 0.0), (0.5, -0.866), (-0.5, -0.866), (-1.0, 0.0), (-0.5, 0.866), (0.5, 0.866)]
GROUND_LIGHT = np.array([-0.62, -0.5])  # horizontal part of the light (from the top left)


def poly_mask(pts, w=W, h=H):
    from PIL import ImageDraw
    img = Image.new("L", (w, h), 0)
    ImageDraw.Draw(img).polygon([(float(x), float(y)) for x, y in pts], fill=255)
    return np.array(img) / 255.0


def to_screen(gx, gy, lift=0.0):
    """Ground point (relative to the tile centre) plus height -> canvas pixel."""
    return (ANCHOR[0] + gx, ANCHOR[1] + gy * GROUND - lift * WALL_Y)


def box(canvas, center, axis, length, thickness, height, mat, seed, base_lift=0.0, courses=True):
    """Oriented box standing on the ground: visible side faces and the top, shaded and textured."""
    ax = np.array(axis) / np.linalg.norm(axis)
    bx = np.array([-ax[1], ax[0]])
    c = np.array(center)
    corners = [c + ax * length + bx * thickness, c - ax * length + bx * thickness,
               c - ax * length - bx * thickness, c + ax * length - bx * thickness]
    X, Y = grid()
    tex = noise(W, H, 12 * SS, seed)
    body, joint = hexc(mat["body"]), hexc(mat["joint"])
    # Side faces whose outward normal points toward the viewer (down the screen), back to front.
    faces = []
    for i in range(4):
        p, q = corners[i], corners[(i + 1) % 4]
        mid = (p + q) / 2 - c
        n = mid / np.linalg.norm(mid)
        if n[1] > 0.01:
            faces.append((p, q, n))
    faces.sort(key=lambda f: (f[0][1] + f[1][1]))
    for p, q, n in faces:
        quad = [to_screen(*p, base_lift), to_screen(*q, base_lift),
                to_screen(*q, base_lift + height), to_screen(*p, base_lift + height)]
        m = poly_mask(quad)
        bright = max(0.52, 0.66 + 0.45 * float(np.dot(n, GROUND_LIGHT)))
        col = shade(body, np.full(X.shape, bright), tex, 0.22)
        if courses:
            top_y = to_screen(*p, base_lift + height)[1]
            v = Y - top_y
            along = (X - to_screen(*p)[0]) * (1 if abs(q[0] - p[0]) > 1 else 0) + (Y * 0)
            course = (v % (9 * SS)) < 1.4 * SS
            row = np.floor(v / (9 * SS))
            brick = ((along + row * 8 * SS + 4000) % (16 * SS)) < 1.4 * SS
            jm = (course | (brick & (abs(q[0] - p[0]) > 1))).astype(float)
            col = col * (1 - jm[..., None]) + shade(joint, np.full(X.shape, bright), tex) * jm[..., None]
        # Darker foot where the wall meets the ground.
        foot = np.clip((Y - (max(quad[0][1], quad[1][1]) - 7 * SS)) / (7 * SS), 0, 1)
        col = col * (1 - 0.3 * foot[..., None])
        put(canvas, m, col)
    top = [to_screen(*k, base_lift + height) for k in corners]
    put(canvas, poly_mask(top), shade(hexc(mat["top"]), np.full(X.shape, 1.02), noise(W, H, 8 * SS, seed + 1), 0.22))


def wall_crenels(canvas, start, end, mat, seed, height, thickness, spacing=22 * SS):
    """Merlons along the top of a straight wall from `start` to `end` (ground)."""
    s, e = np.array(start), np.array(end)
    d = e - s
    n = max(1, int(np.linalg.norm(d) / spacing))
    axis = d / np.linalg.norm(d)
    pts = [s + d * (k + 0.5) / n for k in range(n)]
    pts.sort(key=lambda p: p[1])
    for k, p in enumerate(pts):
        box(canvas, p, axis, 6.5 * SS, thickness, 14 * SS, mat, seed + k, base_lift=height, courses=False)


WALL_HEIGHT = 62 * SS
WALL_THICK = 19 * SS
POST_RADIUS = 38 * SS


def wall_segment(direction, mat, seed):
    """Half a wall from the tile centre to the edge toward `direction`."""
    c = blank()
    d = np.array(DIRECTIONS[direction])
    start, end = d * POST_RADIUS * 0.6, d * 128 * SS
    center = (start + end) / 2
    length = np.linalg.norm(end - start) / 2
    # Soft contact shadow on the ground.
    X, Y = grid()
    sx, sy = to_screen(*(center + np.array([6 * SS, 4 * SS])))
    shadow = poly_mask([to_screen(*(start + np.array([-d[1], d[0]]) * WALL_THICK * 1.8)),
                        to_screen(*(end + np.array([-d[1], d[0]]) * WALL_THICK * 1.8)),
                        to_screen(*(end - np.array([-d[1], d[0]]) * WALL_THICK * 1.8)),
                        to_screen(*(start - np.array([-d[1], d[0]]) * WALL_THICK * 1.8))])
    put(c, shadow, np.zeros(3), 0.25)
    box(c, center, d, length, WALL_THICK, WALL_HEIGHT, mat, seed)
    wall_crenels(c, start, end, mat, seed + 20, WALL_HEIGHT, WALL_THICK)
    return c


def wall_post(mat, seed):
    """Round wall tower in the middle of the tile."""
    c = blank()
    cx, by = ANCHOR
    ground_shadow(c, cx, by, POST_RADIUS * 1.35)
    ty, ry = cylinder(c, cx, by, POST_RADIUS, WALL_HEIGHT * 1.6, mat, seed)
    count = 8
    angles = sorted([2 * np.pi * k / count + 0.3 for k in range(count)], key=np.sin)
    for k, a in enumerate(angles):
        gx, gy = np.cos(a) * POST_RADIUS * 0.82, np.sin(a) * POST_RADIUS * 0.82
        box(c, (gx, gy), (-np.sin(a), np.cos(a)), 7 * SS, 5.5 * SS, 14 * SS, mat, seed + k,
            base_lift=WALL_HEIGHT * 1.6, courses=False)
    return c


def walls(biome):
    mat = MATERIALS[biome]
    seed = 4242
    save(wall_post(mat, seed), f"wall_{biome}_post.png", (256, 320))
    for i in range(6):
        save(wall_segment(i, mat, seed + 100 * (i + 1)), f"wall_{biome}_{i}.png", (256, 320))


def save(canvas, name, size):
    img = Image.fromarray((np.clip(canvas, 0, 1) * 255).astype(np.uint8), "RGBA")
    img.resize(size, Image.LANCZOS).save(os.path.join(OUT, name))


def main(biomes):
    os.makedirs(OUT, exist_ok=True)
    for biome in biomes:
        save(attack_tower(biome), f"attack_{biome}.png", (256, 320))
        save(wall_tower(biome), f"wall_{biome}.png", (256, 320))
        save(barrel(biome), f"barrel_{biome}.png", (128, 128))
        print("generated", biome)


if __name__ == "__main__":
    args = sys.argv[1:]
    if args and args[0] == "walls":
        os.makedirs(OUT, exist_ok=True)
        for b in args[1:] or ["neutral"]:
            walls(b)
            print("walls", b)
    else:
        main(args or list(MATERIALS))
