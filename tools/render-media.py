#!/usr/bin/env python3
"""Render SCREEN-CAP-*.txt/.map frame pairs to PNG (and a GIF) for docs/media.

Reads the player-eye transcripts dumped by playtest/capture-media.el plus
their face-code sidecars, colors each cell from the CISTERN face palette
(cistern-view.el semantics: hazard red, tanks amber, pipes cyan, dim UI),
and emits an SVG per frame. ImageMagick rasterizes and animates.
"""
import subprocess
import sys
from pathlib import Path

PLAYTEST = Path(__file__).resolve().parent.parent / "playtest"
OUT = PLAYTEST / "frames"

CELL_W, CELL_H, FONT = 9, 16, 14
BG = "#0d110c"

PALETTE = {
    "d": ("#d8e8c0", True),   # header
    "i": ("#5a6a52", False),  # dim UI
    "u": ("#e8d890", True),   # tutorial
    "w": ("#d9d9a0", False),  # comedy
    "W": ("#43603e", False),  # wall
    ".": ("#6a7f66", False),  # floor
    "D": ("#c9b458", False),  # door
    "O": ("#b8d078", False),  # ore
    "P": ("#6fb3d9", False),  # pipe live
    "p": ("#3f5560", False),  # pipe dead
    "T": ("#7fd0c0", True),   # toilet
    "B": ("#d9c46f", True),   # toilet busy
    "U": ("#d96f6f", True),   # toilet down
    "t": ("#9fd07f", False),  # tank ok
    "h": ("#d9c46f", False),  # tank high
    "F": ("#d95f5f", True),   # tank full
    "H": ("#d95555", True),   # hazard / contamination / backed-up
    "A": ("#e8e8d0", True),   # worker
    "S": ("#d9a05f", True),   # worker sick
    "M": ("#6fb3d9", True),   # manifold
    "R": ("#7a6a5a", False),  # rubble
    "L": ("#6fa0d9", False),  # flood
    "E": ("#d9806f", False),  # event marker
    "G": ("#c07fd9", True),   # goblin
    "Y": ("#d9c07f", True),   # pest
    "c": ("#b8d078", False),  # cache
    "C": ("#e8ffc0", True),   # cursor (inverse)
    "?": ("#6a7f66", False),  # unknown face
}
HEX = {c: (f"#999999", False) for c in "0123456789"}  # unused


def esc(ch):
    return ch.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def render(txt_path, map_path, svg_path):
    lines = txt_path.read_text().rstrip("\n").split("\n")
    codes = map_path.read_text().rstrip("\n").split("\n")
    w = max(max((len(l) for l in lines), default=0),
            max((len(c) for c in codes), default=0))
    h = len(lines)
    parts = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{w*CELL_W}" '
        f'height="{h*CELL_H}" viewBox="0 0 {w*CELL_W} {h*CELL_H}">',
        f'<rect width="100%" height="100%" fill="{BG}"/>',
        f'<g font-family="DejaVu Sans Mono, monospace" font-size="{FONT}" '
        f'xml:space="preserve">',
    ]
    for y, (line, code) in enumerate(zip(lines, codes)):
        run_char, run_code, x0 = None, None, 0
        for x in range(w):
            ch = line[x] if x < len(line) else " "
            cd = code[x] if x < len(code) else "?"
            cd = cd if cd in PALETTE else "?"
            if (ch, cd) != (run_char, run_code):
                if run_char is not None and run_char != " ":
                    fg, bold = PALETTE[run_code]
                    parts.append(
                        f'<text x="{x0*CELL_W}" y="{(y+1)*CELL_H-3}" fill="{fg}"'
                        f'{" font-weight=" + chr(34) + "bold" + chr(34) if bold else ""}>{esc(run_char)}</text>')
                run_char, run_code, x0 = ch, cd, x
        if run_char is not None and run_char != " ":
            fg, bold = PALETTE[run_code]
            parts.append(
                f'<text x="{x0*CELL_W}" y="{(y+1)*CELL_H-3}" fill="{fg}"'
                f'{" font-weight=" + chr(34) + "bold" + chr(34) if bold else ""}>{esc(run_char)}</text>')
    parts.append("</g></svg>")
    svg_path.write_text("\n".join(parts))


def main():
    OUT.mkdir(exist_ok=True)
    frames = sorted(PLAYTEST.glob("SCREEN-CAP-*.txt"))
    pngs = []
    for txt in frames:
        mp = txt.with_suffix(".map")
        svg = OUT / (txt.stem + ".svg")
        png = OUT / (txt.stem + ".png")
        render(txt, mp, svg)
        r = subprocess.run(["magick", "-background", BG, str(svg), str(png)],
                           capture_output=True, text=True)
        if r.returncode:
            sys.exit(f"magick failed on {svg}: {r.stderr}")
        pngs.append(png)
    gif = OUT / "cistern-demo.gif"
    r = subprocess.run(
        ["magick", "-delay", "80", "-loop", "0"] + [str(p) for p in pngs] + [str(gif)],
        capture_output=True, text=True)
    if r.returncode:
        sys.exit(f"gif failed: {r.stderr}")
    print("frames:", *[f"{p.name} {p.stat().st_size}" for p in pngs], sep="\n  ")
    print("gif:", gif.stat().st_size)


if __name__ == "__main__":
    main()