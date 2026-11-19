# The village visitors: small folklore animals in yukata, walking upright. Builds on village.py's helpers.
# Run inside Blender:  exec(open("<repo>/ios/art/village.py").read()); exec(open("<repo>/ios/art/visitors.py").read()); build_visitors(); render_visitors()
# Each visitor renders 4 walk frames facing down-right ("front") and up-right ("back"), plus a wave; the app mirrors for left.
import bpy, bmesh, math
from mathutils import Vector

BOX = 64  # frame size in board points; feet sit 8 points above the bottom edge


def part(name, coll, parent, at, make, material):
    """A mesh built around its own pivot `at` (local to `parent`), so it can swing."""
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    make(bm)
    bm.to_mesh(me)
    bm.free()
    me.materials.append(material)
    for p in me.polygons:
        p.use_smooth = True
    o = bpy.data.objects.new(name, me)
    o.parent = parent
    o.location = at
    coll.objects.link(o)
    return o


def ball(r, sx=1.0, sy=1.0, sz=1.0, off=(0, 0, 0)):
    def make(bm):
        bmesh.ops.create_uvsphere(bm, u_segments=20, v_segments=12, radius=r)
        for v in bm.verts:
            v.co = Vector((v.co.x * sx + off[0], v.co.y * sy + off[1], v.co.z * sz + off[2]))
    return make


def brick(sx, sy, sz):
    def make(bm):
        bmesh.ops.create_cube(bm, size=1)
        for v in bm.verts:
            v.co = Vector((v.co.x * sx, v.co.y * sy, v.co.z * sz))
    return make


def tube(r1, r2, depth, down=True):
    """A tapered cylinder hanging from (or standing on) its pivot."""
    def make(bm):
        bmesh.ops.create_cone(bm, cap_ends=True, segments=16, radius1=r1, radius2=r2, depth=depth)
        for v in bm.verts:
            v.co.z += -depth / 2 if down else depth / 2
    return make


def ear_cone(r, h, round_tip=False):
    def make(bm):
        bmesh.ops.create_cone(bm, cap_ends=True, segments=12, radius1=r, radius2=r * (0.45 if round_tip else 0.05), depth=h)
        for v in bm.verts:
            v.co.z += h / 2
            v.co.x *= 0.55  # flat ears
    return make


LOOKS = {
    # fur, light fur, outfit, outfit trim, ears ("point" / "round" / "long"), tail, extra
    "tanuki": dict(fur=0x8A6A4A, light=0xE8D8BC, cloth=0x6E7F5A, trim=0xD9B26A, ears="round", tail=0x6A503A, mask=0x3A2E26, hat=0xD8B76A),
    "fox": dict(fur=0xE0782E, light=0xFFF3E0, cloth=0x3D5A8A, trim=0xF2D9A8, ears="point", tail=0xE0782E, tip=0xFFF3E0),
    "rabbit": dict(fur=0xF4EEE6, light=0xFFFFFF, cloth=0xE8A0B0, trim=0x8E2A24, ears="long", tail=0xFFFFFF, inner=0xF2B8C2, basket=0xB98A55),
    "shiba": dict(fur=0xD9924A, light=0xFFF0DC, cloth=0x23395B, trim=0xF6EBD6, ears="point", tail=0xD9924A, scarf=0xC8433A),
    "cat": dict(fur=0xFAF4EA, light=0xFFFFFF, cloth=0x4B3B6E, trim=0xE2A93B, ears="point", tail=0x3A3030, patch=(0xE08A3C, 0x3A3030), cup=0x9CCFCF),
    "monkey": dict(fur=0x9A8A78, light=0xE8A08E, cloth=0x5B7A8C, trim=0xF2E8D8, ears="round", tail=0x9A8A78, towel=0xFFFFFF),
    "deer": dict(fur=0xB07A48, light=0xF6EAD8, cloth=0x7A3E4A, trim=0xE8C77A, ears="point", tail=0xFFFFFF, antler=0xE6D3B0),
    "bear": dict(fur=0x3A3330, light=0xC9A882, cloth=0xC88A3A, trim=0x2F4A3E, ears="round", tail=0x3A3330, jar=0xE0B040),
}


