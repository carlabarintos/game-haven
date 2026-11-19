# Builds Yuzu Springs in Blender and renders the painted layers the app swaps in for its stand-ins.
# Run inside Blender:  exec(open("<repo>/ios/art/village.py").read()); build(); render_all()
# Every layer is a transparent PNG the size of the whole 390×844 board at @3x, so it lines up with no code.
import bpy, bmesh, math, random
from mathutils import Vector

REPO = "/Volumes/NV3/carl/repositories/game-haven"
OUT = REPO + "/ios/GameHaven/Village/Art"
K = 14.142  # board points per world unit on screen (1 world unit = 10 points along an iso axis)


def W(bx, by, z=0.0):
    """A board point (y down) on the ground to world. The camera makes +Y run up-right and -X up-left, 2:1."""
    u, v = (bx - 195) / 10, (422 - by) / 5
    return Vector(((u - v) / 2, (u + v) / 2, z))


def H(h):
    """Board points of height to world Z."""
    return h / 12.247


# MARK: Scene

def scene():
    sc = bpy.data.scenes.get("YuzuSprings") or bpy.data.scenes.new("YuzuSprings")
    bpy.context.window.scene = sc
    for o in list(sc.objects):
        bpy.data.objects.remove(o)
    for c in list(sc.collection.children):
        bpy.data.collections.remove(c)
    sc.render.engine = "CYCLES"
    sc.cycles.samples = 64
    sc.cycles.use_denoising = True
    try:
        bpy.context.preferences.addons["cycles"].preferences.compute_device_type = "METAL"
        sc.cycles.device = "GPU"
    except Exception:
        pass
    sc.render.resolution_x, sc.render.resolution_y = 1170, 2532
    sc.render.film_transparent = True
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGBA"
    sc.view_settings.view_transform = "Standard"
    sc.view_settings.look = "None"

    cam = bpy.data.objects.new("Camera", bpy.data.cameras.new("Camera"))
    cam.data.type = "ORTHO"
    cam.data.sensor_fit = "VERTICAL"
    cam.data.ortho_scale = 844 / K
    cam.data.clip_end = 400
    cam.rotation_euler = (math.radians(60), 0, math.radians(45))
    cam.location = Vector((0.6124, -0.6124, 0.5)) * 120
    sc.collection.objects.link(cam)
    sc.camera = cam

    # Soft afternoon sun from the upper left, so shadows fall down-right like the stand-ins'.
    sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
    sun.data.energy = 3.2
    sun.data.angle = math.radians(12)
    sun.data.color = rgb(0xFFF1DC)
    sun.rotation_euler = (math.radians(50), 0, math.radians(-120))
    sc.collection.objects.link(sun)

    world = bpy.data.worlds.get("Sky") or bpy.data.worlds.new("Sky")
    world.use_nodes = True
    bg = next(n for n in world.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs[0].default_value = (*rgb(0xCFE3EC), 1)
    bg.inputs[1].default_value = 0.9
    sc.world = world
    return sc


def layer(name):
    c = bpy.data.collections.new(name)
    bpy.context.scene.collection.children.link(c)
    return c


# MARK: Materials

def rgb(hex):
    def lin(c):
        c /= 255
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
    return (lin(hex >> 16 & 255), lin(hex >> 8 & 255), lin(hex & 255))


def mat(name, a, b=None, rough=0.9, scale=4.0, emit=0.0, bands=0.0):
    """Matte paint with a soft brushy mottle between two shades; `bands` adds roof-tile rows."""
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.inputs["Roughness"].default_value = rough
    nt.links.new(bsdf.outputs[0], out.inputs[0])
    b = b if b is not None else shade(a, 0.85)
    noise = nt.nodes.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = scale
    noise.inputs["Detail"].default_value = 6
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].position, ramp.color_ramp.elements[1].position = 0.35, 0.65
    ramp.color_ramp.elements[0].color = (*rgb(a), 1)
    ramp.color_ramp.elements[1].color = (*rgb(b), 1)
    nt.links.new(noise.outputs["Fac"], ramp.inputs["Fac"])
    color = ramp.outputs["Color"]
    if bands:
        wave = nt.nodes.new("ShaderNodeTexWave")
        wave.inputs["Scale"].default_value = bands
        mix = nt.nodes.new("ShaderNodeMix")
        mix.data_type = "RGBA"
        mix.blend_type = "MULTIPLY"
        mix.inputs["Factor"].default_value = 0.35
        nt.links.new(color, mix.inputs[6])
        nt.links.new(wave.outputs["Color"], mix.inputs[7])
        color = mix.outputs[2]
    nt.links.new(color, bsdf.inputs["Base Color"])
    if emit:
        nt.links.new(color, bsdf.inputs["Emission Color"])
        bsdf.inputs["Emission Strength"].default_value = emit
    return m


