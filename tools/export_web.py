#!/usr/bin/env python3
"""Build a portable static web export with browser-decompressed WASM."""
import argparse
import gzip
from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "build" / "web"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default="godot", help="Godot executable with matching export templates")
    args = parser.parse_args()
    if not shutil.which(args.godot):
        parser.error(f"Godot executable not found: {args.godot}")
    # Clean only web output, keeping build/.gdignore and other export targets.
    if OUTPUT.exists():
        shutil.rmtree(OUTPUT)
    OUTPUT.mkdir(parents=True)
    subprocess.run([args.godot, "--headless", "--path", str(ROOT), "--editor", "--import"], check=True)
    subprocess.run([args.godot, "--headless", "--path", str(ROOT), "--export-release", "Web", str(OUTPUT / "index.html")], check=True)
    wasm = OUTPUT / "index.wasm"
    original = wasm.read_bytes()
    compressed = gzip.compress(original, compresslevel=9, mtime=0)
    wasm.with_suffix(".wasm.gz").write_bytes(compressed)
    wasm.unlink()
    shutil.copyfile(ROOT / "tools" / "web" / "wasm-loader.js", OUTPUT / "wasm-loader.js")
    html = OUTPUT / "index.html"
    source = html.read_text(encoding="utf-8")
    if source.count("</head>") != 1:
        raise SystemExit("Unexpected Godot HTML shell: missing unique </head>")
    html.write_text(source.replace("</head>", '<script src="wasm-loader.js"></script>\n</head>'), encoding="utf-8")
    print(f"WASM: {len(original) / 1024**2:.1f} MiB -> {len(compressed) / 1024**2:.1f} MiB gzip")
    print(f"Web upload folder: {OUTPUT}")
    print("Preview with: python3 -m http.server 8000 --directory build/web")


if __name__ == "__main__":
    main()
