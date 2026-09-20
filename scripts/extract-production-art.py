"""Extract high-resolution generated assets; discard detached alpha debris, not character details.
Original generated files stay untouched. Requires existing Pillow/numpy art tooling.
"""
from collections import deque
from pathlib import Path
import numpy as np
from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "design/artwork/production"
ASSETS = ROOT / "ios/EnTil/Assets.xcassets"

def components(image, minimum):
    mask = np.array(image.getchannel("A")) > 200
    height, width = mask.shape
    found = []
    for y, x in zip(*np.where(mask)):
        if not mask[y, x]:
            continue
        queue = deque([(y, x)])
        mask[y, x] = False
        points = []
        while queue:
            yy, xx = queue.popleft()
            points.append((yy, xx))
            for ny, nx in ((yy-1, xx), (yy+1, xx), (yy, xx-1), (yy, xx+1)):
                if 0 <= ny < height and 0 <= nx < width and mask[ny, nx]:
                    mask[ny, nx] = False
                    queue.append((ny, nx))
        if len(points) >= minimum:
            found.append(np.array(points))
    return found

def export(image, parts, name):
    mask = np.zeros((image.height, image.width), dtype=np.uint8)
    for points in parts:
        mask[points[:, 0], points[:, 1]] = 255
    # Keep original anti-aliasing within one pixel of each retained contour.
    support = np.array(Image.fromarray(mask).filter(ImageFilter.MaxFilter(3)))
    pixels = np.array(image)
    pixels[:, :, 3] = np.minimum(pixels[:, :, 3], support)
    result = Image.fromarray(pixels)
    result = result.crop(result.getbbox())
    result.save(ASSETS / f"{name}.imageset/art.png", optimize=True)
    print(name, result.size)

cast = Image.open(SOURCE / "cast.png").convert("RGBA")
parts = components(cast, 10000)
assert len(parts) == 12, f"Expected twelve isolated characters, found {len(parts)}"
parts.sort(key=lambda p: int(p[:, 0].mean() / (cast.height / 4)) * 3 + int(p[:, 1].mean() / (cast.width / 3)))
for index, part in enumerate(parts):
    export(cast, [part], f"Character-{index}")
coral = Image.open(SOURCE / "coral.png").convert("RGBA")
export(coral, components(coral, 10000), "Character-1")
logo = Image.open(SOURCE / "logo.png").convert("RGBA")
# Generated alpha can retain neutral-white matte residue between letters.
# Keep only the cream/lime ink, using the same colour-mask extraction approach as the references.
rgb = np.array(logo).astype(np.int16)
ink = (rgb[:, :, 0] > 180) & (rgb[:, :, 1] > 170) & (rgb[:, :, 1] - rgb[:, :, 2] > 12)
rgb[:, :, 3] = np.where(ink, rgb[:, :, 3], 0)
logo = Image.fromarray(rgb.astype(np.uint8))
export(logo, components(logo, 3000), "BrandLogo")
