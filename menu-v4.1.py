#!/usr/bin/env python3
import json
import os
import subprocess
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import urlparse

# Simple, dependency-free HTTP bridge for menuv4.sh
# Exposes a single POST endpoint: /api/menu
# Body: JSON {"action": "...", "profile": "...", "dns_mode": "...", "labels": {...}, ...}
# It shells out to: ./menuv4.sh api --action <action> [--profile ...] [--dns-mode ...] [--image ...]

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
MENU_SCRIPT = os.path.join(SCRIPT_DIR, "menuv4.sh")
BASH = os.environ.get("BASH", "bash")
MENU_CMD_BASE = [BASH, MENU_SCRIPT]

API_KEY_ENV_VAR = "NESS_MENU_API_KEY"  # legacy shared secret
API_KEY_HEADER = "X-API-Key"  # legacy header, still accepted

EMERSSH_ENV_VAR = "NESS_MENU_EMERSSH_PUBKEY"  # OpenSSH-style public key string
EMERSSH_HEADER = "X-EmerSSH-Key"

SSL_SERIAL_ENV_VAR = "NESS_MENU_SSL_SERIAL"  # e.g. client certificate serial
SSL_SERIAL_HEADER = "X-SSL-Serial"

ALLOWED_ORIGINS_ENV_VAR = "NESS_MENU_ALLOWED_ORIGINS"
ALLOWED_ORIGINS = [
    origin.strip()
    for origin in os.environ.get(ALLOWED_ORIGINS_ENV_VAR, "").split(",")
    if origin.strip()
]

REQUIRED_EMERSSH_KEY = os.environ.get(EMERSSH_ENV_VAR, "")
REQUIRED_SSL_SERIAL = os.environ.get(SSL_SERIAL_ENV_VAR, "")
LEGACY_API_KEY = os.environ.get(API_KEY_ENV_VAR, "")