def shade(hex, f):
    return int((hex >> 16 & 255) * f) << 16 | int((hex >> 8 & 255) * f) << 8 | int((hex & 255) * f)


# MARK: Meshes

def mesh(name, verts, faces, material, coll, bevel=0.0, solid=0.0):
    me = bpy.data.meshes.new(name)
    me.from_pydata([tuple(v) for v in verts], [], faces)
    me.materials.append(material)
    for p in me.polygons:
        p.use_smooth = False
    o = bpy.data.objects.new(name, me)
    coll.objects.link(o)
    if solid:
        o.modifiers.new("solid", "SOLIDIFY").thickness = solid
    if bevel:
        bv = o.modifiers.new("bevel", "BEVEL")
        bv.width, bv.segments, bv.limit_method = bevel, 2, "ANGLE"
    return o


def box(name, lo, hi, material, coll, bevel=0.03):
    (x0, y0, z0), (x1, y1, z1) = lo, hi
    v = [(x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0), (x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1)]
    f = [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]
    return mesh(name, v, f, material, coll, bevel)


def blob(name, at, r, material, coll, squash=1.0, seed=0):
    """A soft, lumpy ball: bushes, rocks, foliage."""
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=3, radius=1)
    rnd = random.Random(seed)
    for v in bm.verts:
        n = 1 + 0.12 * math.sin(v.co.x * 5 + seed) * math.cos(v.co.y * 4 + seed) + rnd.uniform(-0.03, 0.03)
        v.co = Vector((v.co.x * r * n, v.co.y * r * n, v.co.z * r * n * squash))
    bm.to_mesh(me)
    bm.free()
    me.materials.append(material)
    for p in me.polygons:
        p.use_smooth = True
    o = bpy.data.objects.new(name, me)
    o.location = at
    coll.objects.link(o)
    return o


def cone(name, at, r, h, material, coll, sides=10):
    v = [(at.x + r * math.cos(a), at.y + r * math.sin(a), at.z) for a in (i * 2 * math.pi / sides for i in range(sides))]
    v.append((at.x, at.y, at.z + h))
    f = [(i, (i + 1) % sides, sides) for i in range(sides)] + [tuple(reversed(range(sides)))]
    return mesh(name, v, f, material, coll)


def disc(name, at, r, material, coll, z=0.02, sides=32):
    v = [(at.x + r * math.cos(a), at.y + r * math.sin(a), z) for a in (i * 2 * math.pi / sides for i in range(sides))]
    return mesh(name, v, [tuple(range(sides))], material, coll)


# MARK: Pieces

