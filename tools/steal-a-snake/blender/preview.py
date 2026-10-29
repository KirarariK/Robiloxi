"""Rendus d'aperçu (EEVEE) des serpents un par un, pour comparer à l'image de référence."""
import math
import os

import bpy
import mathutils

OUT = r"C:\Users\devaa\Desktop\robiloxiiiii\tools\steal-a-snake\exports\preview"


def setup(res=300):
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_EEVEE"
    sc.render.resolution_x = res
    sc.render.resolution_y = res
    sc.view_settings.view_transform = "Standard"
    sc.view_settings.look = "None"
    w = bpy.data.worlds.get("World") or bpy.data.worlds.new("World")
    sc.world = w
    w.use_nodes = True
    bg = w.node_tree.nodes.get("Background")
    bg.inputs[0].default_value = (0.55, 0.52, 0.62, 1)
    bg.inputs[1].default_value = 1.3
    cam = bpy.data.objects.get("PrevCam")
    if not cam:
        cam = bpy.data.objects.new("PrevCam", bpy.data.cameras.new("PrevCam"))
        sc.collection.objects.link(cam)
    sc.camera = cam
    cam.data.lens = 50
    sun = bpy.data.objects.get("PrevSun")
    if not sun:
        sun = bpy.data.objects.new("PrevSun", bpy.data.lights.new("PrevSun", "SUN"))
        sc.collection.objects.link(sun)
    sun.data.energy = 5.0
    sun.rotation_euler = (math.radians(45), 0, math.radians(-25))
    return cam


def frame_object(cam, root, dist=7.0, side=2.4):
    mn = mathutils.Vector((1e9, 1e9, 1e9))
    mx = -mn
    for ob in root.children_recursive:
        if ob.type == "MESH":
            for c in ob.bound_box:
                p = ob.matrix_world @ mathutils.Vector(c)
                mn = mathutils.Vector((min(mn.x, p.x), min(mn.y, p.y), min(mn.z, p.z)))
                mx = mathutils.Vector((max(mx.x, p.x), max(mx.y, p.y), max(mx.z, p.z)))
    t = (mn + mx) / 2
    size = max(mx - mn)
    pos = t + mathutils.Vector((side, -5.4, 1.4)).normalized() * dist * size / 4.4
    cam.location = pos
    cam.rotation_euler = (t - pos).to_track_quat("-Z", "Y").to_euler()


def render_specs(specs, build_one, clear_scene, prefix="s", side=2.4):
    os.makedirs(OUT, exist_ok=True)
    cam = setup()
    paths = []
    for s in specs:
        clear_scene()
        cam = setup()
        root = build_one(s)
        for m in bpy.data.materials:
            m.use_backface_culling = True
        frame_object(cam, root, side=side)
        p = os.path.join(OUT, "%s_%s.png" % (prefix, s["id"]))
        bpy.context.scene.render.filepath = p
        bpy.ops.render.render(write_still=True)
        paths.append(p)
    return paths
