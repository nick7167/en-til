"""Extract approved raster contours; no redraw, recoloring, or enlargement.

Sources remain untouched. The A02 host and two C04 poses replace dimmed B03 figures.
Run from the repository root with Pillow and numpy installed.
"""
from collections import deque
from pathlib import Path
import json
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / 'ios/EnTil/Assets.xcassets'
REFERENCE = ROOT / 'design/references'
cast = Image.open(REFERENCE / 'exec-520ba086-193f-42ab-ac78-3cd7afa2ce65.png').convert('RGB')
home = Image.open(REFERENCE / 'exec-00162405-7f6d-4645-bc0f-401e7237046e.png').convert('RGB')
bundle = Image.open(REFERENCE / 'exec-8ed021f8-b54c-4d9a-bf99-cd0464c184aa.png').convert('RGB')


def fill_enclosed(mask):
    """Keep dark eyes/mouths inside actual colored contours, not bounding boxes."""
    height, width = mask.shape
    exterior = np.zeros_like(mask)
    queue = deque()
    for x in range(width):
        for y in (0, height - 1):
            if not mask[y, x]:
                exterior[y, x] = True
                queue.append((y, x))
    for y in range(height):
        for x in (0, width - 1):
            if not mask[y, x] and not exterior[y, x]:
                exterior[y, x] = True
                queue.append((y, x))
    while queue:
        y, x = queue.popleft()
        for yy, xx in ((y-1,x), (y+1,x), (y,x-1), (y,x+1)):
            if 0 <= yy < height and 0 <= xx < width and not mask[yy, xx] and not exterior[yy, xx]:
                exterior[yy, xx] = True
                queue.append((yy, xx))
    return ~exterior


def largest_components(mask, minimum=5):
    remaining = mask.copy()
    clean = np.zeros_like(mask)
    height, width = mask.shape
    for y, x in zip(*np.where(mask)):
        if not remaining[y, x]:
            continue
        component = [(y, x)]
        remaining[y, x] = False
        for yy, xx in component:
            for ny, nx in ((yy-1,xx),(yy+1,xx),(yy,xx-1),(yy,xx+1)):
                if 0 <= ny < height and 0 <= nx < width and remaining[ny,nx]:
                    remaining[ny,nx] = False
                    component.append((ny,nx))
        if len(component) >= minimum:
            for yy, xx in component:
                clean[yy,xx] = True
    return clean


def export(name, crop, mask):
    pixels = np.array(crop)
    rgba = np.dstack((pixels, mask.astype(np.uint8)*255))
    result = Image.fromarray(rgba, 'RGBA')
    bounds = result.getbbox()
    if bounds is None:
        raise ValueError(f'Empty extraction: {name}')
    result = result.crop(bounds)
    folder = ASSETS / f'{name}.imageset'
    folder.mkdir(parents=True, exist_ok=True)
    result.save(folder / 'art.png')
    (folder / 'Contents.json').write_text(json.dumps({'images':[{'filename':'art.png','idiom':'universal'}], 'info':{'author':'xcode','version':1}}, indent=2)+'\n')
    return result

# Local crops stop above occupied-name labels and inside cell borders.
boxes = [
    (135,990,231,1055), (251,990,342,1066), (359,987,446,1057),
    (140,1091,224,1155), (265,1090,337,1176), (373,1090,445,1175),
    (143,1199,220,1282), (263,1196,337,1282), (373,1190,445,1282),
    (141,1297,223,1388), (254,1294,347,1388), (384,1296,435,1388),
]
# Hue windows in Pillow's 0...255 scale; allow shaded source colors.
hues = [(28,56),(0,22),(163,207),(10,31),(105,139),(28,47),
        (217,250),(45,78),(140,174),(176,212),(16,37),(221,251)]
results = []
for index, (box, (low, high)) in enumerate(zip(boxes,hues)):
    active_boxes = {0: (556,982,652,1049), 2: (722,970,809,1048), 3: (813,964,891,1043)}
    crop = home.crop((394,257,498,319)) if index == 0 else bundle.crop(active_boxes[index]) if index in active_boxes else cast.crop(box)
    hsv = np.array(crop.convert('HSV'))
    mask = (hsv[:,:,0] >= (38 if index == 0 else low)) & (hsv[:,:,0] <= high) & (hsv[:,:,1] > 45) & (hsv[:,:,2] > (65 if index in [0,3] else 87 if index == 2 else 105))
    mask = fill_enclosed(largest_components(mask, minimum=25))
    results.append(export(f'Character-{index}',crop,mask))

logo = home.crop((61,116,302,242))
rgb = np.array(logo)
# Cream lettering and the lime swoosh; the enclosing crop excludes scene pixels.
mask = (rgb[:,:,0] > 165) & (rgb[:,:,1] > 170) & ((rgb[:,:,2] > 145) | (rgb[:,:,1] > rgb[:,:,2]*1.25))
results.append(export('BrandLogo',logo,largest_components(mask)))

# Exact small covers from A06, without labels, price columns or card borders.
pack_names = ['danmark','film-tv','isbryderen','lidt-for-aerlig','efter-midnat','uden-filter']
pack_results = []
for name, top in zip(pack_names, [872,944,1016,1088,1161,1234]):
    crop = home.crop((713,top,772,top+58))
    pack_results.append(export(f'PackReference-{name}',crop,np.ones((crop.height,crop.width),dtype=bool)))

# A06 compact quartet, separate from the wide C04 header ensemble.
cover_group = home.crop((710,1315,786,1398))
cover_hsv = np.array(cover_group.convert('HSV'))
export('PackReference-launch-bundle', cover_group,
       fill_enclosed(largest_components((cover_hsv[:,:,1] > 45) & (cover_hsv[:,:,2] > 110), minimum=20)))

# C04 ensemble includes its original floating host crown.
group = bundle.crop((554,963,894,1048))
hsv = np.array(group.convert('HSV'))
mask = (hsv[:,:,1] > 45) & (hsv[:,:,2] > 112)
group_result = export('CharacterGroup',group,fill_enclosed(largest_components(mask, minimum=45)))

# Review artifact deliberately stays outside asset catalog and repository.
preview = Image.new('RGB',(720,760),(22,19,36))
for index, result in enumerate(results[:12]):
    x = 25 + (index%4)*155
    y = 20 + (index//4)*120
    preview.paste(result,(x,y),result)
preview.paste(results[-1],(180,390),results[-1])
preview.paste(group_result,(160,535),group_result)
for index, result in enumerate(pack_results):
    preview.paste(result,(40+index*108,665),result)
preview.save('/private/tmp/en-til-reference-cast.png')
print('Extracted BrandLogo, 12 characters, CharacterGroup and seven PackReference covers; contact sheet /private/tmp/en-til-reference-cast.png')
