"""下載 Poly Haven（CC0 公眾領域）的 HDRI、PBR 貼圖、glTF 模型 → assets/sky、assets/tex、assets/models
用法：python -I -X utf8 tools/fetch_polyhaven.py
"""
import json
import os
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
UA = {"User-Agent": "godot-asset-fetch"}
SKIES = {  # 用途: (id, 解析度)
    "garden": ("garden_nook", "2k"),
    "meadow": ("dry_orchard_meadow", "2k"),
}
TEX = {  # 用途: id
    "soil": "forest_ground_04",
    "leaves": "leaves_forest_ground",
    "moss": "mossy_rock",
    "sand": "coast_sand_01",
    "concrete": "dirty_concrete",
    "pebbles": "clean_pebbles",
    "mud": "brown_mud_02",
}
MODELS = {  # 用途: id（1k 貼圖）
    "apple": "food_apple_01",
    "grass": "grass_medium_01",
    "grass2": "grass_medium_02",
    "dandelion": "dandelion_01",
    "fern": "fern_02",
    "flower": "flower_gazania",
    "moss": "moss_01",
    "rocks": "rock_moss_set_01",
    "moon_rock1": "moon_rock_01",
    "moon_rock3": "moon_rock_03",
    "moon_rock5": "moon_rock_05",
    "can": "can_rusted",
    "shell": "lambis_shell",
    "sea_rock": "coast_rocks_02",
    "pond_rock": "namaqualand_stones_01",
}
MAPS = {"diff": "Diffuse", "nor": "nor_gl", "rough": "Rough"}


def get(url):
    return urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=180).read()


def save(url, path):
    if os.path.exists(path):
        return
    os.makedirs(os.path.dirname(path), exist_ok=True)
    data = get(url)
    open(path, "wb").write(data)
    print("ok", os.path.relpath(path, ROOT), len(data) // 1024, "KB", flush=True)


def main():
    credits = []
    for name, (pid, res) in SKIES.items():
        info = json.loads(get("https://api.polyhaven.com/files/" + pid))
        save(info["hdri"][res]["hdr"]["url"], os.path.join(ROOT, "assets", "sky", name + ".hdr"))
        credits.append(pid)
    for name, pid in TEX.items():
        info = json.loads(get("https://api.polyhaven.com/files/" + pid))
        for short, key in MAPS.items():
            if key in info:
                save(info[key]["1k"]["jpg"]["url"], os.path.join(ROOT, "assets", "tex", f"{name}_{short}.jpg"))
        credits.append(pid)
    for name, pid in MODELS.items():
        info = json.loads(get("https://api.polyhaven.com/files/" + pid))
        g = info["gltf"]["1k"]["gltf"]
        d = os.path.join(ROOT, "assets", "models", name)
        save(g["url"], os.path.join(d, name + ".gltf"))
        # .gltf 檔名要跟著改：Godot 用檔名當資源名，內部參照的 .bin／貼圖保持原路徑
        for rel, inc in g.get("include", {}).items():
            save(inc["url"], os.path.join(d, rel))
        credits.append(pid)
    open(os.path.join(ROOT, "assets", "CREDITS-polyhaven.txt"), "w", encoding="utf8").write(
        "天空、材質與模型來自 Poly Haven（https://polyhaven.com），CC0 公眾領域授權：\n" + "\n".join(credits) + "\n")


if __name__ == "__main__":
    main()
