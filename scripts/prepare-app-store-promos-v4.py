from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageFilter, ImageOps

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "marketing" / "app-store" / "v4"
OUT.mkdir(parents=True, exist_ok=True)
W, H = 1320, 2868
INK, CREAM, LIME, LILAC, VIOLET, CORAL, AQUA = "#111024", "#FFF5E6", "#D6FF55", "#C9B7FF", "#7E52C7", "#FF6F70", "#72E4DE"
FONT = ROOT / "ios/EnTil/Resources/Fraunces.ttf"
FONT_BOLD = ROOT / "ios/EnTil/Resources/EnTilHeadings-Bold.ttf"
ART = ROOT / "ios/EnTil/Assets.xcassets"

def F(path, size): return ImageFont.truetype(str(path), size)
def art(name): return Image.open(ART / f"{name}.imageset" / "art.png").convert("RGBA")
def fit(im, size): return ImageOps.contain(im, size, method=Image.Resampling.LANCZOS)

def gradient(top, bottom):
    out = Image.new("RGBA", (W, H), top); px = out.load(); a = tuple(int(top[i:i+2], 16) for i in (1, 3, 5)); b = tuple(int(bottom[i:i+2], 16) for i in (1, 3, 5))
    for y in range(H):
        t = y / (H - 1)
        col = tuple(int(a[i] * (1-t) + b[i] * t) for i in range(3)) + (255,)
        for x in range(W): px[x, y] = col
    return out

def base(top, bottom, scene_name):
    out = gradient(top, bottom)
    texture = ImageOps.fit(art(scene_name), (W, H), method=Image.Resampling.LANCZOS)
    texture.putalpha(80); out.alpha_composite(texture)
    return out

def font_text(draw, xy, value, size, fill=CREAM, anchor=None, spacing=2):
    draw.multiline_text(xy, value, font=F(FONT_BOLD, size), fill=fill, anchor=anchor, spacing=spacing, align="center")

def logo(base):
    l = art("BrandLogo"); l.thumbnail((360, 165), Image.Resampling.LANCZOS); base.alpha_composite(l, (W-l.width-70, 64))

def sticker(base, name, xy, size, angle=0, outline=CREAM):
    src = fit(art(name), size); alpha = src.getchannel("A")
    mask = alpha.filter(ImageFilter.MaxFilter(19)); layer = Image.new("RGBA", (mask.width, mask.height), outline); layer.putalpha(mask)
    if angle:
        layer = layer.rotate(angle, resample=Image.Resampling.BICUBIC, expand=True); src = src.rotate(angle, resample=Image.Resampling.BICUBIC, expand=True)
    x, y = xy; base.alpha_composite(layer, (x+10, y+16)); base.alpha_composite(src, (x, y))

