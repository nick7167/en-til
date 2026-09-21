from pathlib import Path

from PIL import Image, ImageDraw, ImageFont, ImageFilter, ImageOps


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "marketing" / "app-store"
OUT.mkdir(parents=True, exist_ok=True)
W, H = 1320, 2868
INK = "#111024"
CREAM = "#FFF5E6"
LIME = "#D6FF55"
LILAC = "#C9B7FF"
VIOLET = "#7E52C7"

FONT = ROOT / "ios/EnTil/Resources/Fraunces.ttf"
FONT_BOLD = ROOT / "ios/EnTil/Resources/EnTilHeadings-Bold.ttf"
ART = ROOT / "ios/EnTil/Assets.xcassets"
SCREEN_DIR = ROOT / "build/visual-playful-final/screenshots"


def font(path: Path, size: int):
    return ImageFont.truetype(str(path), size)


def asset(name: str, filename: str = "art.png") -> Image.Image:
    return Image.open(ART / f"{name}.imageset" / filename).convert("RGBA")


def screenshot(filename: str) -> Image.Image:
    return Image.open(SCREEN_DIR / filename).convert("RGBA")


def fit(im: Image.Image, size: tuple[int, int]) -> Image.Image:
    return ImageOps.fit(im, size, method=Image.Resampling.LANCZOS)


def text(draw, xy, value, fnt, fill=CREAM, anchor=None, spacing=8):
    draw.multiline_text(xy, value, font=fnt, fill=fill, anchor=anchor, spacing=spacing)


def phone(canvas: Image.Image, shot: Image.Image, box: tuple[int, int, int, int], tilt=0):
    x, y, w, h = box
    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    sd.rounded_rectangle((x + 18, y + 26, x + w + 18, y + h + 26), radius=72, fill=(0, 0, 0, 120))
    shadow = shadow.filter(ImageFilter.GaussianBlur(28))
    canvas.alpha_composite(shadow)
    frame = Image.new("RGBA", (w, h), "#25233B")
    inner = fit(shot, (w - 28, h - 28))
    mask = Image.new("L", inner.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, inner.width, inner.height), radius=56, fill=255)
    frame.alpha_composite(inner, (14, 14), (0, 0, inner.width, inner.height))
    if tilt:
        frame = frame.rotate(tilt, resample=Image.Resampling.BICUBIC, expand=True)
    canvas.alpha_composite(frame, (x, y))


def backdrop(scene: str) -> Image.Image:
    bg = fit(asset(scene), (W, H))
    wash = Image.new("RGBA", (W, H), (17, 16, 36, 110))
    bg.alpha_composite(wash)
    return bg


def save(index: int, scene: str, headline: str, subhead: str, shot: str | None, accent: str, chars=()):
    canvas = backdrop(scene)
    draw = ImageDraw.Draw(canvas)
    draw.rounded_rectangle((70, 70, 420, 148), radius=38, fill=accent)
    text(draw, (245, 109), f"EN TIL?  {index:02d}", font(FONT_BOLD, 30), fill=INK, anchor="mm")
    text(draw, (76, 270), headline, font(FONT_BOLD, 104), fill=CREAM, spacing=3)
    text(draw, (82, 590), subhead, font(FONT, 44), fill=LILAC, spacing=5)
    draw.line((82, 760, 430, 760), fill=accent, width=12)
    if shot:
        phone(canvas, screenshot(shot), (250, 850, 820, 1500), tilt=0)
    if chars:
        group = Image.new("RGBA", (500, 380), (0, 0, 0, 0))
        for i, name in enumerate(chars):
            c = fit(asset(name), (180, 260))
            group.alpha_composite(c, (i * 105, 70 - (i % 2) * 28))
        canvas.alpha_composite(group, (790, 2260))
    logo = asset("BrandLogo")
    logo.thumbnail((400, 170), Image.Resampling.LANCZOS)
    canvas.alpha_composite(logo, (W - logo.width - 70, 110))
    text(draw, (W // 2, H - 90), "Et socialt spil for 3–8 venner", font(FONT, 34), fill=CREAM, anchor="ms")
    canvas.convert("RGB").save(OUT / f"app-store-{index:02d}.jpg", quality=95, subsampling=0)


def icon_variant(number: int, character_names: tuple[str, ...], background: str, mark: str):
    icon = Image.new("RGBA", (1024, 1024), background)
    d = ImageDraw.Draw(icon)
    # Apple applies its own rounded mask; keep this master square and opaque.
    d.ellipse((86, 86, 938, 938), fill="#2D254C", outline="#A68AE8", width=12)
    if mark == "question":
        d.ellipse((188, 160, 836, 808), fill=CREAM)
        text(d, (512, 478), "?", font(FONT_BOLD, 520), fill=VIOLET, anchor="mm")
    if mark == "burst":
        for x, y in ((190, 190), (810, 220), (165, 790), (820, 770)):
            d.regular_polygon((x, y, 34), 5, fill=LIME)
    widths = {1: 660, 2: 470, 3: 335}
    for i, name in enumerate(character_names):
        c = fit(asset(name), (widths.get(len(character_names), 400), widths.get(len(character_names), 400)))
        c = c.rotate((-8, 0, 8)[i] if len(character_names) == 3 else 0, resample=Image.Resampling.BICUBIC, expand=True)
        icon.alpha_composite(c, ((1024 - c.width) // 2 + (i - 1) * 120, 320 + (i % 2) * 70))
    d.ellipse((785, 115, 905, 235), fill=LIME)
    text(d, (845, 175), "?", font(FONT_BOLD, 86), fill=INK, anchor="mm")
    icon.convert("RGB").save(OUT / f"icon-concept-{number:02d}.png")


save(1, "Scene-home", "Gør aftenen\ntil et spil", "Et dansk selskabsspil, hvor alle\nkan være med fra første spørgsmål.", "248FC966-9CB3-4B7C-8B8D-4396738F2462.jpg", LIME, ("Character-1", "Character-5", "Character-8"))
save(2, "Scene-question", "Alle svarer\nfor sig selv", "Hurtige spørgsmål. Store grin.\nIngen skal vente på sin tur.", "7898D1AC-3B3F-4B23-8CE9-82E0A7445D6F.jpg", LILAC, ("Character-2", "Character-6"))
save(3, "Scene-backing", "Sats på den,\ndu tror på", "Læs rummet, vælg din ven,\nog tag chancen.", "18539F2B-BA84-4076-A856-1C1D9E520A04.jpg", LIME, ("Character-0", "Character-4", "Character-10"))
save(4, "Scene-board", "Se pointene\nlande", "Rigtige svar giver fart på.\nHvert valg kan flytte spillet.", "27D13BD7-6FC9-4CA6-983C-341269E801D8.jpg", LILAC, ("Character-3", "Character-7"))
save(5, "Scene-finale", "Før din figur\ni mål", "En levende spilleplade,\nspænding til sidste felt.", "E6A9A03C-E215-46B8-A9ED-F8B16346F777.jpg", LIME, ("Character-5", "Character-9", "Character-11"))
save(6, "Scene-lounge", "Én runde\nmere?", "Gratis at spille. Klar på dansk.\nInvitér vennerne og kom i gang.", "70C4CEE5-7942-4F71-9FA5-7DC4BE8B4F62.jpg", LILAC, ("Character-1", "Character-4", "Character-8"))

icon_variant(1, ("Character-0",), VIOLET, "question")
icon_variant(2, ("Character-0", "Character-5", "Character-8"), INK, "burst")
icon_variant(3, ("Character-1", "Character-4", "Character-9"), LILAC, "burst")
