from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageFilter, ImageOps

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "marketing" / "app-store" / "v5"
OUT.mkdir(parents=True, exist_ok=True)
W, H = 1320, 2868
INK, CREAM = "#111024", "#FFF8EA"
FONT = "/System/Library/Fonts/SFNSRounded.ttf"
FONT_BOLD = "/System/Library/Fonts/SFNSRounded.ttf"
ART = ROOT / "ios/EnTil/Assets.xcassets"
SCREEN = ROOT / "build/visual-playful-final/screenshots"

SCREENS = [
    "248FC966-9CB3-4B7C-8B8D-4396738F2462.jpg",  # home
    "7898D1AC-3B3F-4B23-8CE9-82E0A7445D6F.jpg",   # question
    "18539F2B-BA84-4076-A856-1C1D9E520A04.jpg",   # backing
    "27D13BD7-6FC9-4CA6-983C-341269E801D8.jpg",   # board
    "E6A9A03C-E215-46B8-A9ED-F8B16346F777.jpg",   # finale
    "70C4CEE5-7942-4F71-9FA5-7DC4BE8B4F62.jpg",   # lobby
]
COPY = [
    ("ET SOCIALT SPIL FOR 3–8", "Et spil, hvor\nalle er med", "#C9B7FF"),
    ("SVAR I SMUG", "Se hvem der\nramte rigtigt", "#72E4DE"),
    ("LÆS RUMMET", "Sats på den,\ndu tror på", "#D6FF55"),
    ("RIGTIGT SVAR", "Ryk frem, når\ndu har ret", "#FFCF5A"),
    ("SIDSTE RUNDE", "Hvem ender\nførst?", "#FF8A87"),
    ("INVITÉR VENNERNE", "Klar på\nén mere?", "#C9B7FF"),
]

def font(size, bold=False): return ImageFont.truetype(FONT_BOLD if bold else FONT, size)

def logo(base):
    l = Image.open(ART / "BrandLogo.imageset" / "art.png").convert("RGBA")
    l.thumbnail((330, 145), Image.Resampling.LANCZOS)
    base.alpha_composite(l, (W - l.width - 68, 58))

def make(index):
    screen = Image.open(SCREEN / SCREENS[index]).convert("RGB")
    base = ImageOps.fit(screen, (W, H), method=Image.Resampling.LANCZOS).convert("RGBA")
    kicker, headline, color = COPY[index]
    # Product fills the image. The caption is the only marketing layer.
    shade = Image.new("RGBA", (W, H), (0, 0, 0, 0)); sd = ImageDraw.Draw(shade)
    sd.rectangle((0, 0, W, 370), fill=(17, 16, 36, 75))
    sd.rectangle((0, H - 930, W, H), fill=(17, 16, 36, 120))
    base.alpha_composite(shade)
    logo(base)
    d = ImageDraw.Draw(base)
    # Rounded Duolingo-style message panel with a soft lift and glossy highlight.
    x, y, w, h = 72, H - 760, W - 144, 600
    shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0)); sh = ImageDraw.Draw(shadow)
    sh.rounded_rectangle((x + 16, y + 24, x + w + 16, y + h + 24), radius=72, fill=(0, 0, 0, 120))
    base.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(22)))
    d.rounded_rectangle((x, y, x + w, y + h), radius=72, fill=color)
    d.ellipse((x + 40, y + 34, x + 190, y + 74), fill=(255, 255, 255, 85))
    d.text((x + 62, y + 78), kicker, font=font(30, True), fill=INK)
    d.multiline_text((x + 62, y + 162), headline, font=font(82, True), fill=INK, spacing=0)
    d.rounded_rectangle((x + 62, y + h - 112, x + w - 62, y + h - 48), radius=32, fill=(17, 16, 36, 235))
    d.text((x + w // 2, y + h - 80), "EN TIL?", font=font(30, True), fill=CREAM, anchor="mm")
    base.convert("RGB").save(OUT / f"app-store-{index + 1:02d}.jpg", quality=95, subsampling=0)

for i in range(6): make(i)
