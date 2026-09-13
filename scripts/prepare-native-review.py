"""Create a lightweight XCTest review export; original PNG artifacts remain separate."""
import json
from pathlib import Path
import shutil
import subprocess
import sys

source, destination = map(Path, sys.argv[1:])
destination.mkdir(parents=True, exist_ok=True)
manifest = json.loads((source / "manifest.json").read_text())
for group in manifest:
    group["attachments"] = [a for a in group["attachments"]
                            if Path(a["exportedFileName"]).suffix.lower() in (".png", ".jpg", ".txt")]
    for attachment in group["attachments"]:
        original = source / attachment["exportedFileName"]
        target = destination / original.name
        if original.suffix.lower() == ".png":
            target = target.with_suffix(".jpg")
            if not target.exists():
                subprocess.run([
                    "sips", "-s", "format", "jpeg", "-s", "formatOptions", "85",
                    str(original), "--out", str(target),
                ], check=True, stdout=subprocess.DEVNULL)
        elif not target.exists():
            shutil.copy2(original, target)
        attachment["exportedFileName"] = target.name
(destination / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")
print(f"Review export: {destination}")
