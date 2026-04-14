#!/usr/bin/env python3
import json
import os
import subprocess
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import urlparse

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
MENU_SCRIPT = os.path.join(SCRIPT_DIR, "menu")
CONTROL_PAGE = os.path.join(SCRIPT_DIR, "ness-control-live.html")
BASH = os.environ.get("BASH", "bash")

ACTIONS = {
    "start": "1",
    "stop": "2",
    "restart": "3",
    "status": "4",
    "logs": "5",
    "health": "6",
    "pull": "7",
    "cleanup": "8",
}


def run_menu_action(action: str):
    if action not in ACTIONS:
        return 400, {"error": f"Unsupported action: {action}"}

    if not os.path.isfile(MENU_SCRIPT):
        return 500, {"error": f"menu script not found at {MENU_SCRIPT}"}

    # Feed: action + Enter for pause + quit
    payload = f"{ACTIONS[action]}\n\n0\n"

    try:
        proc = subprocess.run(
            [BASH, MENU_SCRIPT],
            input=payload,
            cwd=SCRIPT_DIR,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=180,
            shell=False,
        )
    except subprocess.TimeoutExpired:
        return 500, {"error": "menu action timed out"}
    except Exception as e:
        return 500, {"error": f"failed to execute menu: {e}"}

    status = 200 if proc.returncode == 0 else 500
    return status, {
        "action": action,
        "exit_code": proc.returncode,
        "stdout": proc.stdout,
        "stderr": proc.stderr,
    }


class Handler(BaseHTTPRequestHandler):
    def _send_html(self, path: str):
        if not os.path.isfile(path):
            self._json(404, {"error": f"file not found: {os.path.basename(path)}"})
            return

        with open(path, "rb") as f:
            content = f.read()

        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()
        self.wfile.write(content)

    def _json(self, status=200, data=None):
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()
        self.wfile.write(json.dumps(data or {}).encode("utf-8"))

    def do_OPTIONS(self):
        self._json(200, {"ok": True})

    def do_GET(self):
        parsed = urlparse(self.path)
        if parsed.path in ("/", "/index.html", "/ness-control-live.html"):
            self._send_html(CONTROL_PAGE)
            return
        if parsed.path == "/api/health":
            self._json(200, {"ok": True, "service": "ness-menu-live-api"})
            return
        self._json(404, {"error": "not found"})

    def do_POST(self):
        parsed = urlparse(self.path)
        if parsed.path == "/api/health":
            self._json(200, {"ok": True, "service": "ness-menu-live-api"})
            return

        if parsed.path != "/api/menu":
            self._json(404, {"error": "not found"})
            return

        try:
            length = int(self.headers.get("Content-Length", "0"))
        except ValueError:
            length = 0

        raw = self.rfile.read(length) if length else b"{}"
        try:
            body = json.loads(raw.decode("utf-8") or "{}")
        except json.JSONDecodeError:
            self._json(400, {"error": "invalid JSON"})
            return

        action = (body.get("action") or "").strip().lower()
        status, payload = run_menu_action(action)
        self._json(status, payload)


def run(host="127.0.0.1", port=8091):
    server = HTTPServer((host, port), Handler)
    print(f"ness-menu-live-api listening on http://{host}:{port}")
    print(f"using menu script: {MENU_SCRIPT}")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == "__main__":
    run()
