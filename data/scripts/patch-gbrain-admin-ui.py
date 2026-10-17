#!/usr/bin/env python3
"""Keep GET /admin/login on the embedded admin SPA fallback."""
from pathlib import Path
import sys

TARGET = Path(
    "/usr/local/install/global/node_modules/gbrain/src/commands/serve-http-spa.ts"
)
NEEDLE = " || req.path === '/admin/login'"

text = TARGET.read_text()
if text.count(NEEDLE) != 2:
    sys.exit("admin login route patch target count changed")

TARGET.write_text(text.replace(NEEDLE, ""))
print(f"patched {TARGET}")