def visitor(id):
    """Faces +X (down-right on screen). Returns the root and the parts the walk cycle moves."""
    L = LOOKS[id]
    coll = layer(f"visitor-{id}")
    root = bpy.data.objects.new(f"{id}-root", None)
    coll.objects.link(root)
    fur, light = mat(f"{id}-fur", L["fur"], shade(L["fur"], 0.94), scale=5), mat(f"{id}-light", L["light"], shade(L["light"], 0.95))
    cloth, trim = mat(f"{id}-cloth", L["cloth"], shade(L["cloth"], 0.82), scale=9), mat(f"{id}-trim", L["trim"])
    ink = mat("eye", 0x1E1612, rough=0.3)

    legs = [part(f"{id}-leg", coll, root, (0, s * 0.17, 0.42), tube(0.12, 0.12, 0.4), fur) for s in (1, -1)]
    for leg in legs:  # wooden geta under each foot
        part(f"{id}-geta", coll, leg, (0.05, 0, -0.4), brick(0.42, 0.24, 0.08), mat("geta", 0xB98A55))
    body = part(f"{id}-body", coll, root, (0, 0, 0.38), tube(0.5, 0.36, 1.0, down=False), cloth)
    part(f"{id}-obi", coll, body, (0, 0, 0.5), tube(0.45, 0.43, 0.2, down=False), trim)
    part(f"{id}-collar", coll, body, (0.3, 0, 0.9), ball(0.12, 0.5, 1.6, 1.0), mat(f"{id}-collar", L["light"]))
    arms = []
    for s in (1, -1):
        arm = part(f"{id}-arm", coll, root, (0, s * 0.42, 1.28), tube(0.2, 0.15, 0.55), cloth)
        part(f"{id}-hand", coll, arm, (0, 0, -0.6), ball(0.12), fur)
        arms.append(arm)

    head = part(f"{id}-head", coll, root, (0.02, 0, 1.85), ball(0.56, 1.0, 1.05, 0.92), fur)
    part(f"{id}-muzzle", coll, head, (0.38, 0, -0.18), ball(0.26, 0.9, 1.1, 0.75), light)
    part(f"{id}-nose", coll, head, (0.62, 0, -0.12), ball(0.075), ink)
    for s in (1, -1):
        part(f"{id}-eye", coll, head, (0.47, s * 0.22, 0.04), ball(0.09, 0.6, 1.0, 1.3), ink)
        part(f"{id}-blush", coll, head, (0.38, s * 0.36, -0.16), ball(0.08, 0.4, 1.0, 0.7), mat("blush", 0xF2A3A8))
        tilt = Vector((0, s * 0.35, 0))
        if L["ears"] == "long":
            ear = part(f"{id}-ear", coll, head, (-0.05, s * 0.2, 0.42), ear_cone(0.16, 0.85, round_tip=True), fur)
            part(f"{id}-inner", coll, ear, (0.04, 0, 0.05), ear_cone(0.09, 0.65, round_tip=True), mat(f"{id}-inner", L["inner"]))
            ear.rotation_euler = (s * -0.15, -0.15, 0)
        else:
            r, h = (0.17, 0.26) if L["ears"] == "round" else (0.2, 0.42)
            ear = part(f"{id}-ear", coll, head, (-0.02, s * 0.3, 0.36), ear_cone(r, h, round_tip=L["ears"] == "round"), fur)
            ear.rotation_euler = (s * -0.3, 0, 0)

    tail = mat(f"{id}-tail", L["tail"], shade(L["tail"], 0.92), scale=5)
    if id == "fox":
        t = part("fox-tail", coll, root, (-0.45, 0, 0.55), ball(0.3, 1.9, 0.75, 0.75, off=(-0.4, 0, 0.1)), tail)
        part("fox-tip", coll, t, (-0.95, 0, 0.15), ball(0.2), mat("fox-tip", L["tip"]))
        t.rotation_euler.y = -0.5
    elif id == "tanuki":
        t = part("tanuki-tail", coll, root, (-0.45, 0, 0.45), ball(0.26, 1.6, 0.9, 0.9, off=(-0.3, 0, 0)), tail)
        t.rotation_euler.y = -0.3
        for s in (1, -1):  # the dark eye mask
            part("tanuki-mask", coll, head, (0.42, s * 0.22, 0.0), ball(0.16, 0.5, 1.0, 0.9), mat("tanuki-mask", L["mask"]))
        hat = mat("straw", L["hat"], shade(L["hat"], 0.85), scale=20)
        brim = part("tanuki-hat", coll, head, (0, 0, 0.38), tube(0.78, 0.7, 0.06, down=False), hat)
        part("tanuki-crown", coll, brim, (0, 0, 0.05), tube(0.36, 0.3, 0.3, down=False), hat)
        part("tanuki-band", coll, brim, (0, 0, 0.06), tube(0.37, 0.36, 0.09, down=False), mat("hat-band", 0x8E2A24))
    elif id == "rabbit":
        part("rabbit-tail", coll, root, (-0.5, 0, 0.55), ball(0.17), tail)
        basket = part("rabbit-basket", coll, arms[1], (0.12, -0.05, -0.62), tube(0.24, 0.18, 0.3), mat("wicker", L["basket"], shade(L["basket"], 0.8), scale=30))
        for k, col in enumerate((0xE2A93B, 0xC8433A)):  # yuzu and an apple
            part("rabbit-fruit", coll, basket, (0.06 - k * 0.12, 0, 0.02), ball(0.1), mat(f"fruit{k}", col))
    elif id == "shiba":
        part("shiba-tail", coll, root, (-0.48, 0, 0.85), ball(0.22, 1.0, 0.7, 1.0), tail)
        part("shiba-scarf", coll, body, (0, 0, 0.98), tube(0.42, 0.38, 0.16, down=False), mat("scarf", L["scarf"]))
        part("shiba-knot", coll, body, (0.3, -0.2, 0.95), ball(0.12), mat("scarf", L["scarf"]))
        for s in (1, -1):  # cream eyebrows, as shibas have
            part("shiba-brow", coll, head, (0.45, s * 0.22, 0.17), ball(0.06), light)
    elif id == "cat":
        # An S-curve tail held up, as cats do: a low segment back, then a raised one with a tip.
        orange = mat("calico-orange", L["patch"][0], scale=5)
        t = part("cat-tail", coll, root, (-0.42, 0, 0.6), tube(0.09, 0.08, 0.5, down=False), orange)
        t.rotation_euler.y = -1.1
        up = part("cat-tail2", coll, t, (0, 0, 0.48), tube(0.08, 0.07, 0.5, down=False), orange)
        up.rotation_euler.y = 1.3
        part("cat-tip", coll, up, (0, 0, 0.5), ball(0.08), mat("calico-black", L["patch"][1], scale=5))
        part("cat-patch", coll, head, (-0.12, 0.28, 0.25), ball(0.3, 1.0, 0.8, 0.8), mat("calico-orange", L["patch"][0], scale=5))
        part("cat-patch", coll, head, (-0.1, -0.3, 0.2), ball(0.26, 1.0, 0.8, 0.8), mat("calico-black", L["patch"][1], scale=5))
        cup = part("cat-cup", coll, arms[1], (0.12, 0, -0.66), tube(0.11, 0.09, 0.16, down=False), mat("teacup", L["cup"]))
        part("cat-tea", coll, cup, (0, 0, 0.15), tube(0.1, 0.1, 0.01, down=False), mat("tea", 0x7A9A4A))
    elif id == "monkey":
        # A snow monkey with a folded onsen towel on its head.
        part("monkey-tail", coll, root, (-0.48, 0, 0.6), ball(0.1, 1.4, 1.0, 1.0), tail)
        part("monkey-face", coll, head, (0.3, 0, 0.02), ball(0.4, 0.7, 1.0, 1.0), light)
        part("monkey-towel", coll, head, (-0.02, 0, 0.5), brick(0.5, 0.38, 0.1), mat("towel", L["towel"], shade(L["towel"], 0.92), scale=30))
    elif id == "deer":
        # A Nara deer: white rump tail, spots on the back of the head, and little antlers.
        part("deer-tail", coll, root, (-0.5, 0, 0.7), ball(0.13, 0.8, 1.0, 1.3), tail)
        for k, (y, z) in enumerate([(0.2, 0.25), (-0.2, 0.3), (0, 0.05)]):
            part("deer-spot", coll, head, (-0.45, y, z), ball(0.07), light)
        antler = mat("antler", L["antler"])
        for s in (1, -1):
            a = part("deer-antler", coll, head, (0.0, s * 0.16, 0.42), tube(0.05, 0.035, 0.42, down=False), antler)
            a.rotation_euler = (s * -0.35, -0.2, 0)
            prong = part("deer-prong", coll, a, (0, 0, 0.26), tube(0.03, 0.02, 0.2, down=False), antler)
            prong.rotation_euler.y = 0.8
    elif id == "bear":
        # A moon bear with its pale crescent, carrying a little pot of honey.
        part("bear-tail", coll, root, (-0.48, 0, 0.6), ball(0.12), tail)
        part("bear-moon", coll, body, (0.36, 0, 0.82), ball(0.1, 0.4, 2.2, 0.6), mat("bear-moon", 0xF4EEE6))
        jar = part("bear-jar", coll, arms[1], (0.12, 0, -0.68), tube(0.13, 0.11, 0.2, down=False), mat("honey-jar", L["jar"], shade(L["jar"], 0.8)))
        part("bear-lid", coll, jar, (0, 0, 0.19), tube(0.14, 0.14, 0.05, down=False), mat("jar-cloth", 0xC8433A))
    return root, legs, arms