class MenuHandler(BaseHTTPRequestHandler):
    def _is_origin_allowed(self, origin):
        if not origin:
            return False
        if ALLOWED_ORIGINS:
            return origin in ALLOWED_ORIGINS
        return False

    def _is_authenticated(self):
        # Prefer explicit EmerSSH public key if configured
        if REQUIRED_EMERSSH_KEY:
            provided = self.headers.get(EMERSSH_HEADER, "")
            return provided == REQUIRED_EMERSSH_KEY

        # Fallback: SSL serial number if configured
        if REQUIRED_SSL_SERIAL:
            provided = self.headers.get(SSL_SERIAL_HEADER, "")
            return provided == REQUIRED_SSL_SERIAL

        # Legacy mode: simple shared API key
        if LEGACY_API_KEY:
            provided = self.headers.get(API_KEY_HEADER, "")
            return provided == LEGACY_API_KEY

        # No credentials configured -> remain locked down (401)
        return False

    def _set_headers(self, status=200, content_type="application/json"):
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        origin = self.headers.get("Origin")
        if origin and self._is_origin_allowed(origin):
            self.send_header("Access-Control-Allow-Origin", origin)
        self.end_headers()

    def do_OPTIONS(self):
        origin = self.headers.get("Origin")
        if not origin or not self._is_origin_allowed(origin):
            self.send_response(403)
            self.end_headers()
            return
        self.send_response(200)
        self.send_header("Access-Control-Allow-Origin", origin)
        self.send_header("Access-Control-Allow-Methods", "POST, OPTIONS")
        self.send_header(
            "Access-Control-Allow-Headers",
            "Content-Type, X-API-Key, X-EmerSSH-Key, X-SSL-Serial",
        )
        self.end_headers()

    def do_GET(self):
        """Handle GETs without invoking any actions.

        /api/menu is POST-only; for GET we just report bridge status.
        /favicon.ico returns 204 to keep browser happy.
        """
        parsed = urlparse(self.path)
        if parsed.path == "/favicon.ico":
            # No content, just silence the browser's favicon requests
            self.send_response(204)
            origin = self.headers.get("Origin")
            if origin and self._is_origin_allowed(origin):
                self.send_header("Access-Control-Allow-Origin", origin)
            self.end_headers()
            return

        if parsed.path == "/api/menu":
            self._set_headers(200)
            self.wfile.write(b"{\"status\":\"ness-menu-v4.1 bridge alive\",\"hint\":\"This endpoint expects POST JSON from the UI; no action was run for this GET.\"}")
            return

        self._set_headers(404)
        self.wfile.write(b"{\"error\":\"Not found\"}")

    def do_POST(self):
        parsed = urlparse(self.path)
        if parsed.path != "/api/menu":
            self._set_headers(404)
            self.wfile.write(b"{\"error\":\"Not found\"}")
            return

        origin = self.headers.get("Origin")
        if origin and not self._is_origin_allowed(origin):
            self._set_headers(403)
            self.wfile.write(b"{\"error\":\"Origin not allowed\"}")
            return

        if not self._is_authenticated():
            self._set_headers(401)
            self.wfile.write(b"{\"error\":\"Missing or invalid API key\"}")
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

        identity = data.get("identity") or {}
        emer_id_name = (identity.get("id_name") or identity.get("nvs_name") or "").strip()
        emer_id_scheme = (identity.get("scheme") or "").strip()

        if not emer_id_name:
            emer_id_name = (self.headers.get("X-Emer-ID-Name") or "").strip()
        if not emer_id_scheme:
            emer_id_scheme = (self.headers.get("X-Emer-ID-Scheme") or "").strip()
        image = (data.get("image") or
                 (data.get("payload") or {}).get("image"))  # very small convenience

        if not action:
            self._set_headers(400)
            self.wfile.write(b"{\"error\":\"Missing 'action' field in request body\"}")
            return

        if not os.path.isfile(MENU_SCRIPT):
            self._set_headers(500)
            payload = {"error": f"menuv4.sh not found at {MENU_SCRIPT}"}
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

        # Demux-style identity: forward opaque ID names/schemes for downstream tools
        if emer_id_name:
            env["NESS_ID_NAME"] = emer_id_name
        if emer_id_scheme:
            env["NESS_ID_SCHEME"] = emer_id_scheme

        # Forward identity hints for downstream tools (e.g. EmerSSH / EmerSSL aware scripts)
        emerssh_key = self.headers.get(EMERSSH_HEADER)
        if emerssh_key:
            env["NESS_EMERSSH_KEY"] = emerssh_key
        ssl_serial = self.headers.get(SSL_SERIAL_HEADER)
        if ssl_serial:
            env["NESS_SSL_SERIAL"] = ssl_serial

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
            payload = {"error": f"Failed to execute menuv4.sh: {e}"}
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

    def log_message(self, format, *args):  # noqa: D401
        """Control server logging.

        Suppress noisy GET logs for /api/menu and /favicon.ico so that the
        terminal mostly shows real POST actions initiated by the UI.
        """
        if getattr(self, "command", "") == "GET":
            path = getattr(self, "path", "")
            if path.startswith("/api/menu") or path.startswith("/favicon.ico"):
                return
        super().log_message(format, *args)


def run(addr: str = "127.0.0.1", port: int = 8085) -> None:
    server_address = (addr, port)
    httpd = HTTPServer(server_address, MenuHandler)
    print(f"menu-v4.1 HTTP bridge listening on http://{addr}:{port}/api/menu")
    print(f"Using script: {MENU_SCRIPT}")

    if REQUIRED_EMERSSH_KEY:
        print(
            f"Auth: expecting EmerSSH public key via {EMERSSH_HEADER} "
            f"(env {EMERSSH_ENV_VAR})."
        )
    elif REQUIRED_SSL_SERIAL:
        print(
            f"Auth: expecting SSL serial via {SSL_SERIAL_HEADER} "
            f"(env {SSL_SERIAL_ENV_VAR})."
        )
    elif LEGACY_API_KEY:
        print(
            f"Auth: expecting legacy API key via {API_KEY_HEADER} "
            f"(env {API_KEY_ENV_VAR})."
        )
    else:
        print("No auth secret configured; POST /api/menu will return 401.")

    if not ALLOWED_ORIGINS:
        print(
            f"{ALLOWED_ORIGINS_ENV_VAR} is not set; no browser origins are "
            "allowed by CORS."
        )
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
