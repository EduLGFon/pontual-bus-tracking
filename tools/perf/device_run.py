#!/usr/bin/env python3
# Host driver for the on-device perf run. Installs the release APK,
# measures cold start three times, runs the profile integration test,
# and captures PSS plus screenshots when the test prints its markers.
# Usage: python3 device_run.py --apk <path-to-arm64-or-device-apk>
# Results go to tools/perf/results/<timestamp>.json (gitignored).
# See docs/ui/PERF.md and docs/ui/UI_SPEC.md 17.4.
import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import threading
import time
from datetime import datetime, timezone

PACKAGE = "com.spotnik.pontual/.MainActivity"
APP_ID = "com.spotnik.pontual"


def adb_bin():
    found = shutil.which("adb")
    if found:
        return found
    sdk = os.environ.get("ANDROID_SDK_ROOT", os.path.expanduser("~/Android/Sdk"))
    candidate = os.path.join(sdk, "platform-tools", "adb")
    if os.path.exists(candidate):
        return candidate
    return "adb"


ADB = adb_bin()


def flutter_bin():
    found = shutil.which("flutter")
    if found:
        return found
    candidate = os.path.expanduser("~/flutter/bin/flutter")
    if os.path.exists(candidate):
        return candidate
    return "flutter"


FLUTTER = flutter_bin()


def run(*args, capture=True, timeout=120):
    p = subprocess.run(
        list(args), capture_output=capture, text=True, timeout=timeout
    )
    return p.stdout if capture else ""


def wait_boot(timeout_s=900):
    run(ADB, "wait-for-device", capture=False)
    deadline = time.time() + timeout_s
    while time.time() < deadline:
        out = run(ADB, "shell", "getprop", "sys.boot_completed").strip()
        if out == "1":
            return
        time.sleep(5)
    raise TimeoutError("emulator did not boot in time")


def unlock():
    run(ADB, "shell", "wm", "dismiss-keyguard", capture=False)
    run(
        ADB,
        "shell",
        "settings",
        "put",
        "global",
        "stay_on_while_plugged_in",
        "3",
        capture=False,
    )


def wait_stopped(timeout_s=180):
    # pidof exits 1 with empty output when nothing runs. An adb error
    # also yields empty output, so only trust a clean exit-1 with no
    # stderr; anything else keeps waiting.
    deadline = time.time() + timeout_s
    while time.time() < deadline:
        p = subprocess.run(
            [ADB, "shell", "pidof", APP_ID],
            capture_output=True,
            text=True,
            timeout=60,
        )
        if p.returncode != 0 and not p.stderr.strip():
            time.sleep(5)
            return
        time.sleep(3)
    raise RuntimeError("app would not stop")


def cold_start_once(timeout_s=300):
    # am start -W never settles on software-emulated GPUs, so read the
    # system's own Displayed timing from logcat instead.
    run(ADB, "shell", "am", "force-stop", APP_ID, capture=False)
    wait_stopped()
    run(ADB, "logcat", "-c", capture=False)
    run(ADB, "shell", "am", "start", "-n", PACKAGE, capture=False)
    pat = re.compile(
        r"Displayed com\.spotnik\.pontual/\.MainActivity[^:]*: \+"
        r"(?:(\d+)s)?(\d+)ms"
    )
    deadline = time.time() + timeout_s
    while time.time() < deadline:
        out = run(ADB, "logcat", "-d")
        m = pat.search(out)
        if m:
            return int(m.group(1) or 0) * 1000 + int(m.group(2))
        time.sleep(3)
    raise RuntimeError("no Displayed line in logcat")


def pss_kb():
    out = run(ADB, "shell", "dumpsys", "meminfo", APP_ID)
    m = re.search(r"TOTAL\s+PSS:\s*([\d,]+)", out)
    if not m:
        raise RuntimeError("no TOTAL PSS in meminfo")
    return int(m.group(1).replace(",", ""))


def screencap(path):
    with open(path, "wb") as fh:
        subprocess.run(
            [ADB, "exec-out", "screencap", "-p"], stdout=fh, timeout=60
        )


def device_serial():
    out = run(ADB, "devices")
    for line in out.splitlines()[1:]:
        parts = line.split()
        if len(parts) == 2 and parts[1] == "device":
            return parts[0]
    raise RuntimeError("no online device")


