#!/usr/bin/env python3
"""Run isolated Godot suites; default execution never opens a window."""
import argparse
import math
import os
from pathlib import Path
import re
import shutil
import signal
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
ERROR = re.compile(r"SCRIPT ERROR:|(?:^|\n)\s*(?:ERROR:|FATAL:)")


def find_engine(requested=None):
    if requested:
        path = Path(requested).expanduser()
        if path.suffix == ".app":
            path /= "Contents/MacOS/Godot"
        return shutil.which(str(path))
    for name in ("godot", "godot4", "godot-mono"):
        engine = shutil.which(name)
        if engine:
            return engine
    if sys.platform == "darwin":
        for bundle in (Path("/Applications/Godot.app"), Path.home() / "Applications/Godot.app"):
            engine = find_engine(str(bundle))
            if engine:
                return engine
    return None


def stop_process(process):
    if process.poll() is None:
        if os.name == "nt":
            # Kill the process tree, including editor/import children, on Windows.
            subprocess.run(["taskkill", "/PID", str(process.pid), "/T", "/F"],
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                           creationflags=subprocess.CREATE_NO_WINDOW, check=False)
        else:
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
        if process.poll() is None:
            process.kill()
    process.wait()


def run(command, log, timeout, require_pass=True):
    started = time.monotonic()
    timed_out = False
    with log.open("w") as output:
        options = ({"creationflags": subprocess.CREATE_NEW_PROCESS_GROUP}
                   if os.name == "nt" else {"start_new_session": True})
        try:
            process = subprocess.Popen(
                command, cwd=ROOT, stdout=output, stderr=subprocess.STDOUT, **options,
            )
        except OSError as error:
            print(f"FAIL {log.stem}: cannot launch {command[0]}: {error}", flush=True)
            return False
        try:
            process.wait(timeout=timeout)
        except (subprocess.TimeoutExpired, KeyboardInterrupt) as error:
            stop_process(process)
            if isinstance(error, KeyboardInterrupt):
                raise
            timed_out = True
    contents = log.read_text(errors="replace")
    passed = (
        not timed_out and process.returncode == 0 and not ERROR.search(contents)
        and (not require_pass or re.search(r"^PASS:", contents, re.MULTILINE))
    )
    label = "PASS" if passed else "TIMEOUT" if timed_out else "FAIL"
    print(f"{label} {log.stem} ({time.monotonic() - started:.1f}s)", flush=True)
    if not passed:
        print("\n".join(contents.splitlines()[-35:]))
        print(f"Full log: {log.relative_to(ROOT)}", flush=True)
    return bool(passed)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("group", nargs="?", default="headless",
                        choices=["fast", "integration", "headless", "visual", "all"])
    parser.add_argument("--godot", default=os.environ.get("GODOT_BIN"),
                        help="Godot executable (or set GODOT_BIN)")
    parser.add_argument("--timeout", type=float, default=60,
                        help="Maximum seconds per suite and import (default: 60)")
    args = parser.parse_args()
    if not math.isfinite(args.timeout) or args.timeout <= 0:
        parser.error("--timeout must be finite and positive")
    engine = find_engine(args.godot)
    if not engine:
        parser.error("Godot executable not found; add it to PATH or set --godot / GODOT_BIN")
    print(f"Godot: {engine}", flush=True)
    groups = {
        "fast": ["unit"], "integration": ["integration"],
        "headless": ["unit", "integration"], "visual": ["visual"],
        "all": ["unit", "integration", "visual"],
    }[args.group]
    logs = ROOT / "artifacts" / "tests"
    logs.mkdir(parents=True, exist_ok=True)
    base = [engine, "--path", str(ROOT)]
    # Register global classes and import assets, including on a clean checkout.
    if not run(base + ["--headless", "--editor", "--import", "--quit"],
               logs / "import.log", args.timeout, require_pass=False):
        return 1
    suites = [(group, path) for group in groups
              for path in sorted((ROOT / "tests" / group).glob("test_*.gd"))]
    failures = 0
    for group, path in suites:
        command = base + ([] if group == "visual" else ["--headless"])
        command += ["--audio-driver", "Dummy", "--script",
                    "res://" + path.relative_to(ROOT).as_posix()]
        failures += not run(command, logs / f"{group}-{path.stem}.log", args.timeout)
    print(f"{len(suites) - failures}/{len(suites)} suites passed. Logs: artifacts/tests/")
    return int(failures > 0)


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        sys.exit(130)