def house(id, x, y, a, b, h, r, roof, noren, coll, window=True):
    """Front corner (x, y) on the board, `a` points along +Y (up-right), `b` along -X (up-left), as the stand-in."""
    B = W(x, y)
    x1, y0 = B.x, B.y
    x0, y1 = x1 - b / 10, y0 + a / 10
    hz, rz = H(h), H(r)
    xm, o = (x0 + x1) / 2, 0.45
    plaster, wood = mat("plaster", 0xF3E7CF, 0xE6D5B5, scale=8), mat("timber", 0x5E3B26, 0x4A2E1E, scale=12)
    stone = mat("stone", 0x9C968A, 0x7E786E, scale=6)
    box(f"{id}-base", (x0 - 0.15, y0 - 0.15, 0), (x1 + 0.15, y1 + 0.15, 0.3), stone, coll)
    box(f"{id}-walls", (x0, y0, 0.3), (x1, y1, hz), plaster, coll, bevel=0.02)
    # Timber frame: corner posts and a beam under the eaves.
    for px, py in [(x0, y0), (x1, y0), (x1, y1), (x0, y1)]:
        box(f"{id}-post", (px - 0.13, py - 0.13, 0.3), (px + 0.13, py + 0.13, hz), wood, coll)
    box(f"{id}-beam", (x0 - 0.1, y0 - 0.1, hz - 0.3), (x1 + 0.1, y1 + 0.1, hz), wood, coll)
    box(f"{id}-sill", (x0 - 0.08, y0 - 0.08, 0.3), (x1 + 0.08, y1 + 0.08, 0.5), wood, coll)
    # Gable roof, ridge along Y, eaves past the walls.
    tiles = mat(f"roof-{id}", roof[1], roof[0], rough=0.6, scale=3, bands=6)
    ze = hz - 0.25
    zr = hz + rz
    for side in (x0 - o, x1 + o):
        mesh(f"{id}-roof", [(xm, y0 - o, zr), (xm, y1 + o, zr), (side, y1 + o, ze), (side, y0 - o, ze)], [(0, 1, 2, 3)], tiles, coll, solid=0.22, bevel=0.04)
    box(f"{id}-ridge", (xm - 0.22, y0 - o - 0.05, zr - 0.05), (xm + 0.22, y1 + o + 0.05, zr + 0.25), mat(f"ridge-{id}", shade(roof[0], 0.75)), coll)
    for gy in (y0, y1):
        mesh(f"{id}-gable", [(x0, gy, hz), (x1, gy, hz), (xm, gy, zr)], [(0, 1, 2)], plaster, coll)
    # Shoji window on the front-left face, lattice in timber.
    if window:
        wx0, wx1 = x0 + (x1 - x0) * 0.22, x0 + (x1 - x0) * 0.72
        wz0, wz1 = H(h * 0.35), H(h * 0.8)
        box(f"{id}-shoji", (wx0, y0 - 0.06, wz0), (wx1, y0 + 0.02, wz1), mat("shoji", 0xFBF3E0, 0xF2E6C8, emit=0.15), coll, bevel=0)
        # The lit pane for the night layer, just in front of the paper and behind the lattice.
        lit = mat("lamplight", 0xFFC870, 0xFFB050, emit=4)
        mesh(f"{id}-lit", [(wx0, y0 - 0.07, wz0), (wx1, y0 - 0.07, wz0), (wx1, y0 - 0.07, wz1), (wx0, y0 - 0.07, wz1)], [(0, 1, 2, 3)], lit, LIGHTS)
        for k in range(4):
            lx = wx0 + (wx1 - wx0) * k / 3
            box(f"{id}-lat", (lx - 0.04, y0 - 0.1, wz0), (lx + 0.04, y0 - 0.04, wz1), wood, coll, bevel=0)
        box(f"{id}-lat", (wx0, y0 - 0.1, (wz0 + wz1) / 2 - 0.04), (wx1, y0 - 0.04, (wz0 + wz1) / 2 + 0.04), wood, coll, bevel=0)
    # Door on the front-right face, with a noren curtain in two halves.
    dy0, dy1 = y0 + (y1 - y0) * 0.5, y0 + (y1 - y0) * 0.8
    box(f"{id}-door", (x1 - 0.02, dy0, 0.3), (x1 + 0.06, dy1, H(h * 0.72)), mat("doorway", 0x3B2A1E), coll, bevel=0)
    if noren:
        cloth = mat(f"noren-{id}", noren, shade(noren, 0.8), scale=10)
        mid = (dy0 + dy1) / 2
        for c0, c1 in [(dy0, mid - 0.04), (mid + 0.04, dy1)]:
            box(f"{id}-noren", (x1 + 0.06, c0, H(h * 0.42)), (x1 + 0.12, c1, H(h * 0.72)), cloth, coll, bevel=0.01)
    box(f"{id}-step", (x1 + 0.1, dy0 - 0.1, 0), (x1 + 0.7, dy1 + 0.1, 0.18), stone, coll)
    return (x0, y0, x1, y1, hz)


def rocks(id, center, radius, count, coll, size=(0.35, 0.6), seed=1):
    rnd = random.Random(seed)
    stone = mat("rock", 0xA29C90, 0x827C72, scale=5)
    for i in range(count):
        a = i * 2 * math.pi / count + rnd.uniform(-0.12, 0.12)
        r = rnd.uniform(*size)
        blob(f"{id}-rock", center + Vector((math.cos(a) * radius, math.sin(a) * radius, r * 0.25)), r, stone, coll, squash=0.6, seed=seed + i)


def water(name, center, r, coll):
    w = mat("water", 0x9CCFCF, 0x84C0C4, rough=0.15, scale=3, emit=0.1)
    return disc(name, center, r, w, coll, z=0.12, sides=40)


