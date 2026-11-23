"""EyeCam：眼動鼠之賽車的網路攝影機眼動追蹤小程式（由遊戲自動啟動、遊戲關閉就自動結束）。

流程（參考 UnitEye 的觀念，程式為原創）：
  網路攝影機 → MediaPipe Face Landmarker（478 點含虹膜＋52 個表情係數＋頭部姿勢）
  → 原始特徵（虹膜在眼眶中的位置、eyeLook 係數、頭部偏航／俯仰／翻滾、鼻尖、距離、眨眼）
  → 以 JSON 行經 127.0.0.1 TCP 送給遊戲。
校正（嶺迴歸）、濾波（One Euro）、興趣區（AOI）都在遊戲裡做，這裡只負責「看」。

用法：EyeCam.exe --port 47971 --parent <遊戲 PID> [--camera 0] [--selftest]
"""
import base64
import json
import math
import os
import socket
import sys
import threading
import time

VERSION = "1.0.0"


def resource_path(*p):
    base = getattr(sys, "_MEIPASS", os.path.dirname(os.path.abspath(__file__)))
    return os.path.join(base, *p)


# 眼睛關鍵點（MediaPipe 478 點）：以「影像」左右命名，避免受試者左右混淆
EYE_A = (33, 133, 159, 145)     # 外角、內角、上、下（影像左側那隻眼）
EYE_B = (263, 362, 386, 374)    # 外角、內角、上、下（影像右側那隻眼）
IRIS_1, IRIS_2 = 468, 473
NOSE = 1
BS_NAMES = ["eyeLookInLeft", "eyeLookOutLeft", "eyeLookUpLeft", "eyeLookDownLeft",
            "eyeLookInRight", "eyeLookOutRight", "eyeLookUpRight", "eyeLookDownRight",
            "eyeBlinkLeft", "eyeBlinkRight"]


def parent_alive(pid):
    if not pid:
        return True
    if sys.platform == "win32":
        import ctypes
        k = ctypes.windll.kernel32
        h = k.OpenProcess(0x1000, False, pid)   # PROCESS_QUERY_LIMITED_INFORMATION
        if not h:
            return False
        code = ctypes.c_ulong()
        ok = k.GetExitCodeProcess(h, ctypes.byref(code))
        k.CloseHandle(h)
        return bool(ok) and code.value == 259    # STILL_ACTIVE
    try:
        os.kill(pid, 0)
        return True
    except OSError:
        return False


def eye_feat(lm, eye, iris_pts):
    """回傳 (水平, 垂直, 張開度)；水平 0=外角 1=內角（以影像座標），垂直以眼寬為單位。"""
    o, i, u, d = (lm[k] for k in eye)
    ax, ay = i.x - o.x, i.y - o.y
    L = math.hypot(ax, ay) + 1e-9
    ux, uy = ax / L, ay / L
    cx, cy = (o.x + i.x) / 2, (o.y + i.y) / 2
    # 兩個虹膜中心挑離這隻眼睛中心最近的（MediaPipe 虹膜與眼角的命名慣例不同，用距離配對最保險）
    c = min(iris_pts, key=lambda p: (p.x - cx) ** 2 + (p.y - cy) ** 2)
    h = ((c.x - o.x) * ux + (c.y - o.y) * uy) / L
    mid_y = (u.y + d.y) / 2
    v = (c.y - mid_y) / L
    open_ = abs(d.y - u.y) / L
    return float(h), float(v), float(open_)


def head_pose(mat):
    mat = [[float(mat[r][c]) for c in range(4)] for r in range(4)]
    R = [[mat[r][c] for c in range(3)] for r in range(3)]
    yaw = math.degrees(math.atan2(-R[2][0], math.hypot(R[2][1], R[2][2])))
    pitch = math.degrees(math.atan2(R[2][1], R[2][2]))
    roll = math.degrees(math.atan2(R[1][0], R[0][0]))
    tz = -mat[2][3]   # 公分（MediaPipe 臉部座標以公分計）
    return yaw, pitch, roll, tz


