"""Fail early when a literal SwiftUI image name has no asset catalogue entry."""
from pathlib import Path
import re

root = Path(__file__).resolve().parents[1]
assets = root / 'ios/EnTil/Assets.xcassets'
missing = []
for source in (root / 'ios/EnTil').glob('*.swift'):
    for name in re.findall(r'Image\("([^"\\]+)"\)', source.read_text()):
        if not (assets / f'{name}.imageset' / 'Contents.json').is_file():
            missing.append(f'{source.name}: {name}')
assert not missing, 'Missing native image assets: ' + ', '.join(missing)
print('Literal SwiftUI image assets exist.')
