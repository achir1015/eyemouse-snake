# PyInstaller：python -m PyInstaller eyecam/EyeCam.spec --noconfirm --distpath ../build/eyecam --workpath ../build/eyecam-work
import sys
from PyInstaller.utils.hooks import collect_data_files, collect_dynamic_libs

datas = [("face_landmarker.task", ".")]
datas += collect_data_files("mediapipe", includes=["**/*.binarypb", "**/*.tflite", "**/*.txt"])
binaries = collect_dynamic_libs("mediapipe")

a = Analysis(["eyecam.py"], pathex=["."], binaries=binaries, datas=datas, hiddenimports=[],
             excludes=["tkinter", "PySide6", "PyQt5", "torch", "tensorflow", "jax", "pandas", "scipy", "IPython"],
             noarchive=False)
pyz = PYZ(a.pure)
exe = EXE(pyz, a.scripts, [], exclude_binaries=True, name="EyeCam", console=False)
coll = COLLECT(exe, a.binaries, a.datas, name="EyeCam")