class Tracker:
    def __init__(self, camera=0):
        self.camera = camera
        self.want_camera = camera
        self.running = True
        self.status = "starting"
        self.fps = 0.0
        self.latest = None        # 最新一筆特徵 dict
        self.seq = 0
        self.preview_on = False
        self.preview = None       # base64 JPEG
        self.lock = threading.Lock()

    def run(self):
        try:
            import cv2
            import numpy as np  # noqa: F401
            import mediapipe as mp
            from mediapipe.tasks import python as mpt
            from mediapipe.tasks.python import vision
        except Exception as e:  # 缺元件
            self.status = f"error:元件載入失敗 {e}"
            return
        try:
            with open(resource_path("face_landmarker.task"), "rb") as f:
                buf = f.read()
            opts = vision.FaceLandmarkerOptions(
                base_options=mpt.BaseOptions(model_asset_buffer=buf),
                running_mode=vision.RunningMode.VIDEO, num_faces=1,
                output_facial_transformation_matrixes=True, output_face_blendshapes=True)
            lmk = vision.FaceLandmarker.create_from_options(opts)
        except Exception as e:
            self.status = f"error:臉部模型載入失敗 {e}"
            return
        api = cv2.CAP_DSHOW if sys.platform == "win32" else (cv2.CAP_AVFOUNDATION if sys.platform == "darwin" else cv2.CAP_ANY)
        cap = None
        t0 = time.monotonic()
        last_ts = 0
        n = 0
        fps_t, fps_n = time.monotonic(), 0
        while self.running:
            if cap is None or self.want_camera != self.camera:
                if cap is not None:
                    cap.release()
                self.camera = self.want_camera
                cap = cv2.VideoCapture(self.camera, api)
                if not cap.isOpened():
                    cap.release()
                    cap = cv2.VideoCapture(self.camera)
                if not cap.isOpened():
                    cap.release()
                    cap = None
                    self.status = "nocam"
                    time.sleep(2.0)
                    continue
                cap.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
                cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)
                self.status = "ok"
            ok, frame = cap.read()
            if not ok:
                self.status = "nocam"
                time.sleep(0.05)
                continue
            rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
            ts = int((time.monotonic() - t0) * 1000)
            if ts <= last_ts:
                ts = last_ts + 1
            last_ts = ts
            try:
                res = lmk.detect_for_video(mp.Image(image_format=mp.ImageFormat.SRGB, data=rgb), ts)
            except Exception:
                continue
            n += 1
            fps_n += 1
            if time.monotonic() - fps_t > 1.0:
                self.fps = fps_n / (time.monotonic() - fps_t)
                fps_t, fps_n = time.monotonic(), 0
            out = {"t": round(time.time(), 3), "face": 0, "fps": round(self.fps, 1), "w": frame.shape[1], "h": frame.shape[0]}
            if res.face_landmarks:
                lm = res.face_landmarks[0]
                irs = [lm[IRIS_1], lm[IRIS_2]]
                ah, av, ao = eye_feat(lm, EYE_A, irs)
                bh, bv, bo = eye_feat(lm, EYE_B, irs)
                bs = {}
                if res.face_blendshapes:
                    for b in res.face_blendshapes[0]:
                        bs[b.category_name] = float(b.score)
                yaw = pitch = roll = 0.0
                tz = 0.0
                if res.facial_transformation_matrixes:
                    yaw, pitch, roll, tz = head_pose(res.facial_transformation_matrixes[0])
                out.update({
                    "face": 1,
                    # 虹膜：影像左眼 (h,v)、影像右眼 (h,v)；h 以外角→內角為正，所以兩眼方向相反，遊戲端會換算
                    "ir": [round(ah, 4), round(av, 4), round(bh, 4), round(bv, 4)],
                    "open": round((ao + bo) / 2, 4),
                    "bs": [round(bs.get(k, 0.0), 4) for k in BS_NAMES],
                    "hp": [round(yaw, 2), round(pitch, 2), round(roll, 2)],
                    "dist": round(tz, 1),
                    "nose": [round(float(lm[NOSE].x), 4), round(float(lm[NOSE].y), 4)],
                })
            with self.lock:
                self.seq += 1
                self.latest = out
            if self.preview_on and n % 4 == 0:
                small = cv2.resize(frame, (192, 144))
                small = cv2.flip(small, 1)
                if res.face_landmarks:
                    lm = res.face_landmarks[0]
                    for k in (IRIS_1, IRIS_2, NOSE) + EYE_A + EYE_B:
                        cv2.circle(small, (int((1 - lm[k].x) * 192), int(lm[k].y * 144)), 2,
                                   (255, 120, 140) if k in (IRIS_1, IRIS_2) else (120, 230, 255), -1)
                ok2, jpg = cv2.imencode(".jpg", small, [cv2.IMWRITE_JPEG_QUALITY, 70])
                if ok2:
                    with self.lock:
                        self.preview = base64.b64encode(jpg.tobytes()).decode("ascii")
        if cap is not None:
            cap.release()
        lmk.close()


def list_cameras():
    import cv2
    api = cv2.CAP_DSHOW if sys.platform == "win32" else cv2.CAP_ANY
    out = []
    for i in range(4):
        c = cv2.VideoCapture(i, api)
        if c.isOpened():
            out.append(i)
        c.release()
    return out


