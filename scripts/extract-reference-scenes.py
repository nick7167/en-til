"""Assemble full-screen backgrounds from unaltered approved scene crops.
No interface text/buttons are baked into production backgrounds.
"""
from pathlib import Path
import json
import numpy as np
from PIL import Image, ImageFilter
ROOT=Path(__file__).resolve().parents[1]
REF=ROOT/'design/references'
ASSETS=ROOT/'ios/EnTil/Assets.xcassets'
files={'A':'exec-00162405-7f6d-4645-bc0f-401e7237046e.png','B':'exec-520ba086-193f-42ab-ac78-3cd7afa2ce65.png','C':'exec-8ed021f8-b54c-4d9a-bf99-cd0464c184aa.png','D':'exec-ad7b2695-d676-4ed8-be77-8d0ce5badc35.png','E':'exec-406bc08e-1755-4947-b149-a771f558cd30.png','F':'exec-ba5fcc62-3d19-4084-a8ae-8a736dc43779.png'}
images={k:Image.open(REF/f).convert('RGB') for k,f in files.items()}
W,H=780,1688

def base():
 y,x=np.mgrid[0:H,0:W]; glow=np.exp(-((x-W*.6)**2/(W*.65)**2+(y-H*.6)**2/(H*.65)**2))
 out=np.zeros((H,W,3),dtype=np.uint8)
 for c,(lo,hi) in enumerate([(13,20),(14,18),(25,34)]):out[:,:,c]=lo+glow*(hi-lo)
 return Image.fromarray(out).convert('RGBA')

def art(canvas,sheet,box,xy,width,fade=20):
 patch=images[sheet].crop(box).convert('RGBA'); height=round(patch.height*width/patch.width)
 patch=patch.resize((width,height),Image.Resampling.LANCZOS)
 alpha=np.full((height,width),255.,dtype=float)
 if fade:
  ramp=np.minimum(np.arange(height),np.arange(height)[::-1])/fade
  alpha*=np.clip(ramp,0,1)[:,None]
 patch.putalpha(Image.fromarray(alpha.astype('uint8')))
 canvas.alpha_composite(patch,xy)

def edges(canvas):
 art(canvas,'A',(23,1283,91,1400),(0,450),125,28)
 art(canvas,'A',(280,220,331,337),(680,400),100,22)

def footer(canvas):art(canvas,'A',(23,1283,331,1440),(0,1290),780,25)

def save(name,canvas):
 folder=ASSETS/f'Scene-{name}.imageset';folder.mkdir(exist_ok=True)
 canvas.convert('RGB').save(folder/'art.png',optimize=True)
 (folder/'Contents.json').write_text(json.dumps({'images':[{'filename':'art.png','idiom':'universal'}],'info':{'author':'xcode','version':1}},indent=2)+'\n')

for name in ['plain','lounge','home','question','backing','privateRound','waiting','paused','guess','board','finale','ice']:
 c=base()
 if name=='lounge':edges(c);footer(c)
 if name=='home':art(c,'A',(23,241,331,424),(0,455),780,35)
 if name=='question':art(c,'A',(692,500,1001,644),(0,1110),780,25)
 if name=='backing':footer(c)
 if name=='privateRound':art(c,'D',(85,348,487,491),(0,692),780,20)
 if name=='waiting':art(c,'D',(534,273,938,585),(0,535),780,30)
 if name=='paused':art(c,'E',(98,970,487,1114),(0,350),780,16)
 if name=='guess':art(c,'D',(86,1279,487,1421),(0,1255),780,20)
 if name=='board':edges(c);footer(c)
 if name=='finale':
  art(c,'E',(537,1099,927,1128),(0,638),780,8)
  # The blank flag is filled by live native score text, not a baked mock score.
  # Keep stage and winner composition; native winner artwork covers the reference winner when needed.
 if name=='ice':art(c,'C',(104,1065,482,1285),(0,655),780,25)
 save(name,c)
print('Extracted 12 production scene backgrounds; six original sheets unchanged.')

# Reviewed reconstruction candidates replace crop fallbacks; original sheets stay untouched.
import shutil
for name, source in {'home':'home','question':'question','waiting':'waiting','ice':'ice','lobby':'lobby','privateRound':'privateRound','finale':'finale','board':'board','adult':'home','settings':'board'}.items():
    folder=ASSETS/f'Scene-{name}.imageset'
    folder.mkdir(exist_ok=True)
    shutil.copy2(ROOT/'design/artwork/scenes'/f'{source}.png', folder/'art.png')
    (folder/'Contents.json').write_text(json.dumps({'images':[{'filename':'art.png','idiom':'universal'}],'info':{'author':'xcode','version':1}},indent=2)+'\n')
