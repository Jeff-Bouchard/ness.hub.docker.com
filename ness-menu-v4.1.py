#!/usr/bin/env python3
import json
import os
import subprocess
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import urlparse

# Simple, dependency-free HTTP bridge for ness-menu-v4.sh
# Exposes a single POST endpoint: /api/menu
# Body: JSON {"action": "...", "profile": "...", "dns_mode": "...", "labels": {...}, ...}
# It shells out to: ./ness-menu-v4.sh api --action <action> [--profile ...] [--dns-mode ...] [--image ...]

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
MENU_SCRIPT = os.path.join(SCRIPT_DIR, "ness-menu-v4.sh")
BASH = os.environ.get("BASH", "bash")
MENU_CMD_BASE = [BASH, MENU_SCRIPT]


class MenuHandler(BaseHTTPRequestHandler):
    def _set_headers(self, status=200, content_type="application/json"):
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()

    def do_OPTIONS(self):
        self.send_response(200)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()

    def do_GET(self):
        """Handle GETs without invoking any actions.

        /api/menu is POST-only; for GET we return a helpful JSON error instead of 501.
        /favicon.ico returns 204 to keep browser happy.
        """
        parsed = urlparse(self.path)
        if parsed.path == "/favicon.ico":
            # No content, just silence the browser's favicon requests
            self.send_response(204)
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()
            return

        if parsed.path == "/api/menu":
            self._set_headers(405)
            self.wfile.write(b"{\"error\":\"Use POST with a JSON body for /api/menu; GET is not supported.\"}")
            return

        self._set_headers(404)
        self.wfile.write(b"{\"error\":\"Not found\"}")

    def do_POST(self):
        parsed = urlparse(self.path)
        if parsed.path != "/api/menu":
            self._set_headers(404)
            self.wfile.write(b"{\"error\":\"Not found\"}")
            return

        length = int(self.headers.get("Content-Length", "0") or "0")
        raw_body = self.rfile.read(length) if length else b"{}"

        try:
            data = json.loads(raw_body.decode("utf-8") or "{}")
        except json.JSONDecodeError as e:
            self._set_headers(400)
            payload = {"error": f"Invalid JSON body: {e}"}
            self.wfile.write(json.dumps(payload).encode("utf-8"))
            return

        action = data.get("action") or ""
        profile = data.get("profile") or ""
        dns_mode = data.get("dns_mode") or ""
        engine = (data.get("engine") or "").strip()
        image = (data.get("image") or
                 (data.get("payload") or {}).get("image"))  # very small convenience

        if not action:
            self._set_headers(400)
            self.wfile.write(b"{\"error\":\"Missing 'action' field in request body\"}")
            return

        if not os.path.isfile(MENU_SCRIPT):
            self._set_headers(500)
            payload = {"error": f"ness-menu-v4.sh not found at {MENU_SCRIPT}"}
            self.wfile.write(json.dumps(payload).encode("utf-8"))
            return

        cmd = MENU_CMD_BASE + ["api", "--action", action]
        if profile:
            cmd.extend(["--profile", profile])
        if dns_mode:
            cmd.extend(["--dns-mode", dns_mode])
        if image:
            cmd.extend(["--image", image])

        # Environment can be extended later (e.g. DNS labels, NRPT hints)
        env = os.environ.copy()
        if engine:
            env["CONTAINER_ENGINE"] = engine

        try:
            proc = subprocess.run(
                cmd,
                cwd=SCRIPT_DIR,
                env=env,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                shell=False,
            )
        except Exception as e:
            self._set_headers(500)
            payload = {"error": f"Failed to execute ness-menu-v4.sh: {e}"}
            self.wfile.write(json.dumps(payload).encode("utf-8"))
            return

        # Prepare a simple JSON response with stdout/stderr and exit code
        payload = {
            "action": action,
            "profile": profile,
            "dns_mode": dns_mode,
            "engine": engine or env.get("CONTAINER_ENGINE", ""),
            "exit_code": proc.returncode,
            "stdout": proc.stdout,
            "stderr": proc.stderr,
        }

        status = 200 if proc.returncode == 0 else 500
        self._set_headers(status)
        self.wfile.write(json.dumps(payload).encode("utf-8"))


def run(addr: str = "127.0.0.1", port: int = 8085) -> None:
    server_address = (addr, port)
    httpd = HTTPServer(server_address, MenuHandler)
    print(f"ness-menu-v4.1 HTTP bridge listening on http://{addr}:{port}/api/menu")
    print(f"Using script: {MENU_SCRIPT}")
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down HTTP bridge...")
        httpd.server_close()


if __name__ == "__main__":
    host = "127.0.0.1"
    port = 8085
    if len(sys.argv) >= 2:
        # Allow 'host:port' or just 'port'
        arg = sys.argv[1]
        if ":" in arg:
            host_part, port_part = arg.split(":", 1)
            host = host_part or host
            try:
                port = int(port_part)
            except ValueError:
                pass
        else:
            try:
                port = int(arg)
            except ValueError:
                pass
    run(host, port)
