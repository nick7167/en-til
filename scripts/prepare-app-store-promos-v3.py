from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageFilter, ImageOps

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "marketing" / "app-store" / "v3"
OUT.mkdir(parents=True, exist_ok=True)
W, H = 1320, 2868
INK, CREAM, LIME, LILAC, VIOLET, CORAL = "#111024", "#FFF5E6", "#D6FF55", "#C9B7FF", "#7E52C7", "#FF6F70"
FONT = ROOT / "ios/EnTil/Resources/Fraunces.ttf"
FONT_BOLD = ROOT / "ios/EnTil/Resources/EnTilHeadings-Bold.ttf"
ART = ROOT / "ios/EnTil/Assets.xcassets"

def F(path, size): return ImageFont.truetype(str(path), size)
def art(name): return Image.open(ART / f"{name}.imageset" / "art.png").convert("RGBA")
def fit(im, size): return ImageOps.contain(im, size, method=Image.Resampling.LANCZOS)

def scene(name):
    bg = ImageOps.fit(art(name), (W, H), method=Image.Resampling.LANCZOS)
    bg.alpha_composite(Image.new("RGBA", (W, H), (17, 16, 36, 55)))
    return bg

def logo(base):
    l = art("BrandLogo"); l.thumbnail((360, 165), Image.Resampling.LANCZOS)
    base.alpha_composite(l, (W - l.width - 70, 74))

def heading(draw, value, xy=(78, 160), size=112, fill=CREAM):
    draw.multiline_text(xy, value, font=F(FONT_BOLD, size), fill=fill, spacing=2)

def character(base, name, xy, size, angle=0):
    c = fit(art(name), size)
    if angle: c = c.rotate(angle, resample=Image.Resampling.BICUBIC, expand=True)
    base.alpha_composite(c, xy)