def swipe_map(serial):
    # Four pans across the soak, 30 s apart. Coordinates fit a 1080x2400
    # phone; the map fills most of the line screen.
    for _ in range(4):
        run(
            ADB,
            "-s",
            serial,
            "shell",
            "input",
            "swipe",
            "800",
            "1000",
            "300",
            "1000",
            "400",
            capture=False,
        )
        time.sleep(30)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--apk", required=True)
    ap.add_argument("--out-dir", default=None)
    args = ap.parse_args()

    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    out_dir = args.out_dir or os.path.join(
        os.path.dirname(os.path.abspath(__file__)), "results", stamp
    )
    os.makedirs(out_dir, exist_ok=True)

    print("waiting for boot...", flush=True)
    wait_boot()
    unlock()
    print("installing...", flush=True)
    run(ADB, "install", "-r", args.apk, capture=False)

    cold = []
    for i in range(3):
        ms = cold_start_once()
        cold.append(ms)
        print(f"cold start run {i + 1}: {ms} ms", flush=True)
    run(ADB, "shell", "am", "force-stop", APP_ID, capture=False)

    mem = {}
    shots = {}
    stop = threading.Event()

    def watch():
        p = subprocess.Popen(
            [ADB, "logcat", "-v", "brief"],
            stdout=subprocess.PIPE,
            text=True,
        )
        assert p.stdout is not None
        for line in p.stdout:
            if "PERF_MARK HOME_MEM" in line:
                mem["home_pss_kb"] = pss_kb()
                shot = os.path.join(out_dir, "home.png")
                screencap(shot)
                shots["home"] = shot
                print(f"home PSS {mem['home_pss_kb']} KB", flush=True)
            elif "PERF_MARK LINE_SOAK" in line:
                sw = threading.Thread(
                    target=swipe_map, args=(serial,), daemon=True
                )
                sw.start()
                print("soak started, swiping", flush=True)
            elif "PERF_MARK LINE_MEM" in line:
                mem["line_pss_kb"] = pss_kb()
                shot = os.path.join(out_dir, "line.png")
                screencap(shot)
                shots["line"] = shot
                print(f"line PSS {mem['line_pss_kb']} KB", flush=True)
            elif "PERF_MARK DONE" in line:
                break
            if stop.is_set():
                break
        p.terminate()

    t = threading.Thread(target=watch, daemon=True)
    serial = device_serial()
    t.start()
    print(f"running profile app on {serial}...", flush=True)
    stdout_path = os.path.join(out_dir, "flutter-run.log")
    with open(stdout_path, "w") as log:
        proc = subprocess.Popen(
            [
                FLUTTER,
                "run",
                "--profile",
                "-t",
                "integration_test/perf_app.dart",
                "-d",
                serial,
            ],
            cwd=os.path.join(
                os.path.dirname(os.path.abspath(__file__)), "..", "..", "app"
            ),
            stdout=log,
            stderr=subprocess.STDOUT,
            text=True,
        )
        # The watcher breaks the loop on DONE; give it a bounded wait.
        t.join(timeout=1500)
        proc.terminate()
        try:
            proc.wait(timeout=60)
        except subprocess.TimeoutExpired:
            proc.kill()
    run(ADB, "shell", "am", "force-stop", APP_ID, capture=False)
    stop.set()
    with open(stdout_path) as log:
        test_output = log.read()
    print(test_output[-2000:], flush=True)

    timings = {}
    for m in re.finditer(r"PERF_TIMINGS (\w+) frames=(\d+) (.*)", test_output):
        timings[m.group(1)] = {"frames": int(m.group(2)), "rest": m.group(3)}

    def median(xs):
        s = sorted(xs)
        return s[len(s) // 2]

    results = {
        "device": run(ADB, "shell", "getprop", "ro.product.model").strip(),
        "cold_start_ms": cold,
        "cold_start_median_ms": median(cold),
        "mem": mem,
        "timings": timings,
        "shots": shots,
    }
    with open(os.path.join(out_dir, "results.json"), "w") as fh:
        json.dump(results, fh, indent=2)
    print(json.dumps(results, indent=2))


if __name__ == "__main__":
    sys.exit(main())
