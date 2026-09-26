#!/usr/bin/env python3
"""Convert the Ordir logo SVG into SwiftUI Path code for OrdirMascotGeometry.

Usage: tools/svg_to_swift.py Assets/ordir-logo.svg

Handles the absolute M/L/C/Z commands the logo uses (with implicit repeats),
bakes in each path's transform plus the enclosing group translate, and emits:
  - `frame`: the static globe frame + pedestal, in viewBox coordinates
  - each sparkle re-centred on its bounding-box centre so it can rotate/scale in place
"""
import re
import sys
import xml.etree.ElementTree as ET

NS = "{http://www.w3.org/2000/svg}"
# Order of <path> elements in the source file -> role.
ROLES = ["outerSparkle", "tinySparkle", "mediumSparkle", "frame"]


def matrix(attr):
    """Parse matrix()/translate() into (a, b, c, d, e, f)."""
    if not attr:
        return (1, 0, 0, 1, 0, 0)
    nums = [float(n) for n in re.findall(r"-?\d*\.?\d+(?:e-?\d+)?", attr)]
    if attr.strip().startswith("translate"):
        return (1, 0, 0, 1, nums[0], nums[1] if len(nums) > 1 else 0)
    return tuple(nums)


def compose(outer, inner):
    a1, b1, c1, d1, e1, f1 = outer
    a2, b2, c2, d2, e2, f2 = inner
    return (a1 * a2 + c1 * b2, b1 * a2 + d1 * b2, a1 * c2 + c1 * d2,
            b1 * c2 + d1 * d2, a1 * e2 + c1 * f2 + e1, b1 * e2 + d1 * f2 + f1)


def parse(d, m):
    """Return a list of (cmd, [points]) with points already transformed."""
    a, b, c, dd, e, f = m
    tokens = re.findall(r"[MLCZmlcz]|-?\d*\.?\d+(?:e-?\d+)?", d)
    arity = {"M": 1, "L": 1, "C": 3}
    out, cmd, i = [], None, 0
    while i < len(tokens):
        t = tokens[i]
        if t.isalpha():
            if t.islower():
                sys.exit(f"relative command {t!r} not supported")
            cmd = t
            i += 1
            if cmd == "Z":
                out.append(("Z", []))
                continue
        n = arity[cmd] * 2
        vals = [float(v) for v in tokens[i:i + n]]
        i += n
        pts = [(a * x + c * y + e, b * x + dd * y + f) for x, y in zip(vals[0::2], vals[1::2])]
        out.append((cmd, pts))
        if cmd == "M":
            cmd = "L"  # implicit repeats after M are line-tos
    return out


def bounds(segs):
    xs = [p[0] for _, pts in segs for p in pts]
    ys = [p[1] for _, pts in segs for p in pts]
    return min(xs), min(ys), max(xs), max(ys)


def swift(segs, dx=0.0, dy=0.0, indent="        "):
    fmt = lambda p: f"CGPoint(x: {p[0] - dx:.3f}, y: {p[1] - dy:.3f})"
    lines = []
    for cmd, pts in segs:
        if cmd == "M":
            lines.append(f"p.move(to: {fmt(pts[0])})")
        elif cmd == "L":
            lines.append(f"p.addLine(to: {fmt(pts[0])})")
        elif cmd == "C":
            lines.append(f"p.addCurve(to: {fmt(pts[2])}, control1: {fmt(pts[0])}, control2: {fmt(pts[1])})")
        else:
            lines.append("p.closeSubpath()")
    return "\n".join(indent + l for l in lines)


def main(path):
    root = ET.parse(path).getroot()
    group = next(root.iter(NS + "g"))
    base = matrix(group.get("transform"))
    paths = list(root.iter(NS + "path"))
    assert len(paths) == len(ROLES), f"expected {len(ROLES)} paths, found {len(paths)}"
    for role, el in zip(ROLES, paths):
        segs = parse(el.get("d"), compose(base, matrix(el.get("transform"))))
        x0, y0, x1, y1 = bounds(segs)
        if role == "frame":
            print(f"    // {role}: bounds ({x0:.1f}, {y0:.1f}) – ({x1:.1f}, {y1:.1f})")
            print(f"    static let {role}: Path = {{\n        var p = Path()\n{swift(segs)}\n        return p\n    }}()\n")
        else:
            cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
            print(f"    // {role}: centre ({cx:.3f}, {cy:.3f}), size {x1 - x0:.1f}×{y1 - y0:.1f}")
            print(f"    static let {role}: Path = {{\n        var p = Path()\n{swift(segs, cx, cy)}\n        return p\n    }}()\n")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "Assets/ordir-logo.svg")
