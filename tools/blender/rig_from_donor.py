"""Gives a Meshy model a Mixamo skeleton without Mixamo, for when its auto-rigger refuses the model: a donor's
Mixamo armature (another dayı, 65 bones with fingers) is moved onto this model's joints, read from Meshy's own rig
of the same model, and Meshy's skin weights are renamed onto it (automatic weights fail on Meshy's open meshes).
Bones Meshy has no joint for (fingers, toe ends) keep their offsets from their parent, turned and scaled with it;
they carry no weights, so the hand moves as one piece. The output is an FBX shaped like a Mixamo download, for
mixamo_import.py.

    blender -b --factory-startup -P tools/blender/rig_from_donor.py -- <donor mixamo.fbx> <meshy rigged.glb> <out.fbx>
"""
import os
import sys

import bpy
from mathutils import Matrix

sys.path.append(os.path.dirname(__file__))
from kit import args, reset  # noqa: E402

PREFIX = "mixamorig:"
# Mixamo bone -> the Meshy rig's bone at the same joint.
JOINTS = {"Hips": "Hips", "Spine": "Spine02", "Spine1": "Spine01", "Spine2": "Spine", "Neck": "neck", "Head": "Head",
          "HeadTop_End": "head_end"}
for side in ("Left", "Right"):
    for name in ("Shoulder", "Arm", "ForeArm", "Hand", "UpLeg", "Leg", "Foot", "ToeBase"):
        JOINTS[side + name] = side + name


def load(path):
    before = set(bpy.data.objects)
    if path.endswith(".fbx"):
        bpy.ops.import_scene.fbx(filepath=path)
    else:
        bpy.ops.import_scene.gltf(filepath=path)
    return [o for o in bpy.data.objects if o not in before]


def main():
    donor_path, meshy_path, out = (os.path.abspath(p) for p in args()[:3])
    reset()
    donor = load(donor_path)
    armature = next(o for o in donor if o.type == "ARMATURE")
    for obj in donor:
        if obj.type == "MESH":
            bpy.data.objects.remove(obj)
    meshy = load(meshy_path)
    rig = next(o for o in meshy if o.type == "ARMATURE")
    to_armature = armature.matrix_world.inverted()
    joints = {name: to_armature @ (rig.matrix_world @ rig.data.bones[meshy_name].head_local)
              for name, meshy_name in JOINTS.items() if meshy_name in rig.data.bones}
    target = next(o for o in meshy if o.type == "MESH" and o.name != "Icosphere")
    for obj in meshy:
        if obj is not target:
            bpy.data.objects.remove(obj)
    # Meshy's weights, renamed to the Mixamo bones at the same joints.
    renames = {meshy_name: PREFIX + name for name, meshy_name in JOINTS.items()}
    for group in target.vertex_groups:
        if group.name in renames:
            group.name = renames[group.name]
    # Meshy's extra face bone moves with the head.
    face = target.vertex_groups.get("headfront")
    head = target.vertex_groups.get(PREFIX + "Head")
    if face and head:
        for vertex in target.data.vertices:
            for g in vertex.groups:
                if g.group == face.index:
                    head.add([vertex.index], g.weight, "ADD")
        target.vertex_groups.remove(face)
    for modifier in list(target.modifiers):
        target.modifiers.remove(modifier)
    target.parent = None

    bpy.context.view_layer.objects.active = armature
    bpy.ops.object.mode_set(mode="EDIT")
    bones = armature.data.edit_bones
    for bone in bones:
        bone.use_connect = False
    original = {b.name: (b.head.copy(), b.tail.copy(), b.matrix.to_3x3().normalized()) for b in bones}
    placed = {}  # name -> (new head, rotation, scale)

    def place(bone):
        name = bone.name.replace(PREFIX, "")
        head, tail, rot = original[bone.name]
        parent = bone.parent
        if name in joints:
            new_head = joints[name]
        else:
            p_head, _, _ = original[parent.name]
            np_head, p_q, p_s = placed[parent.name]
            new_head = np_head + p_q @ (head - p_head) * p_s
        # Turn and stretch toward the first child that has a joint of its own; otherwise follow the parent.
        q, s = None, 1.0
        for child in bone.children:
            child_name = child.name.replace(PREFIX, "")
            if child_name in joints and name in joints:
                before = original[child.name][0] - head
                after = joints[child_name] - new_head
                if before.length > 1e-5 and after.length > 1e-5:
                    q = before.rotation_difference(after).to_matrix()
                    s = after.length / before.length
                    break
        if q is None:
            if parent is not None and parent.name in placed:
                _, q, s = placed[parent.name]
            else:
                q = Matrix.Identity(3)
        placed[bone.name] = (new_head, q, s)
        length = (tail - head).length * s
        bone.matrix = Matrix.Translation(new_head) @ (q @ rot).to_4x4()
        bone.length = max(length, 0.002)
        for child in bone.children:
            place(child)

    for bone in [b for b in bones if b.parent is None]:
        place(bone)
    bpy.ops.object.mode_set(mode="OBJECT")

    bpy.ops.object.select_all(action="DESELECT")
    target.select_set(True)
    armature.select_set(True)
    bpy.context.view_layer.objects.active = armature
    bpy.ops.object.parent_set(type="ARMATURE_NAME")
    for group in list(target.vertex_groups):
        if not group.name.startswith(PREFIX) and group.name.startswith("ARMATURE") is False and group.name not in armature.data.bones:
            print("RIG_FROM_DONOR unmapped group", group.name)
    weighted = sum(1 for v in target.data.vertices if v.groups)
    print("RIG_FROM_DONOR weighted vertices %d / %d" % (weighted, len(target.data.vertices)))

    # Embed textures: FBX can only carry images that exist as files.
    folder = os.path.splitext(out)[0] + "_tex"
    os.makedirs(folder, exist_ok=True)
    for i, image in enumerate(bpy.data.images):
        if image.size[0]:
            image.filepath_raw = os.path.join(folder, "tex_%d.png" % i)
            image.file_format = "PNG"
            image.save()
    bpy.ops.export_scene.fbx(filepath=out, object_types={"ARMATURE", "MESH"}, add_leaf_bones=False, bake_anim=False,
                             path_mode="COPY", embed_textures=True)
    print("RIG_FROM_DONOR", out)


main()