def pose(root, legs, arms, frame, facing, wave=False):
    """frame 0 is standing; 1-3 with 0 make the walk cycle."""
    swing = math.sin(frame * math.pi / 2)
    root.rotation_euler.z = 0 if facing == "front" else math.radians(90)
    root.location.z = 0.05 * abs(swing)
    legs[0].rotation_euler.y, legs[1].rotation_euler.y = 0.45 * swing, -0.45 * swing
    arms[0].rotation_euler = (0, -0.4 * swing, 0)
    arms[1].rotation_euler = (0, 0.4 * swing, 0)
    if wave:  # the camera-side arm (−Y) up and waving
        arms[1].rotation_euler = (-2.5, 0, 0)


def build_visitors():
    global VISITORS
    for c in list(bpy.context.scene.collection.children):
        if c.name.startswith("visitor-"):
            for o in list(c.objects):
                bpy.data.objects.remove(o)
            bpy.data.collections.remove(c)
    VISITORS = {id: visitor(id) for id in LOOKS}


def render_visitors(out=None):
    sc = bpy.context.scene
    cam = sc.camera
    old = (cam.data.ortho_scale, cam.data.shift_y, cam.location.copy(), sc.render.resolution_x, sc.render.resolution_y)
    cam.data.ortho_scale = BOX / K
    cam.data.shift_y = 0.5 - 8 / BOX
    cam.location = Vector((0.6124, -0.6124, 0.5)) * 120
    sc.render.resolution_x = sc.render.resolution_y = BOX * 3
    try:
        for id, (root, legs, arms) in VISITORS.items():
            vl = bpy.context.view_layer
            for lc in vl.layer_collection.children:
                lc.exclude = lc.name not in (f"visitor-{id}", "catcher")
                lc.holdout = False
            shots = [(f, d, False) for d in ("front", "back") for f in range(4)] + [(0, "front", True)]
            for f, d, wave in shots:
                pose(root, legs, arms, f, d, wave)
                name = f"visitor-{id}-wave" if wave else f"visitor-{id}-{d}-{f}"
                sc.render.filepath = f"{out or OUT}/{name}@3x.png"
                bpy.ops.render.render(write_still=True)
            pose(root, legs, arms, 0, "front")
    finally:
        cam.data.ortho_scale, cam.data.shift_y, cam.location, sc.render.resolution_x, sc.render.resolution_y = old
