// 眼動鼠之賽車：線上版的攝影機眼動追蹤（瀏覽器內執行，影像不上傳）。
// 與電腦版 EyeCam 輸出相同格式（ir/bs/hp/dist/nose），由 Godot 的 EyeCam 以 JavaScriptBridge 讀取。
(function () {
  if (window.__ec) return;
  const VER = "1.2.3";
  const CDN = "https://cdn.jsdelivr.net/npm/@mediapipe/tasks-vision@" + VER;
  const EYE_A = [33, 133, 159, 145];
  const EYE_B = [263, 362, 386, 374];
  const IRIS_1 = 468, IRIS_2 = 473, NOSE = 1;
  const BS = ["eyeLookInLeft", "eyeLookOutLeft", "eyeLookUpLeft", "eyeLookDownLeft",
    "eyeLookInRight", "eyeLookOutRight", "eyeLookUpRight", "eyeLookDownRight", "eyeBlinkLeft", "eyeBlinkRight"];
  const ec = window.__ec = { status: "off", latest: "", seq: 0, lastSeq: 0, preview: "", previewOn: false, fps: 0, err: "" };
  const r4 = (x) => Math.round(x * 10000) / 10000;

  function eyeFeat(lm, eye, irs) {
    const o = lm[eye[0]], i = lm[eye[1]], u = lm[eye[2]], d = lm[eye[3]];
    const ax = i.x - o.x, ay = i.y - o.y;
    const L = Math.hypot(ax, ay) + 1e-9;
    const ux = ax / L, uy = ay / L;
    const cx = (o.x + i.x) / 2, cy = (o.y + i.y) / 2;
    const c = irs.reduce((best, p) => ((p.x - cx) ** 2 + (p.y - cy) ** 2 < (best.x - cx) ** 2 + (best.y - cy) ** 2 ? p : best));
    const h = ((c.x - o.x) * ux + (c.y - o.y) * uy) / L;
    const v = (c.y - (u.y + d.y) / 2) / L;
    return [h, v, Math.abs(d.y - u.y) / L];
  }

  function headPose(m) {
    const d = m.data;
    // 平移量（公分，約 -30～-90）在 data[14] 表示欄優先，在 data[11] 表示列優先
    const colMajor = Math.abs(d[14]) > Math.abs(d[11]);
    const g = colMajor ? (r, c) => d[c * 4 + r] : (r, c) => d[r * 4 + c];
    const yaw = Math.atan2(-g(2, 0), Math.hypot(g(2, 1), g(2, 2))) * 180 / Math.PI;
    const pitch = Math.atan2(g(2, 1), g(2, 2)) * 180 / Math.PI;
    const roll = Math.atan2(g(1, 0), g(0, 0)) * 180 / Math.PI;
    return [yaw, pitch, roll, -g(2, 3)];
  }

  ec.start = async function () {
    if (ec.status === "ok" || ec.status === "starting") return;
    ec.status = "starting";
    try {
      const vision = await import(CDN + "/vision_bundle.mjs");
      const fs = await vision.FilesetResolver.forVisionTasks(CDN + "/wasm");
      const opts = (delegate) => ({
        baseOptions: { modelAssetPath: "face_landmarker.task", delegate },
        runningMode: "VIDEO", numFaces: 1, outputFaceBlendshapes: true, outputFacialTransformationMatrixes: true,
      });
      try { ec.lmk = await vision.FaceLandmarker.createFromOptions(fs, opts("GPU")); }
      catch (e) { ec.lmk = await vision.FaceLandmarker.createFromOptions(fs, opts("CPU")); }
    } catch (e) { ec.status = "error"; ec.err = String(e); return; }
    try {
      ec.stream = await navigator.mediaDevices.getUserMedia({ video: { width: 640, height: 480, facingMode: "user" }, audio: false });
    } catch (e) { ec.status = "nocam"; ec.err = String(e); return; }
    const v = ec.video = document.createElement("video");
    v.playsInline = true; v.muted = true; v.srcObject = ec.stream;
    await v.play();
    ec.canvas = document.createElement("canvas");
    ec.canvas.width = 192; ec.canvas.height = 144;
    ec.running = true;
    ec.status = "ok";
    let lastT = -1, n = 0, fpsT = performance.now(), fpsN = 0, lastRun = 0;
    const loop = () => {
      if (!ec.running) return;
      requestAnimationFrame(loop);
      const now = performance.now();
      if (now - lastRun < 30 || v.currentTime === lastT || v.readyState < 2) return;
      lastRun = now; lastT = v.currentTime;
      let res;
      try { res = ec.lmk.detectForVideo(v, now); } catch (e) { return; }
      n++; fpsN++;
      if (now - fpsT > 1000) { ec.fps = fpsN * 1000 / (now - fpsT); fpsT = now; fpsN = 0; }
      const out = { t: Date.now() / 1000, face: 0, fps: Math.round(ec.fps * 10) / 10, w: v.videoWidth, h: v.videoHeight };
      const lm = res.faceLandmarks && res.faceLandmarks[0];
      if (lm) {
        const irs = [lm[IRIS_1], lm[IRIS_2]];
        const a = eyeFeat(lm, EYE_A, irs), b = eyeFeat(lm, EYE_B, irs);
        const bs = {};
        if (res.faceBlendshapes && res.faceBlendshapes[0]) for (const c of res.faceBlendshapes[0].categories) bs[c.categoryName] = c.score;
        let hp = [0, 0, 0, 0];
        if (res.facialTransformationMatrixes && res.facialTransformationMatrixes[0]) hp = headPose(res.facialTransformationMatrixes[0]);
        out.face = 1;
        out.ir = [r4(a[0]), r4(a[1]), r4(b[0]), r4(b[1])];
        out.open = r4((a[2] + b[2]) / 2);
        out.bs = BS.map((k) => r4(bs[k] || 0));
        out.hp = [Math.round(hp[0] * 100) / 100, Math.round(hp[1] * 100) / 100, Math.round(hp[2] * 100) / 100];
        out.dist = Math.round(hp[3] * 10) / 10;
        out.nose = [r4(lm[NOSE].x), r4(lm[NOSE].y)];
      }
      ec.latest = JSON.stringify(out);
      ec.seq++;
      if (ec.previewOn && n % 4 === 0) {
        const cx = ec.canvas.getContext("2d");
        cx.save(); cx.translate(192, 0); cx.scale(-1, 1); cx.drawImage(v, 0, 0, 192, 144); cx.restore();
        if (lm) {
          for (const k of [IRIS_1, IRIS_2, NOSE, ...EYE_A, ...EYE_B]) {
            cx.fillStyle = (k === IRIS_1 || k === IRIS_2) ? "#ff7890" : "#78e6ff";
            cx.beginPath(); cx.arc((1 - lm[k].x) * 192, lm[k].y * 144, 2, 0, Math.PI * 2); cx.fill();
          }
        }
        ec.preview = ec.canvas.toDataURL("image/jpeg", 0.7).split(",")[1];
      }
    };
    requestAnimationFrame(loop);
  };

  ec.pop = function () {
    if (ec.seq === ec.lastSeq) return "";
    ec.lastSeq = ec.seq;
    return ec.latest;
  };
  ec.popPreview = function () { const p = ec.preview; ec.preview = ""; return p; };
  ec.stop = function () {
    ec.running = false;
    if (ec.stream) ec.stream.getTracks().forEach((t) => t.stop());
    ec.stream = null;
    if (ec.status !== "error") ec.status = "off";
  };
  window.addEventListener("pagehide", () => ec.stop());
})();
