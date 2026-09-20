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

project = (root / 'ios/EnTil.xcodeproj/project.pbxproj').read_text()
resources = project.split('/* Begin PBXResourcesBuildPhase section */')[1].split('/* End PBXResourcesBuildPhase section */')[0]
missing_fixtures = [p.name for p in (root / 'ios/EnTil/Resources/Fixtures').glob('*.json')
                    if f'/* {p.name} in Resources */' not in resources]
assert not missing_fixtures, 'Regenerate the Xcode project to bundle fixtures: ' + ', '.join(missing_fixtures)
print('Snapshot fixtures are registered in Xcode resources.')

# PNG IHDR dimensions: prevent thumbnail-sized production sprites from returning.
import struct
for name, minimum in [("BrandLogo", 1000)] + [(f"Character-{i}", 250) for i in range(12)]:
    data = (assets / f"{name}.imageset/art.png").read_bytes()
    assert data[:8] == b"\x89PNG\r\n\x1a\n", f"{name}: expected PNG"
    width, height = struct.unpack(">II", data[16:24])
    assert max(width, height) >= minimum, f"{name}: {width}x{height} is too small for production"
print("Logo and character source resolutions pass.")