def serve(port, parent, camera):
    tr = Tracker(camera)
    srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    try:
        srv.bind(("127.0.0.1", port))
    except OSError:
        print("port busy", flush=True)
        return 2
    srv.listen(1)
    if sys.platform == "darwin":
        # macOS：相機權限詢問只能在主執行緒跑（OpenCV 在背景執行緒無法跳出詢問視窗）→ 先在主執行緒開一次相機
        try:
            import cv2
            c = cv2.VideoCapture(camera, cv2.CAP_AVFOUNDATION)
            c.release()
        except Exception:
            pass
        os.environ["OPENCV_AVFOUNDATION_SKIP_AUTH"] = "1"
    th = threading.Thread(target=tr.run, daemon=True)
    th.start()
    srv.settimeout(1.0)
    started = time.monotonic()
    last_client = time.monotonic()
    while tr.running:
        if not parent_alive(parent):
            break
        if time.monotonic() - last_client > (60 if time.monotonic() - started < 90 else 20):
            break   # 沒有遊戲連線就自己結束
        try:
            conn, _ = srv.accept()
        except socket.timeout:
            continue
        conn.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
        conn.settimeout(0.005)
        buf = b""
        sent_seq = 0
        last_status = ""
        last_prev = None
        try:
            conn.sendall((json.dumps({"ev": "hello", "version": VERSION}) + "\n").encode())
            while tr.running and parent_alive(parent):
                last_client = time.monotonic()
                try:
                    d = conn.recv(4096)
                    if not d:
                        break
                    buf += d
                    while b"\n" in buf:
                        line, buf = buf.split(b"\n", 1)
                        try:
                            m = json.loads(line.decode("utf-8"))
                        except Exception:
                            continue
                        cmd = m.get("cmd")
                        if cmd == "quit":
                            tr.running = False
                        elif cmd == "preview":
                            tr.preview_on = bool(m.get("on"))
                        elif cmd == "camera":
                            tr.want_camera = int(m.get("index", 0))
                        elif cmd == "cameras":
                            conn.sendall((json.dumps({"ev": "cameras", "list": list_cameras()}) + "\n").encode())
                except socket.timeout:
                    pass
                with tr.lock:
                    seq, latest, prev = tr.seq, tr.latest, tr.preview
                if tr.status != last_status:
                    last_status = tr.status
                    conn.sendall((json.dumps({"ev": "status", "status": tr.status, "camera": tr.camera}) + "\n").encode())
                if seq != sent_seq and latest is not None:
                    sent_seq = seq
                    try:
                        line = json.dumps(latest, separators=(",", ":"), default=float)
                    except (TypeError, ValueError):
                        line = json.dumps({"t": latest.get("t", 0), "face": 0})
                    conn.sendall((line + "\n").encode())
                if tr.preview_on and prev is not None and prev is not last_prev:
                    last_prev = prev
                    conn.sendall((json.dumps({"ev": "preview", "jpg": prev}) + "\n").encode())
                time.sleep(0.008)
        except OSError:
            pass
        finally:
            try:
                conn.close()
            except OSError:
                pass
            tr.preview_on = False
    tr.running = False
    th.join(timeout=3)
    return 0


def selftest(out_path):
    lines = []
    ok = True
    try:
        import cv2  # noqa: F401
        import mediapipe  # noqa: F401
        lines.append("import ok")
        from mediapipe.tasks import python as mpt
        from mediapipe.tasks.python import vision
        with open(resource_path("face_landmarker.task"), "rb") as f:
            buf = f.read()
        vision.FaceLandmarker.create_from_options(vision.FaceLandmarkerOptions(
            base_options=mpt.BaseOptions(model_asset_buffer=buf), running_mode=vision.RunningMode.IMAGE,
            output_face_blendshapes=True)).close()
        lines.append("model ok")
    except Exception as e:
        ok = False
        lines.append(f"FAIL {e}")
    lines.append("SELFTEST OK" if ok else "SELFTEST FAIL")
    txt = "\n".join(lines)
    if out_path:
        with open(out_path, "w", encoding="utf-8") as f:
            f.write(txt)
    print(txt, flush=True)
    return 0 if ok else 1


def main():
    args = sys.argv[1:]

    def opt(name, default):
        for a in args:
            if a.startswith(f"--{name}="):
                return a.split("=", 1)[1]
        if f"--{name}" in args:
            i = args.index(f"--{name}")
            if i + 1 < len(args):
                return args[i + 1]
        return default

    if "--selftest" in args:
        return selftest(opt("out", ""))
    return serve(int(opt("port", 47971)), int(opt("parent", 0)), int(opt("camera", 0)))


if __name__ == "__main__":
    sys.exit(main())
