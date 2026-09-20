"""Check WCAG AA text contrast for the native app's protected text surfaces."""
from pathlib import Path
import re

root = Path(__file__).resolve().parents[1]
source = (root / "ios/EnTil/Design.swift").read_text()
palette = {name: int(value, 16) for name, value in re.findall(r"static let (\w+) = Color\(hex: 0x([0-9A-Fa-f]+)\)", source)}

def luminance(color):
    channels = [((color >> shift) & 255) / 255 for shift in (16, 8, 0)]
    linear = [v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4 for v in channels]
    return sum(a * b for a, b in zip(linear, (0.2126, 0.7152, 0.0722)))

checks = []
for surface in ("ink", "lounge", "violet"):
    for text in ("cream", "lilac", "lime"):
        checks.append((f"{text} on {surface}", palette[text], palette[surface]))
for surface in ("lime", "lilac"):
    checks.append((f"ink on {surface}", palette["ink"], palette[surface]))
# Selected answer fill and the lightest board tile are read from production code.
assert "Color(hex: 0x343B2C)" in source
checks.append(("selected answer", palette["cream"], 0x343B2C))
board = (root / "ios/EnTil/BoardView.swift").read_text()
assert "Color(hex: 0x78629D)" in board
checks.append(("board number", palette["cream"], 0x78629D))
for label, foreground, background in checks:
    light, dark = sorted((luminance(foreground), luminance(background)), reverse=True)
    ratio = (light + 0.05) / (dark + 0.05)
    assert ratio >= 4.5, f"{label}: {ratio:.2f}:1 is below 4.5:1"
    print(f"{label}: {ratio:.2f}:1")
