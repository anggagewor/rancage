#!/usr/bin/env python3
"""
Generate Rancage app icon (1024x1024).

Apple macOS icon guidelines:
- 1024x1024 square canvas, NO rounded corners (system applies squircle mask)
- Content centered with padding (~100px visual inset from mask edges)
- Simple, recognizable at 16x16
- No text, no emoji

Design: Gauge/speedometer arc with needle + small coffee cup accent.
Rendered at 2x then downscaled for anti-aliasing.
"""

import math
import sys
from PIL import Image, ImageDraw, ImageFilter

RENDER_SIZE = 2048  # Render at 2x for anti-aliasing
OUTPUT_SIZE = 1024
CENTER = RENDER_SIZE // 2
S = RENDER_SIZE / 1024.0  # Scale factor


def lerp_color(c1, c2, t):
    return tuple(int(c1[i] + (c2[i] - c1[i]) * t) for i in range(3))


def main():
    img = Image.new("RGBA", (RENDER_SIZE, RENDER_SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # === Background (full square, system applies mask) ===
    draw.rectangle([0, 0, RENDER_SIZE, RENDER_SIZE], fill=(20, 22, 28, 255))

    # === Gauge parameters ===
    gauge_cy = int(CENTER + 40 * S)
    gauge_cx = CENTER
    gauge_radius = int(300 * S)
    arc_width = int(36 * S)
    start_angle = 220  # math degrees (lower-left)
    total_sweep = 260  # total arc span

    # --- Background track ---
    track_bbox = [
        gauge_cx - gauge_radius - arc_width // 2,
        gauge_cy - gauge_radius - arc_width // 2,
        gauge_cx + gauge_radius + arc_width // 2,
        gauge_cy + gauge_radius + arc_width // 2,
    ]
    # PIL arc: 0° = 3 o'clock, clockwise. Convert.
    pil_start = -(start_angle)
    pil_end = -(start_angle - total_sweep)
    draw.arc(track_bbox, start=pil_start, end=pil_end, fill=(38, 42, 52, 255), width=arc_width)

    # --- Colored arc (65% filled) ---
    fill_percent = 0.65
    filled_sweep = int(total_sweep * fill_percent)

    # Draw colored arc in small segments for gradient effect
    seg_count = filled_sweep
    for i in range(seg_count):
        t = i / max(seg_count - 1, 1)
        seg_start_angle = start_angle - i
        seg_end_angle = start_angle - i - 1.5  # slight overlap

        # Color: green → cyan → light blue
        if t < 0.4:
            color = lerp_color((40, 200, 110), (30, 210, 200), t / 0.4)
        elif t < 0.7:
            color = lerp_color((30, 210, 200), (60, 190, 235), (t - 0.4) / 0.3)
        else:
            color = lerp_color((60, 190, 235), (100, 210, 250), (t - 0.7) / 0.3)

        pil_s = -seg_start_angle
        pil_e = -seg_end_angle
        draw.arc(track_bbox, start=pil_s, end=pil_e, fill=(*color, 255), width=arc_width)

    # --- Tick marks (outer edge) ---
    num_ticks = 11
    tick_radius = gauge_radius + arc_width // 2 + int(16 * S)
    for i in range(num_ticks):
        t = i / (num_ticks - 1)
        angle = math.radians(start_angle - t * total_sweep)
        tx = int(gauge_cx + tick_radius * math.cos(angle))
        ty = int(gauge_cy - tick_radius * math.sin(angle))
        dot_r = int(4 * S)
        # Brighter ticks where the arc is filled
        if t <= fill_percent:
            tick_color = (120, 130, 145, 255)
        else:
            tick_color = (55, 58, 68, 255)
        draw.ellipse([tx - dot_r, ty - dot_r, tx + dot_r, ty + dot_r], fill=tick_color)

    # --- Needle ---
    needle_angle_deg = start_angle - filled_sweep
    needle_rad = math.radians(needle_angle_deg)
    needle_length = int(200 * S)
    needle_tip = (
        gauge_cx + needle_length * math.cos(needle_rad),
        gauge_cy - needle_length * math.sin(needle_rad)
    )
    draw.line(
        [(gauge_cx, gauge_cy), needle_tip],
        fill=(255, 255, 255, 240),
        width=int(8 * S)
    )

    # Needle shadow (subtle)
    shadow_tip = (needle_tip[0] + 3 * S, needle_tip[1] + 3 * S)
    draw.line(
        [(gauge_cx + 3 * S, gauge_cy + 3 * S), shadow_tip],
        fill=(0, 0, 0, 40),
        width=int(8 * S)
    )

    # --- Center hub ---
    hub_r = int(16 * S)
    draw.ellipse(
        [gauge_cx - hub_r, gauge_cy - hub_r, gauge_cx + hub_r, gauge_cy + hub_r],
        fill=(255, 255, 255, 255)
    )
    # Inner dot
    inner_r = int(6 * S)
    draw.ellipse(
        [gauge_cx - inner_r, gauge_cy - inner_r, gauge_cx + inner_r, gauge_cy + inner_r],
        fill=(50, 55, 65, 255)
    )

    # === Coffee cup accent (bottom center, small & subtle) ===
    cup_cx = CENTER
    cup_cy = int(CENTER + 280 * S)
    cw = int(28 * S)
    ch = int(22 * S)
    cup_color = (210, 165, 50, 180)

    # Cup body outline (trapezoid)
    cup_pts = [
        (cup_cx - cw, cup_cy - ch // 2),
        (cup_cx - cw + int(5 * S), cup_cy + ch // 2),
        (cup_cx + cw - int(5 * S), cup_cy + ch // 2),
        (cup_cx + cw, cup_cy - ch // 2),
    ]
    draw.line(cup_pts + [cup_pts[0]], fill=cup_color, width=int(3.5 * S))

    # Handle arc
    h_bbox = [
        cup_cx + cw - int(2 * S), cup_cy - int(10 * S),
        cup_cx + cw + int(16 * S), cup_cy + int(10 * S)
    ]
    draw.arc(h_bbox, start=-90, end=90, fill=cup_color, width=int(3.5 * S))

    # Steam (3 wavy lines)
    for dx in [int(-12 * S), 0, int(12 * S)]:
        points = []
        for i in range(10):
            t = i / 9.0
            px = cup_cx + dx + int(4 * S) * math.sin(t * math.pi * 1.5)
            py = cup_cy - ch // 2 - int(6 * S) - t * int(28 * S)
            points.append((px, py))
        if len(points) >= 2:
            draw.line(points, fill=(210, 165, 50, 90), width=int(2.5 * S))

    # === Downsample to 1024 (anti-aliasing) ===
    img = img.resize((OUTPUT_SIZE, OUTPUT_SIZE), Image.LANCZOS)

    # Save
    output_path = sys.argv[1] if len(sys.argv) > 1 else "assets/logo.png"
    img.save(output_path, "PNG")
    print(f"✅ Icon generated: {output_path}")


if __name__ == "__main__":
    main()
