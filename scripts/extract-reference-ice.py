"""Remove mockup lettering while preserving the approved ice scene's artwork.

Build-only: Pillow, numpy and opencv-python-headless (optionally in build/image-tools).
The original reference sheet is never modified.
"""
from pathlib import Path
import sys
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'build/image-tools'))
import cv2
import numpy as np
from PIL import Image

source = ROOT / 'design/references/exec-8ed021f8-b54c-4d9a-bf99-cd0464c184aa.png'
pixels = np.array(Image.open(source).convert('RGB').crop((106,840,481,1507)))
original = pixels.copy()
hsv = cv2.cvtColor(pixels, cv2.COLOR_RGB2HSV)
mask = np.zeros(pixels.shape[:2], np.uint8)
# Isolate lettering and its shadow, then protect the blue mountain faces at the left edge.
for left, top, right, bottom in [(127,887,457,969),(137,996,457,1073),(157,1278,455,1345),(106,870,145,919)]:
    area = hsv[top-840:bottom-840, left-106:right-106]
    mask[top-840:bottom-840, left-106:right-106] = ((area[:,:,1] < 80) & (area[:,:,2] > 140)).astype(np.uint8) * 255
mask = cv2.dilate(mask, np.ones((9,9), np.uint8))
protected = np.zeros_like(mask)
cv2.fillPoly(protected, [np.array([(0,140),(24,111),(53,190),(57,224),(72,204),(99,234),(0,340)], np.int32)], 255)
mask[protected > 0] = 0
mask[118:171,124:257] = 255  # Intensity chip, including its shadow.
pixels = cv2.inpaint(pixels, mask, 4, cv2.INPAINT_TELEA)
assert np.array_equal(pixels[245:440,70:300], original[245:440,70:300]), 'Hero artwork must remain unchanged'
for row in range(pixels.shape[0]):
    fade = max(0, min(1, (row-32)/20)) if row < 52 else max(0, min(1, (508-row)/8)) if row > 500 else 1
    pixels[row] = (pixels[row] * fade + np.array([14,15,26]) * (1-fade)).astype(np.uint8)
output = ROOT / 'design/artwork/scenes/ice-reference.png'
Image.fromarray(pixels).resize((780,1387), Image.Resampling.LANCZOS).save(output, optimize=True)
print(output.relative_to(ROOT))
