#!/usr/bin/env python3
"""Patch upstream GBrain admin routes for Docker wrapper deployments.

The upstream ref currently serves the embedded admin SPA only for /admin/*,
leaving /admin as a 404 and excluding GET /admin/login from the SPA fallback.
Its /admin/events SSE endpoint also sends headers but no initial bytes, which
can leave browser EventSource state stuck at "connecting" behind proxies.
"""
from pathlib import Path
import sys

ROOT = Path("/usr/local/install/global/node_modules/gbrain")
TARGET = ROOT / "src/commands/serve-http.ts"

text = TARGET.read_text()

old_sse = """    res.flushHeaders();\n\n    sseClients.add(res);\n    req.on('close', () => sseClients.delete(res));\n"""
new_sse = """    res.flushHeaders();\n    // Send an immediate comment frame so browsers/proxies mark the\n    // EventSource as open even before real activity arrives. Without this,\n    // the dashboard can sit at \"Live Activity ● connecting...\" indefinitely\n    // on quiet brains. Heartbeats keep idle reverse-proxy connections alive.\n    res.write(': connected\\n\\n');\n\n    const heartbeat = setInterval(() => {\n      res.write(': heartbeat\\n\\n');\n    }, 25000);\n\n    sseClients.add(res);\n    req.on('close', () => {\n      clearInterval(heartbeat);\n      sseClients.delete(res);\n    });\n"""
if old_sse not in text:
    sys.exit("SSE patch target not found")
text = text.replace(old_sse, new_sse, 1)

old_dev = """  if (useDevPath) {\n    app.use('/admin', express.static(adminDistPath));\n    app.get('/admin/{*path}', (req: Request, res: Response, next: NextFunction) => {\n      if (req.path.startsWith('/admin/api/') || req.path === '/admin/events' || req.path === '/admin/login') {\n        return next();\n      }\n      res.sendFile(path.join(adminDistPath, 'index.html'));\n    });\n  } else {\n"""
new_dev = """  if (useDevPath) {\n    app.use('/admin', express.static(adminDistPath));\n    app.get('/admin', (_req: Request, res: Response) => {\n      res.sendFile(path.join(adminDistPath, 'index.html'));\n    });\n    app.get('/admin/{*path}', (req: Request, res: Response, next: NextFunction) => {\n      if (req.path.startsWith('/admin/api/') || req.path === '/admin/events') {\n        return next();\n      }\n      res.sendFile(path.join(adminDistPath, 'index.html'));\n    });\n  } else {\n"""
if old_dev not in text:
    sys.exit("dev admin route patch target not found")
text = text.replace(old_dev, new_dev, 1)

old_embedded = """    app.get('/admin/{*path}', (req: Request, res: Response, next: NextFunction) => {\n      if (req.path.startsWith('/admin/api/') || req.path === '/admin/events' || req.path === '/admin/login') {\n        return next();\n      }\n      const hit = ADMIN_ASSETS[req.path];\n"""
new_embedded = """    app.get('/admin', (_req: Request, res: Response) => {\n      if (ADMIN_INDEX_HTML) {\n        res.setHeader('Content-Type', ADMIN_INDEX_HTML.mime);\n        res.send(loadAsset(ADMIN_INDEX_HTML));\n        return;\n      }\n      res.status(404).send('admin SPA not available');\n    });\n    app.get('/admin/{*path}', (req: Request, res: Response, next: NextFunction) => {\n      if (req.path.startsWith('/admin/api/') || req.path === '/admin/events') {\n        return next();\n      }\n      const hit = ADMIN_ASSETS[req.path];\n"""
if old_embedded not in text:
    sys.exit("embedded admin route patch target not found")
text = text.replace(old_embedded, new_embedded, 1)

TARGET.write_text(text)
print(f"patched {TARGET}")
