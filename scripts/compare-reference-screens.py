"""Create local side-by-side review sheets from exported XCTest screenshots."""
from pathlib import Path
import json,sys
from PIL import Image,ImageDraw,ImageOps
ROOT=Path(__file__).resolve().parents[1]
folder=Path(sys.argv[1]);shots=folder/'screenshots';out=folder/'comparison';out.mkdir(exist_ok=True)
refs=[('A','exec-00162405-7f6d-4645-bc0f-401e7237046e.png',[(23,43,332,727),(358,43,665,727),(691,43,1001,727),(23,790,332,1462),(358,790,665,1462),(691,790,1001,1462)]),('B','exec-520ba086-193f-42ab-ac78-3cd7afa2ce65.png',[(120,40,483,727),(541,40,906,727),(120,790,483,1484),(541,790,906,1484)]),('C','exec-8ed021f8-b54c-4d9a-bf99-cd0464c184aa.png',[(105,36,482,780),(539,37,914,780),(106,839,482,1507),(539,839,914,1507)]),('D','exec-ad7b2695-d676-4ed8-be77-8d0ce5badc35.png',[(86,43,486,737),(534,43,935,737),(86,797,486,1497),(534,797,935,1497)]),('E','exec-406bc08e-1755-4947-b149-a771f558cd30.png',[(98,47,487,771),(537,47,926,771),(98,833,487,1493),(537,833,926,1493)]),('F','exec-ba5fcc62-3d19-4084-a8ae-8a736dc43779.png',[(110,41,476,759),(545,41,918,759),(110,814,476,1490),(545,814,918,1490)])]
attachments=[a for group in json.loads((shots/'manifest.json').read_text()) for a in group['attachments']]
for letter,file,boxes in refs:
 sheet=Image.open(ROOT/'design/references'/file)
 canvas=Image.new('RGB',(len(boxes)*360,440),'#ededeb');draw=ImageDraw.Draw(canvas)
 for i,box in enumerate(boxes):
  prefix=f'{letter}{i+1:02}'
  original=sheet.crop(box).resize((174,394),Image.Resampling.LANCZOS)
  canvas.paste(original,(i*360,35));draw.text((i*360,10),prefix+' approved',fill='black')
  found=next((a for a in attachments if a['suggestedHumanReadableName'].startswith(prefix)),None)
  if found:
   actual=Image.open(shots/found['exportedFileName']).convert('RGB').resize((174,394),Image.Resampling.LANCZOS)
   canvas.paste(actual,(i*360+180,35));draw.text((i*360+180,10),'Native',fill='black')
 canvas.save(out/f'{letter}.jpg',quality=94)
print(out)