def spring(coll):
    c = W(200, 428)
    disc("spring-bed", c, 4.9, mat("rock-bed", 0x8A857A), coll, z=0.08, sides=40)
    water("spring-water", c, 4.4, coll)
    rocks("spring", c, 4.7, 22, coll, size=(0.45, 0.8), seed=3)
    # Bamboo fence around the far half for privacy, as onsen have.
    bamboo = mat("bamboo", 0xC9B26A, 0xA89350, scale=10)
    for i in range(56):
        a = math.radians(95 + i * 170 / 55)  # far side: toward -X / +Y
        p = c + Vector((math.cos(a) * 5.8, math.sin(a) * 5.8, 0))
        box("spring-fence", p - Vector((0.17, 0.17, 0)), p + Vector((0.17, 0.17, 1.8 + 0.12 * (i % 3))), bamboo, coll, bevel=0.03)
    for i in range(18):  # two tie rails
        a0, a1 = math.radians(95 + i * 170 / 18), math.radians(95 + (i + 1) * 170 / 18)
        for z in (0.6, 1.4):
            p, q = c + Vector((math.cos(a0) * 5.55, math.sin(a0) * 5.55, z)), c + Vector((math.cos(a1) * 5.55, math.sin(a1) * 5.55, z))
            box("spring-rail", Vector(map(min, p, q)) - Vector((0.05, 0.05, 0.06)), Vector(map(max, p, q)) + Vector((0.05, 0.05, 0.06)), mat("rope", 0x6B4A33), coll, bevel=0)
    bucket = W(160, 452)
    box("spring-bucket", bucket - Vector((0.25, 0.25, 0)), bucket + Vector((0.25, 0.25, 0.45)), mat("cedar", 0xB98A55), coll)


def pond(coll):
    c = W(105, 705)
    disc("pond-bed", c, 3.9, mat("rock-bed", 0x8A857A), coll, z=0.08, sides=40)
    water("pond-water", c, 3.5, coll)
    rocks("pond", c, 3.8, 16, coll, size=(0.35, 0.6), seed=7)
    pad = mat("lily", 0x6E9A55, 0x5C8746)
    for dx, dy, r in [(-1.2, 0.8, 0.45), (1.0, -1.1, 0.35), (1.6, 0.9, 0.4)]:
        disc("pond-lily", c + Vector((dx, dy, 0)), r, pad, coll, z=0.16, sides=14)


def pine(name, at, coll, s=1.0):
    box(f"{name}-trunk", at + Vector((-0.15 * s, -0.15 * s, 0)), at + Vector((0.15 * s, 0.15 * s, 0.8 * s)), mat("bark", 0x5A3E2B), coll)
    for k, dark in enumerate((0x2F5638, 0x3A6542, 0x46744C)):
        cone(f"{name}-needles", at + Vector((0, 0, (0.6 + k * 0.9) * s)), (1.2 - k * 0.3) * s, 1.6 * s, mat(f"needles{k}", dark, shade(dark, 0.85)), coll)


def bush(name, at, coll, seed=0):
    leaf = mat("bush", 0x5E8A4E, 0x4B7540, scale=6)
    for dx, dy, r in [(-0.45, 0.2, 0.55), (0.4, -0.2, 0.5), (0.0, 0.25, 0.65)]:
        blob(f"{name}-leaf", at + Vector((dx, dy, r * 0.6)), r, leaf, coll, squash=0.8, seed=seed)


def cherry(name, at, coll, seed=0):
    box(f"{name}-trunk", at + Vector((-0.18, -0.18, 0)), at + Vector((0.18, 0.18, 2.2)), mat("bark", 0x5A3E2B), coll)
    for k, (dx, dy, dz, r, col) in enumerate([(-0.6, 0.3, 2.6, 1.1, 0xF2B8C2), (0.6, -0.3, 2.8, 1.0, 0xEFA8B6), (0.1, 0.4, 3.5, 0.95, 0xF7CDD4)]):
        blob(f"{name}-bloom", at + Vector((dx, dy, dz)), r, mat(f"sakura{k}", col, shade(col, 0.9), scale=8), coll, squash=0.85, seed=seed + k)


def stone_lantern(name, at, coll):
    s = mat("lantern-stone", 0xA8A296, 0x8C8679, scale=7)
    box(f"{name}-foot", at + Vector((-0.35, -0.35, 0)), at + Vector((0.35, 0.35, 0.25)), s, coll)
    box(f"{name}-post", at + Vector((-0.15, -0.15, 0.25)), at + Vector((0.15, 0.15, 1.1)), s, coll)
    box(f"{name}-light", at + Vector((-0.3, -0.3, 1.1)), at + Vector((0.3, 0.3, 1.55)), mat("lantern-glow", 0xFFD98A, emit=0.6), coll)
    cone(f"{name}-cap", at + Vector((0, 0, 1.55)), 0.62, 0.5, s, coll, sides=4).rotation_euler.z = math.radians(45)


