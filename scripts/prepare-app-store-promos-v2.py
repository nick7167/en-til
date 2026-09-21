from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageFilter, ImageOps

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "marketing" / "app-store" / "v2"
OUT.mkdir(parents=True, exist_ok=True)
W, H = 1320, 2868
INK, CREAM, LIME, LILAC, VIOLET = "#111024", "#FFF5E6", "#D6FF55", "#C9B7FF", "#7E52C7"
FONT = ROOT / "ios/EnTil/Resources/Fraunces.ttf"
FONT_BOLD = ROOT / "ios/EnTil/Resources/EnTilHeadings-Bold.ttf"
ART = ROOT / "ios/EnTil/Assets.xcassets"
SCREEN = ROOT / "build/visual-playful-final/screenshots"

def F(path, size): return ImageFont.truetype(str(path), size)
def art(name, file="art.png"): return Image.open(ART / f"{name}.imageset" / file).convert("RGBA")
def shot(name): return Image.open(SCREEN / name).convert("RGBA")
def fit(im, size): return ImageOps.fit(im, size, method=Image.Resampling.LANCZOS)

def scene(name):
    bg = fit(art(name), (W, H))
    overlay = Image.new("RGBA", (W, H), (17, 16, 36, 90))
    bg.alpha_composite(overlay)
    return bg

def label(draw, xy, value, size, fill=CREAM, anchor=None):
    draw.text(xy, value, font=F(FONT_BOLD, size), fill=fill, anchor=anchor, spacing=5)

def card(base, image, xy, size, angle=0, border=LILAC):
    x, y = xy; w, h = size
    layer = Image.new("RGBA", (w + 30, h + 30), (0, 0, 0, 0))
    ld = ImageDraw.Draw(layer)
    ld.rounded_rectangle((15, 18, w + 15, h + 18), radius=55, fill=(0, 0, 0, 150))
    ld.rounded_rectangle((0, 0, w + 30, h + 30), radius=55, fill=border)
    inner = fit(image, (w, h))
    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, w, h), radius=42, fill=255)
    layer.paste(inner, (15, 15), mask)
    if angle: layer = layer.rotate(angle, resample=Image.Resampling.BICUBIC, expand=True)
    base.alpha_composite(layer, (x, y))

def character(base, name, xy, size, angle=0):
    c = fit(art(name), size)
    if angle: c = c.rotate(angle, resample=Image.Resampling.BICUBIC, expand=True)
    base.alpha_composite(c, xy)

def logo(base):
    l = art("BrandLogo"); l.thumbnail((355, 160), Image.Resampling.LANCZOS)
    base.alpha_composite(l, (W - l.width - 72, 82))

def make(index, scene_name, headline, accent, elements):
    base = scene(scene_name); d = ImageDraw.Draw(base)
    logo(base)
    # A soft spotlight creates a campaign-like composition instead of a screenshot stack.
    glow = Image.new("RGBA", (W, H), (0, 0, 0, 0)); gd = ImageDraw.Draw(glow)
    gd.ellipse((-280, 540, 1120, 1940), fill=accent + "42")
    base.alpha_composite(glow.filter(ImageFilter.GaussianBlur(34)))
    label(d, (78, 170), headline, 112, CREAM)
    d.line((82, 545, 410, 545), fill=accent, width=15)
    for item in elements:
        if item[0] == "card": card(base, shot(item[1]), item[2], item[3], item[4], accent)
        elif item[0] == "char": character(base, item[1], item[2], item[3], item[4])
        elif item[0] == "pill":
            x, y, w, h, value = item[1:]
            d.rounded_rectangle((x, y, x + w, y + h), radius=h // 2, fill=accent)
            label(d, (x + w // 2, y + h // 2), value, 34, INK, "mm")
    label(d, (78, H - 82), "Et dansk selskabsspil for 3–8 venner", 34, CREAM)
    base.convert("RGB").save(OUT / f"app-store-{index:02d}.jpg", quality=95, subsampling=0)

make(1, "Scene-home", "Saml flokken.", LIME, [
    ("card", "248FC966-9CB3-4B7C-8B8D-4396738F2462.jpg", (485, 795), (690, 1190), -4),
    ("char", "Character-1", (90, 1390), (420, 490), -10),
    ("char", "Character-5", (825, 1630), (330, 395), 12),
    ("char", "Character-8", (175, 2080), (310, 370), 0),
    ("pill", 120, 2500, 355, 80, "Invitér vennerne"),
])
make(2, "Scene-question", "Svar først.\nGrin bagefter.", LILAC, [
    ("card", "7898D1AC-3B3F-4B23-8CE9-82E0A7445D6F.jpg", (115, 870), (670, 1155), 5),
    ("char", "Character-2", (730, 1100), (410, 480), -7),
    ("char", "Character-6", (870, 1680), (320, 390), 8),
    ("pill", 770, 2350, 360, 80, "Alle er med"),
])
make(3, "Scene-backing", "Hvem tror\ndu på?", LIME, [
    ("card", "18539F2B-BA84-4076-A856-1C1D9E520A04.jpg", (440, 770), (730, 1200), -3),
    ("char", "Character-0", (78, 1080), (360, 420), -10),
    ("char", "Character-4", (840, 1180), (370, 430), 7),
    ("char", "Character-10", (140, 2040), (300, 360), 0),
    ("pill", 460, 2320, 360, 80, "Læs rummet"),
])
make(4, "Scene-board", "Hvert valg\nflytter noget.", LILAC, [
    ("card", "27D13BD7-6FC9-4CA6-983C-341269E801D8.jpg", (70, 1040), (1180, 900), -2),
    ("char", "Character-3", (150, 1810), (350, 410), -8),
    ("char", "Character-7", (840, 1740), (390, 450), 8),
    ("pill", 440, 2290, 390, 80, "+1 point"),
])
make(5, "Scene-finale", "Kapløbet\ner i gang.", LIME, [
    ("card", "E6A9A03C-E215-46B8-A9ED-F8B16346F777.jpg", (315, 770), (700, 1210), 3),
    ("char", "Character-5", (45, 1260), (400, 470), -10),
    ("char", "Character-9", (860, 1400), (340, 400), 9),
    ("char", "Character-11", (180, 2100), (300, 350), 0),
    ("pill", 760, 2360, 360, 80, "Hvem vinder?"),
])
make(6, "Scene-lounge", "Klar på\nén mere?", LILAC, [
    ("card", "70C4CEE5-7942-4F71-9FA5-7DC4BE8B4F62.jpg", (150, 930), (650, 1080), -5),
    ("card", "E6A9A03C-E215-46B8-A9ED-F8B16346F777.jpg", (620, 1090), (575, 940), 7),
    ("char", "Character-1", (760, 1870), (330, 390), 8),
    ("char", "Character-4", (80, 2070), (350, 410), -8),
    ("pill", 430, 2470, 405, 80, "Spil gratis"),
])
