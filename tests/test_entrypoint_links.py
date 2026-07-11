import re
from pathlib import Path
from urllib.parse import unquote
import unittest


ROOT = Path(__file__).resolve().parents[1]
ENTRYPOINTS = [
    ROOT / "README.md",
    ROOT / "data/README.md",
    ROOT / "docs/README.md",
    ROOT / "docs/repo-map/HOTSPOTS.md",
    ROOT / "erasave/README.md",
    ROOT / "framework/README.md",
    ROOT / "quest_select_design/README.md",
    ROOT / "recipes/README.md",
    ROOT / "tools/README.md",
]
LINK = re.compile(r"!?\[[^]]*\]\(([^)]+)\)")


class EntrypointLinkTests(unittest.TestCase):
    def test_local_links_resolve(self):
        missing = []
        for document in ENTRYPOINTS:
            for raw_target in LINK.findall(document.read_text(encoding="utf-8")):
                target = raw_target.split("#", 1)[0]
                if not target or "://" in target or target.startswith("mailto:"):
                    continue
                resolved = (document.parent / unquote(target)).resolve()
                if not resolved.exists():
                    missing.append(f"{document.relative_to(ROOT)} -> {target}")
        self.assertEqual([], missing, "Missing local links:\n" + "\n".join(missing))


if __name__ == "__main__":
    unittest.main()