def bridge(coll):
    red = mat("vermilion", 0xC8433A, 0xA8362E)
    a, b = W(70, 724), W(142, 690)
    n = 12
    for i in range(n):
        t = i / (n - 1)
        p = a.lerp(b, t)
        p.z = 0.35 + 0.9 * math.sin(math.pi * t)
        d = (b - a).normalized()
        side = Vector((-d.y, d.x, 0)) * 0.55
        box("bridge-plank", p - side - d * 0.22, p + side + d * 0.22 + Vector((0, 0, 0.12)), mat("cedar", 0xB98A55), coll, bevel=0.01)
        if i % 3 == 0:
            for s in (side, -side):
                box("bridge-post", p + s * 1.05 - Vector((0.07, 0.07, 0.3)), p + s * 1.05 + Vector((0.07, 0.07, 0.6)), red, coll)
    for s in (1, -1):
        pts = []
        for i in range(n):
            t = i / (n - 1)
            p = a.lerp(b, t)
            p.z = 0.35 + 0.9 * math.sin(math.pi * t) + 0.55
            d = (b - a).normalized()
            pts.append(p + Vector((-d.y, d.x, 0)) * 0.58 * s)
        for p, q in zip(pts, pts[1:]):
            box("bridge-rail", Vector(map(min, p, q)) - Vector((0.06, 0.06, 0.06)), Vector(map(max, p, q)) + Vector((0.06, 0.06, 0.06)), red, coll, bevel=0)


# MARK: Ground

ROUTES = [
    [(200, 870), (195, 810), (250, 790), (240, 750), (230, 712), (175, 692), (195, 645), (212, 610), (210, 560), (200, 520),
     (190, 488), (118, 478), (110, 440), (102, 400), (140, 370), (172, 345), (200, 322), (214, 292), (236, 252)],
    [(-40, 612), (40, 596), (110, 604), (160, 614), (220, 626), (250, 690), (300, 690), (340, 690), (380, 660), (430, 650)],
    [(430, 372), (360, 366), (330, 346), (290, 336), (250, 326), (220, 352), (172, 345), (130, 340), (60, 386), (-40, 378)],
]  # same as VillageScene.routes, so visitors walk on the painted paths


def bezier(points, steps=14):
    out = [points[0]]
    for i in range(1, len(points) - 2, 3):
        p0, c1, c2, p3 = points[i - 1], points[i], points[i + 1], points[i + 2]
        for s in range(1, steps + 1):
            t = s / steps
            out.append(tuple((1 - t) ** 3 * p0[k] + 3 * (1 - t) ** 2 * t * c1[k] + 3 * (1 - t) * t * t * c2[k] + t ** 3 * p3[k] for k in (0, 1)))
    return out


def ribbon(name, board_pts, width, z, material, coll):
    pts = [W(*q, z) for q in board_pts]
    verts, faces = [], []
    for i, p in enumerate(pts):
        d = (pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]).normalized()
        side = Vector((-d.y, d.x, 0)) * width / 2
        verts += [p - side, p + side]
        if i:
            faces.append((2 * i - 2, 2 * i - 1, 2 * i + 1, 2 * i))
    return mesh(name, verts, faces, material, coll)


