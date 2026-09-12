"""Freeze approved Fraunces soft axes; fontTools is a build-only tool."""
from pathlib import Path
import sys
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'build/image-tools'))
from fontTools.ttLib import TTFont
from fontTools.varLib.instancer import instantiateVariableFont
font=TTFont(ROOT/'ios/EnTil/Resources/Fraunces.ttf')
axes={axis.axisTag:axis for axis in font['fvar'].axes}
values={'SOFT':100,'WONK':1,'wght':700,'opsz':24}
assert set(values)<=set(axes)
font=instantiateVariableFont(font,values,inplace=True)
for record in font['name'].names:
 names={1:'En Til Headings',2:'Bold',3:'EnTilHeadings-Bold-1',4:'En Til Headings Bold',6:'EnTilHeadings-Bold',16:'En Til Headings',17:'Bold'}
 if record.nameID in names: record.string=names[record.nameID].encode(record.getEncoding())
font.save(ROOT/'ios/EnTil/Resources/EnTilHeadings-Bold.ttf')
print('EnTilHeadings-Bold.ttf: Fraunces SOFT=100, WONK=1, wght=700, opsz=24; OFL retained.')
