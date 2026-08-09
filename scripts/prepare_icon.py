#!/usr/bin/env python3
"""
Prepare macOS app icon from a source image.

1. Scale down content to ~76% and center on dark background
2. Apply macOS-style rounded corners (radius ~22.37%)

This gives proper visual weight matching other macOS icons.

Usage:
    python3 scripts/prepare_icon.py assets/icon_raw.png
"""

import sys
from PIL import Image, ImageDraw

OUTPUT_SIZE = 1024
CORNER_RATIO = 0.2237  # Apple's macOS squircle radius ratio
CONTENT_SCALE = 0.76   # Scale content to 76% — leaves ~12% padding each side
BG_COLOR = (14, 16, 20, 255)  # Dark background matching the icon


def create_rounded_mask(size, radius):
    """Create anti-aliased rounded rect mask (render at 2x, downscale)."""
    render_size = size * 2
    render_radius = radius * 2

    mask_hires = Image.new("L", (render_size, render_size), 0)
    draw_hires = ImageDraw.Draw(mask_hires)
    draw_hires.rounded_rectangle(
        [0, 0, render_size - 1, render_size - 1],
        radius=render_radius,
        fill=255
    )
    return mask_hires.resize((size, size), Image.LANCZOS)


def main():
    if len(sys.argv) < 2:
        print("Usage: python3 scripts/prepare_icon.py <source.png> [output.png]")
        sys.exit(1)

    source_path = sys.argv[1]
    output_path = sys.argv[2] if len(sys.argv) > 2 else "assets/logo.png"

    # Load source
    img = Image.open(source_path).convert("RGBA")
    w, h = img.size
    print(f"Source: {w}x{h}")

    # Crop to square
    if w != h:
        side = min(w, h)
        left = (w - side) // 2
        top = (h - side) // 2
        img = img.crop((left, top, left + side, top + side))
        print(f"Cropped to {side}x{side}")

    # Step 1: Apply rounded corners at full size FIRST
    radius = int(img.size[0] * CORNER_RATIO)
    print(f"Applying rounded corners (radius: {radius}px) at full size")

    mask = create_rounded_mask(img.size[0], radius)
    rounded = Image.new("RGBA", img.size, (0, 0, 0, 0))
    rounded.paste(img, (0, 0), mask)

    # Step 2: Scale down the rounded icon
    content_size = int(OUTPUT_SIZE * CONTENT_SCALE)
    rounded_scaled = rounded.resize((content_size, content_size), Image.LANCZOS)
    print(f"Scaled to {content_size}x{content_size} ({CONTENT_SCALE*100:.0f}%)")

    # Step 3: Place on transparent canvas
    output = Image.new("RGBA", (OUTPUT_SIZE, OUTPUT_SIZE), (0, 0, 0, 0))
    offset = (OUTPUT_SIZE - content_size) // 2
    output.paste(rounded_scaled, (offset, offset), rounded_scaled)
    print(f"Centered with {offset}px padding")

    output.save(output_path, "PNG")
    print(f"✅ Icon saved: {output_path}")
    print()
    print("Next:")
    print("  ./scripts/bundle.sh")
    print("  cp -r build/Rancage.app /Applications/")


if __name__ == "__main__":
    main()