def ground(coll):
    grass = mat("grass", 0xAFCB92, 0x8FB275, scale=0.6)
    edge = [(-10, 228), (120, 206), (230, 216), (320, 208), (400, 206)]
    outline = edge + [(400, 960), (-10, 960)]
    mesh("meadow", [W(*q) for q in outline], [tuple(range(len(outline)))], grass, coll)
    gravel, kerb = mat("path", 0xE6D9C0, 0xD6C6A6, scale=5), mat("kerb", 0xB7A88C, 0xA39478, scale=5)
    for i, route in enumerate(ROUTES):
        line = bezier(route)
        # Each route a hair higher than the last, so crossings don't flicker.
        ribbon(f"kerb{i}", line, 1.75, 0.02 + 0.004 * i, kerb, coll)
        ribbon(f"path{i}", line, 1.4, 0.05 + 0.004 * i, gravel, coll)
    # Grass tufts and wildflowers, kept off the paths.
    lines = [W(*q) for r in ROUTES for q in bezier(r)]
    tuft, flowers = mat("tuft", 0x86AD6A, 0x6F9858), [mat(f"flower{k}", col) for k, col in enumerate((0xFFF6E6, 0xF6D46B, 0xF2B8C2))]
    rnd = random.Random(5)
    for i in range(260):
        p = W(rnd.uniform(-10, 400), rnd.uniform(240, 900))
        if min((p - q).length for q in lines) < 1.4:
            continue
        if i % 4:
            for k in range(3):
                cone("tuft", p + Vector((rnd.uniform(-0.2, 0.2), rnd.uniform(-0.2, 0.2), 0)), 0.09, rnd.uniform(0.3, 0.5), tuft, coll, sides=4)
        else:
            blob("flower", p + Vector((0, 0, 0.12)), 0.13, rnd.choice(flowers), coll, seed=i)
    # Far pines along the meadow's top edge.
    rnd = random.Random(11)
    x = -6.0
    while x < 400:
        j = max(k for k in range(len(edge)) if edge[k][0] <= x)
        (ax, ay), (bx, by) = edge[j], edge[min(j + 1, len(edge) - 1)]
        y = ay + (by - ay) * (x - ax) / max(bx - ax, 1) + 4
        pine("ridge-pine", W(x, y), coll, s=rnd.uniform(0.35, 0.55))
        x += rnd.uniform(9, 14)
    for i, (bx, by) in enumerate([(22, 312), (376, 336), (300, 470), (16, 740), (372, 520)]):
        pine(f"pine{i}", W(bx, by), coll, s=rnd.uniform(0.85, 1.05))
    for i, (bx, by) in enumerate([(244, 470), (180, 590), (262, 760), (360, 700), (70, 640), (140, 280)]):
        bush(f"bush{i}", W(bx, by), coll, seed=i)


# MARK: Build and render

PLACES = {
    "tea": lambda c: house("tea", 110, 300, 56, 40, 34, 26, (0x3A3A44, 0x4A4A55), 0x2F4A6E, c),
    "books": lambda c: house("books", 300, 270, 48, 36, 30, 22, (0x46372B, 0x5A4636), 0x3F6E4E, c),
    "bath": lambda c: house("bath", 262, 388, 34, 28, 24, 18, (0x2F4A50, 0x3E5E66), 0xC8433A, c, window=False),
    "spring": spring,
    "maple": lambda c: house("maple", 76, 545, 42, 32, 28, 20, (0x6E2F22, 0x8E3E2C), None, c),
    "pine": lambda c: house("pine", 312, 612, 42, 32, 28, 20, (0x2E4834, 0x3E5E46), 0x8E2F2A, c),
    "pond": pond,
}

STAGES = {
    2: lambda c: [stone_lantern(f"lantern{i}", W(x, y), c) for i, (x, y) in enumerate([(171, 800), (275, 772), (157, 566)])],
    4: lambda c: [cherry(f"cherry{i}", W(x, y), c, seed=i * 3) for i, (x, y) in enumerate([(30, 404), (362, 470), (207, 226)])],
    5: bridge,
}


LIGHTS = None


def build():
    global LIGHTS
    scene()
    LIGHTS = layer("lights")
    ground(layer("ground"))
    for id, make in PLACES.items():
        make(layer(f"place-{id}"))
    for n, make in STAGES.items():
        make(layer(f"village-{n}"))
    catcher = box("shadow-catcher", W(195, 422) - Vector((60, 60, 0.01)), W(195, 422) + Vector((60, 60, 0)), mat("catcher", 0xFFFFFF), layer("catcher"), bevel=0)
    catcher.is_shadow_catcher = True


def render(name, holdouts=()):
    """Renders one layer alone. The catcher keeps its shadows on the ground; holdouts cut out whatever stands in front of it."""
    vl = bpy.context.view_layer
    for lc in vl.layer_collection.children:
        lc.exclude = lc.name not in (name, *holdouts) and not (lc.name == "catcher" and name != "ground")
        lc.holdout = lc.name in holdouts
    bpy.context.scene.render.filepath = f"{OUT}/{name}@3x.png"
    bpy.ops.render.render(write_still=True)


def render_all():
    render("ground")
    places = [f"place-{id}" for id in PLACES]
    render("lights", holdouts=places)  # lit windows the app shows only at night
    for p in places:
        render(p)
    for n in STAGES:
        render(f"village-{n}", holdouts=places)  # stage layers are drawn over the places, so places hide what's behind them
