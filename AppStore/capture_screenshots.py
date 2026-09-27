#!/usr/bin/env python3
"""Capture Just Nurikabe's App Store screenshots.

    python3 AppStore/capture_screenshots.py            # from the repo root

Builds Debug for the simulator, then for each device × appearance × scene
launches the app fresh with `-uiTestResetState -NurikabeScreenshotScene
<scene>` (DEBUG-only; the scene seeds its own state, so there are no tap
chains) and screenshots the simulator. Output is flattened to RGB and its
size asserted:

    AppStore/screenshots/iphone-65/NN-appearance-scene.png   1242×2688  APP_IPHONE_65
    AppStore/screenshots/ipad/NN-appearance-scene.png        2048×2732  APP_IPAD_PRO_3GEN_129

Names sort light first (01–05) then dark (06–10); ASC shows them in upload
order, and a set holds at most 10. Never use the 6.9" (APP_IPHONE_67) type:
the API accepts it but App Store Connect never displays it.
"""
import os, subprocess, sys, time
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BUNDLE = "de.kaikunze.nurikabe"
DERIVED = "/tmp/nurikabe-shots"
DEVICES = [
    ("iphone-65", "BCB6EC16-DCF7-4985-839A-A36B45E890F7", (1242, 2688)),   # iPhone 11 Pro Max, iOS 18.5
    ("ipad", "6BAA0686-A30B-45E5-9335-0B45466D8F7C", (2048, 2732)),        # iPad Pro 12.9" 6th gen, iOS 18.5
]
SCENES = ["hint", "lesson", "path", "home", "win"]   # teaching first
APPEARANCES = ["light", "dark"]


def run(*args, check=True):
    return subprocess.run(args, check=check, capture_output=True, text=True)


def build(udid):
    run("xcodebuild", "-project", os.path.join(ROOT, "Nurikabe.xcodeproj"), "-scheme", "Nurikabe",
        "-configuration", "Debug", "-destination", f"platform=iOS Simulator,id={udid}",
        "-derivedDataPath", DERIVED, "build")
    return os.path.join(DERIVED, "Build/Products/Debug-iphonesimulator/Nurikabe.app")


def main():
    problems = []
    for folder, udid, size in DEVICES:
        out = os.path.join(ROOT, "AppStore/screenshots", folder)
        os.makedirs(out, exist_ok=True)
        run("xcrun", "simctl", "boot", udid, check=False)
        run("xcrun", "simctl", "bootstatus", udid, "-b")
        app = build(udid)
        run("xcrun", "simctl", "install", udid, app)
        run("xcrun", "simctl", "status_bar", udid, "override", "--time", "9:41",
            "--batteryState", "charged", "--batteryLevel", "100",
            "--cellularMode", "active", "--cellularBars", "4", "--wifiBars", "3")
        n = 0
        for appearance in APPEARANCES:
            run("xcrun", "simctl", "ui", udid, "appearance", appearance)
            for scene in SCENES:
                n += 1
                run("xcrun", "simctl", "launch", "--terminate-running-process", udid, BUNDLE,
                    "-uiTestResetState", "-NurikabeScreenshotScene", scene)
                time.sleep(5)
                path = os.path.join(out, f"{n:02d}-{appearance}-{scene}.png")
                run("xcrun", "simctl", "io", udid, "screenshot", path)
                img = Image.open(path).convert("RGB")      # App Store art may not carry alpha
                img.save(path)
                if img.size != size:
                    problems.append(f"{path}: {img.size}, expected {size}")
                print(f"{folder}: {os.path.basename(path)} {img.size}")
        run("xcrun", "simctl", "ui", udid, "appearance", "light")
    for p in problems:
        print("PROBLEM", p)
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