def bubble(base, xy, size, value, fill, text_fill=INK, tail="left", font_size=40):
    x, y = xy; w, h = size
    layer = Image.new("RGBA", (w + 90, h + 90), (0, 0, 0, 0)); d = ImageDraw.Draw(layer)
    d.rounded_rectangle((8, 8, w + 8, h + 8), radius=42, fill=fill)
    if tail == "left": d.polygon(((42, h - 12), (0, h + 68), (105, h - 2)), fill=fill)
    else: d.polygon(((w - 50, h - 12), (w + 80, h + 70), (w - 2, h - 2)), fill=fill)
    d.multiline_text((w // 2 + 8, h // 2 + 8), value, font=F(FONT_BOLD, font_size), fill=text_fill, anchor="mm", align="center", spacing=3)
    base.alpha_composite(layer, (x, y))

def card(base, xy, size, title, body, accent):
    x, y = xy; w, h = size; d = ImageDraw.Draw(base)
    shadow = Image.new("RGBA", base.size, (0, 0, 0, 0)); sd = ImageDraw.Draw(shadow)
    sd.rounded_rectangle((x + 18, y + 24, x + w + 18, y + h + 24), radius=34, fill=(0, 0, 0, 125))
    base.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(18)))
    d.rounded_rectangle((x, y, x + w, y + h), radius=34, fill=CREAM, outline=accent, width=12)
    d.ellipse((x + w - 75, y + 28, x + w - 35, y + 68), fill=accent)
    d.multiline_text((x + w // 2, y + 105), title, font=F(FONT_BOLD, 46), fill=INK, anchor="ma", align="center", spacing=3)
    d.multiline_text((x + 42, y + 180), body, font=F(FONT, 34), fill=INK, spacing=7)

def footer(draw):
    draw.text((W // 2, H - 75), "Et til? — et socialt spil for 3–8 venner", font=F(FONT, 32), fill=CREAM, anchor="ms")

def save(base, index): base.convert("RGB").save(OUT / f"app-store-{index:02d}.jpg", quality=95, subsampling=0)

# 1. A social gathering, with the question already becoming the conversation.
b = scene("Scene-lounge"); d = ImageDraw.Draw(b); logo(b); heading(d, "Hvem kender\ngruppen bedst?")
card(b, (125, 790), (620, 470), "SPØRGSMÅL", "Hvilken planet er\nstørst i solsystemet?", LIME)
bubble(b, (705, 775), (445, 145), "Jorden!", LILAC, tail="right", font_size=45)
character(b, "Character-1", (60, 1390), (330, 390), -4); character(b, "Character-5", (425, 1360), (350, 415), 4)
character(b, "Character-8", (810, 1440), (340, 400), -5); character(b, "Character-3", (980, 1960), (260, 310), 6)
bubble(b, (160, 2070), (395, 135), "Det bliver\nspændende…", CORAL, text_fill=CREAM, font_size=37)
footer(d); save(b, 1)

# 2. Private answer mechanic as a secret exchange, not a screen.
b = scene("Scene-question"); d = ImageDraw.Draw(b); logo(b); heading(d, "Svar i smug.\nAfslør alt bagefter.")
card(b, (365, 760), (600, 405), "DIT SVAR", "Mars", LILAC)
bubble(b, (80, 1160), (400, 150), "Jeg ved det!", LIME, font_size=43)
bubble(b, (825, 1160), (400, 150), "Eller gør jeg?", CORAL, text_fill=CREAM, tail="right", font_size=39)
character(b, "Character-2", (50, 1480), (350, 410), -7); character(b, "Character-6", (930, 1490), (330, 390), 7)
character(b, "Character-0", (500, 1760), (330, 390), 0)
d.ellipse((520, 1480, 800, 1760), outline=LIME, width=16)
footer(d); save(b, 2)

# 3. Backing is the game's social hook, shown as a bold choice between friends.
b = scene("Scene-backing"); d = ImageDraw.Draw(b); logo(b); heading(d, "Hvem satser\ndu på?", fill=CREAM)
card(b, (250, 720), (820, 420), "VÆLG EN VEN", "Freja     Noah     Alma", LIME)
bubble(b, (85, 1210), (440, 155), "Freja har\nden her!", LILAC, font_size=39)
bubble(b, (790, 1210), (440, 155), "Jeg siger Noah.", CORAL, text_fill=CREAM, tail="right", font_size=36)
character(b, "Character-0", (70, 1530), (330, 390), -6); character(b, "Character-4", (490, 1500), (340, 400), 0); character(b, "Character-10", (900, 1530), (330, 390), 6)
d.line((240, 2110, 1080, 2110), fill=LIME, width=15)
footer(d); save(b, 3)

# 4. Movement is a visual leap, with everyone reacting around the board.
b = scene("Scene-board"); d = ImageDraw.Draw(b); logo(b); heading(d, "Ét rigtigt svar.\nTo felter frem.")
d.rounded_rectangle((100, 790, 1220, 1400), radius=55, fill="#2B2449", outline=LILAC, width=12)
d.text((660, 900), "+2 FELTER", font=F(FONT_BOLD, 86), fill=LIME, anchor="ma")
d.text((660, 1040), "Du rykker forbi Noah!", font=F(FONT, 43), fill=CREAM, anchor="ma")
for x, y, n in [(170, 1220, "1"), (390, 1130, "2"), (610, 1240, "3"), (830, 1120, "4"), (1030, 1230, "5")]:
    d.ellipse((x, y, x + 130, y + 130), fill=VIOLET, outline=LIME, width=8); d.text((x + 65, y + 65), n, font=F(FONT_BOLD, 55), fill=CREAM, anchor="mm")
character(b, "Character-3", (80, 1630), (320, 380), -8); character(b, "Character-7", (460, 1680), (340, 400), 4); character(b, "Character-5", (920, 1600), (350, 410), 8)
bubble(b, (195, 2200), (490, 145), "Yes! Jeg fører!", LIME, font_size=40)
footer(d); save(b, 4)

# 5. Finale is a full scene with bodies and confetti, no interface needed.
b = scene("Scene-finale"); d = ImageDraw.Draw(b); logo(b); heading(d, "Før din figur\ni mål.")
for x, y, col in [(130, 770, LIME), (400, 930, LILAC), (700, 770, CORAL), (990, 940, LIME)]:
    d.ellipse((x, y, x + 180, y + 180), fill=col)
    d.text((x + 90, y + 90), "★", font=F(FONT_BOLD, 70), fill=INK, anchor="mm")
character(b, "Character-5", (50, 1210), (370, 440), -8); character(b, "Character-9", (415, 1320), (370, 440), 2); character(b, "Character-11", (800, 1190), (380, 450), 7)
bubble(b, (155, 1930), (450, 150), "Hvem vinder?", CORAL, text_fill=CREAM, font_size=42)
bubble(b, (730, 2080), (435, 145), "Sidste spørgsmål!", LILAC, font_size=37, tail="right")
footer(d); save(b, 5)

# 6. Rematch: a warm group portrait and the game's invitation.
b = scene("Scene-lounge"); d = ImageDraw.Draw(b); logo(b); heading(d, "Én runde mere?", fill=CREAM)
bubble(b, (125, 760), (495, 160), "Vi tager\nen mere!", LIME, font_size=48)
bubble(b, (720, 870), (460, 145), "Selvfølgelig.", LILAC, tail="right", font_size=43)
character(b, "Character-1", (55, 1150), (330, 390), -8); character(b, "Character-4", (390, 1280), (350, 410), 2); character(b, "Character-8", (770, 1160), (350, 410), 8); character(b, "Character-0", (970, 1690), (285, 340), -4)
d.rounded_rectangle((250, 2020, 1070, 2250), radius=80, fill=VIOLET, outline=LIME, width=12)
d.text((660, 2135), "SPIL GRATIS", font=F(FONT_BOLD, 64), fill=CREAM, anchor="mm")
footer(d); save(b, 6)