def bubble(base, xy, size, fill, value, text_fill=INK, angle=0):
    x, y = xy; w, h = size
    layer = Image.new("RGBA", (w+80, h+80), (0,0,0,0)); d = ImageDraw.Draw(layer)
    d.rounded_rectangle((13, 18, w+13, h+18), radius=min(h//2, 70), fill=(0,0,0,95))
    d.rounded_rectangle((0, 0, w, h), radius=min(h//2, 70), fill=fill)
    d.ellipse((20, 17, 90, 55), fill=(255,255,255,75))
    d.multiline_text((w//2, h//2+3), value, font=F(FONT_BOLD, 43), fill=text_fill, anchor="mm", align="center", spacing=2)
    if angle: layer = layer.rotate(angle, resample=Image.Resampling.BICUBIC, expand=True)
    base.alpha_composite(layer, (x, y))

def badge(base, xy, value, fill=LIME, size=190):
    x,y=xy; d=ImageDraw.Draw(base)
    d.ellipse((x+12,y+18,x+size+12,y+size+18),fill=(0,0,0,85)); d.ellipse((x,y,x+size,y+size),fill=fill,outline=CREAM,width=7)
    font_text(d,(x+size//2,y+size//2),value,42,INK,"mm")

def finish(base, index):
    d=ImageDraw.Draw(base); logo(base)
    d.rounded_rectangle((70,H-142,530,H-58),radius=42,fill=(17,16,36,180))
    font_text(d,(300,H-100),"3–8 venner · gratis at spille",28,CREAM,"mm")
    base.convert("RGB").save(OUT/f"app-store-{index:02d}.jpg",quality=95,subsampling=0)

# 1: bright group hook, question bubble as the game's central object.
b=base("#FF6F70","#6E45C5","Scene-lounge"); d=ImageDraw.Draw(b); font_text(d,(78,150),"Hvem kender\ngruppen bedst?",108,CREAM)
bubble(b,(105,770),(690,240),CREAM,"Hvilken planet er\nstørst i solsystemet?",INK,-3); badge(b,(850,820),"?",LIME,180)
sticker(b,"Character-1",(55,1320),(300,355),-8); sticker(b,"Character-5",(380,1260),(350,415),3); sticker(b,"Character-8",(775,1325),(335,395),-4); sticker(b,"Character-3",(1020,1800),(240,285),7)
bubble(b,(135,2070),(410,130),LIME,"Jorden!",INK,-4); bubble(b,(740,2140),(430,130),AQUA,"Det var let!",INK,5); finish(b,1)

# 2: secrets and reactions, using oversized chat bubbles as the mechanic.
b=base("#6048C7","#1B1740","Scene-question"); d=ImageDraw.Draw(b); font_text(d,(78,150),"Svar i smug.\nAfslør alt bagefter.",104,CREAM)
bubble(b,(105,760),(455,170),LIME,"Mars",INK,-6); bubble(b,(730,790),(470,170),LILAC,"Jupiter?",INK,6)
sticker(b,"Character-2",(40,1290),(340,400),-7); sticker(b,"Character-6",(890,1300),(345,405),7); sticker(b,"Character-0",(470,1630),(340,400),0)
badge(b,(515,1210),"20s",CORAL,190); bubble(b,(150,2150),(420,130),CORAL,"Ingen må se!",CREAM,-4); finish(b,2)

# 3: backing, with characters forming a confident triangle around the choice.
b=base("#C9B7FF","#523499","Scene-backing"); d=ImageDraw.Draw(b); font_text(d,(78,150),"Hvem satser\ndu på?",112,INK)
bubble(b,(205,760),(880,220),CREAM,"Freja       Noah       Alma",INK,0); badge(b,(550,1080),"VÆLG",LIME,220)
sticker(b,"Character-0",(55,1380),(335,395),-8); sticker(b,"Character-4",(490,1360),(350,415),2); sticker(b,"Character-10",(900,1390),(330,390),8)
bubble(b,(100,2080),(430,135),AQUA,"Jeg tror på Freja",INK,-4); bubble(b,(765,2140),(420,135),CORAL,"Noah overrasker",CREAM,5); finish(b,3)

# 4: board movement with a ribbon-like path and modern score badge.
b=base("#111024","#7E52C7","Scene-board"); d=ImageDraw.Draw(b); font_text(d,(78,150),"Rigtigt svar.\nTo felter frem.",106,CREAM)
d.rounded_rectangle((100,760,1220,1320),radius=82,fill=(255,245,230,240)); font_text(d,(660,925),"+2 FELTER",92,VIOLET,"ma"); d.text((660,1080),"Du rykker forbi Noah",font=F(FONT,44),fill=INK,anchor="ma")
for i,(x,y,c) in enumerate([(145,1180,LIME),(350,1040,LILAC),(555,1190,CORAL),(760,1040,AQUA),(965,1180,LIME)]):
    d.ellipse((x,y,x+155,y+155),fill=c,outline=CREAM,width=8); font_text(d,(x+78,y+78),str(i+1),50,INK,"mm")
sticker(b,"Character-3",(110,1600),(300,355),-8); sticker(b,"Character-7",(490,1660),(335,395),4); sticker(b,"Character-5",(900,1580),(340,400),8)
bubble(b,(250,2190),(490,140),LIME,"Yes! Jeg fører!",INK,-3); finish(b,4)

# 5: finale, full-width excitement and confetti rather than an interface.
b=base("#FF6F70","#5A37A9","Scene-finale"); d=ImageDraw.Draw(b); font_text(d,(78,150),"Sidste\nspørgsmål!",116,CREAM)
for x,y,c in [(120,760,LIME),(350,910,AQUA),(610,740,LILAC),(880,900,LIME),(1080,730,CORAL)]: badge(b,(x,y),"★",c,150)
sticker(b,"Character-5",(50,1230),(365,430),-8); sticker(b,"Character-9",(420,1280),(365,430),2); sticker(b,"Character-11",(800,1200),(380,450),8)
bubble(b,(150,2020),(455,145),CREAM,"Hvem vinder?",INK,-4); bubble(b,(770,2110),(425,145),LIME,"Én chance tilbage",INK,5); finish(b,5)

# 6: warm rematch invitation, with a big rounded CTA and complete cast.
b=base("#72E4DE","#493091","Scene-lounge"); d=ImageDraw.Draw(b); font_text(d,(78,150),"Én runde\nmere?",116,INK)
bubble(b,(130,760),(475,165),CREAM,"Vi tager en mere!",INK,-5); bubble(b,(740,860),(435,150),LIME,"Selvfølgelig.",INK,5)
sticker(b,"Character-1",(35,1260),(320,380),-8); sticker(b,"Character-4",(350,1330),(340,400),1); sticker(b,"Character-8",(700,1240),(350,410),7); sticker(b,"Character-0",(980,1630),(275,325),-4)
d.rounded_rectangle((220,2100,1100,2350),radius=125,fill=VIOLET,outline=CREAM,width=10); font_text(d,(660,2220),"SPIL GRATIS",70,CREAM,"mm"); finish(b,6)
