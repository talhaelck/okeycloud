"""Talks to the Meshy API (https://docs.meshy.ai): generates, rigs and animates models into raw/meshy/.

The key comes from the MESHY_API_KEY environment variable or the git-ignored .env file in the project root.

    python tools/meshy.py balance                         check the key and remaining credits
    python tools/meshy.py image <image.png> <name>        image to 3D (textured, PBR)
    python tools/meshy.py picture "<prompt>" <name> [model]  text to image (A-pose, plain background) -> raw/meshy/<name>.png
    python tools/meshy.py photo "<prompt>" <name> [model]    text to image, 4:3, no pose (wall pictures)
    python tools/meshy.py text "<prompt>" <name>          text to 3D (preview, then textured refine)
    python tools/meshy.py rig <model.glb> <name> [height] rig a standing humanoid (face toward glTF +Z)
    python tools/meshy.py animate <rig task id> <name> <action id>...   preset animations, one clip each
    python tools/meshy.py actions [filter]                list the animation library

Every finished task is saved as raw/meshy/<name>*.glb; then run tools/blender/meshy_import.py to make it game-ready.
"""
import base64
import json
import mimetypes
import os
import pathlib
import sys
import time
import urllib.error
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "raw" / "meshy"
API = "https://api.meshy.ai/openapi"


def api_key():
    key = os.environ.get("MESHY_API_KEY", "")
    env = ROOT / ".env"
    if not key and env.exists():
        for line in env.read_text(encoding="utf-8").splitlines():
            if line.startswith("MESHY_API_KEY="):
                key = line.split("=", 1)[1].strip()
    if not key:
        sys.exit("MESHY_API_KEY yok: proje klasöründeki .env dosyasına anahtarı yapıştır.")
    return key


def call(method, path, body=None):
    req = urllib.request.Request(API + path, method=method, headers={"Authorization": "Bearer " + api_key()})
    if body is not None:
        req.data = json.dumps(body).encode()
        req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req) as r:
            return json.loads(r.read())
    except urllib.error.HTTPError as e:
        sys.exit("Meshy %s %s -> %d: %s" % (method, path, e.code, e.read().decode(errors="replace")))


def data_uri(path):
    mime = mimetypes.guess_type(path)[0] or "application/octet-stream"
    if path.endswith(".glb"):
        mime = "model/gltf-binary"
    return "data:%s;base64,%s" % (mime, base64.b64encode(pathlib.Path(path).read_bytes()).decode())


def wait(path, task_id):
    while True:
        task = call("GET", "%s/%s" % (path, task_id))
        print("  %s %s %d%%" % (task_id, task["status"], task.get("progress", 0)), flush=True)
        if task["status"] == "SUCCEEDED":
            print("  credits used:", task.get("consumed_credits"))
            return task
        if task["status"] in ("FAILED", "CANCELED"):
            sys.exit("Task failed: %s" % task.get("task_error", {}).get("message", task["status"]))
        time.sleep(5)


def download(url, name):
    OUT.mkdir(parents=True, exist_ok=True)
    path = OUT / name
    with urllib.request.urlopen(url) as r:
        path.write_bytes(r.read())
    print("  saved", path.relative_to(ROOT))


def generate(path, body, name):
    task = wait(path, call("POST", path, body)["result"])
    download(task["model_urls"]["glb"], name + ".glb")
    return task


def main(cmd, *rest):
    if cmd == "balance":
        print(call("GET", "/v1/balance"))
    elif cmd == "image":
        image, name = rest
        generate("/v1/image-to-3d", {"image_url": data_uri(image), "should_texture": True, "enable_pbr": True,
                                     "should_remesh": True, "target_polycount": 100000, "pose_mode": "a-pose",
                                     "target_formats": ["glb"]}, name)
    elif cmd in ("picture", "photo"):
        prompt, name = rest[:2]
        body = {"ai_model": rest[2] if len(rest) > 2 else "nano-banana-2", "prompt": prompt, "aspect_ratio": "3:4"}
        if cmd == "picture":
            body["pose_mode"] = "a-pose"  # characters to be turned into 3D; a photo for a wall needs no pose
        else:
            body["aspect_ratio"] = "4:3"
        task = wait("/v1/text-to-image", call("POST", "/v1/text-to-image", body)["result"])
        download(task["image_urls"][0], name + ".png")
    elif cmd == "text":
        prompt, name = rest
        preview = wait("/v2/text-to-3d", call("POST", "/v2/text-to-3d", {"mode": "preview", "prompt": prompt})["result"])
        generate("/v2/text-to-3d", {"mode": "refine", "preview_task_id": preview["id"], "enable_pbr": True}, name)
    elif cmd == "rig":
        model, name = rest[:2]
        body = {"model_url": data_uri(model), "height_meters": float(rest[2]) if len(rest) > 2 else 1.7}
        task = wait("/v1/rigging", call("POST", "/v1/rigging", body)["result"])
        print("  rig task id (for animate):", task["id"])
        download(task["result"]["rigged_character_glb_url"], name + "_rigged.glb")
    elif cmd == "animate":
        rig_id, name, *actions = rest
        task = wait("/v1/animations", call("POST", "/v1/animations",
                                           {"rig_task_id": rig_id, "action_ids": [int(a) for a in actions]})["result"])
        download(task["result"]["animation_glb_url"], name + "_anim.glb")
    elif cmd == "actions":
        for action in call("GET", "/v1/animations/library"):
            line = json.dumps(action, ensure_ascii=False)
            if not rest or rest[0].lower() in line.lower():
                print(line)
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main(*sys.argv[1:]) if len(sys.argv) > 1 else sys.exit(__doc__)
