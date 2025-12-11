#!/usr/bin/env python3
"""NESS status HTTP shim

Listens on port 50880 and exposes a single JSON endpoint:
  GET /status

It runs the existing bash tests in ness-menu-v0.4.2.sh via the API mode:
  - test-dns-realities
  - test-full-node-e2e

and returns a compact JSON document with exit codes, summaries, and timestamps.

This script is intended to be run on the host alongside the NESS stack, e.g.:
  sudo python3 ness-status-http.py

Security notes:
- No request parameters are accepted.
- All subprocess calls have timeouts.
- Output from tests is truncated before being returned in JSON.
"""

import http.server
import json
import os
import socketserver
import subprocess
import sys
import time
import uuid
from typing import Any, Dict

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
MENU_SCRIPT = os.path.join(BASE_DIR, "ness-menu-v0.4.2.sh")
PORT = int(os.environ.get("NESS_STATUS_PORT", "50880"))


def _truncate(text: str, limit: int = 2000) -> str:
    """Return a safely truncated version of text."""
    if not text:
        return ""
    if len(text) <= limit:
        return text
    return text[: limit - 3] + "..."


def run_menu_test(action: str, timeout: int = 60) -> Dict[str, Any]:
    """Run ness-menu-v0.4.2.sh in api mode for a given action.

    Returns a dict with ok, exit_code, duration_sec, summary, stdout_head, stderr_head.
    """
    start = time.time()
    cmd = [MENU_SCRIPT, "api", "--action", action]

    try:
        completed = subprocess.run(
            cmd,
            cwd=BASE_DIR,
            capture_output=True,
            text=True,
            timeout=timeout,
            check=False,
        )
        duration = time.time() - start
        stdout = completed.stdout or ""
        stderr = completed.stderr or ""

        # Build a short summary from the first non-empty line of stdout or stderr.
        merged_lines = (stdout + "\n" + stderr).splitlines()
        summary = ""
        for line in merged_lines:
            if line.strip():
                summary = line.strip()
                break
        if not summary:
            summary = "OK" if completed.returncode == 0 else "Error"

        return {
            "ok": completed.returncode == 0,
            "exit_code": completed.returncode,
            "duration_sec": round(duration, 3),
            "summary": summary,
            "stdout_head": _truncate(stdout),
            "stderr_head": _truncate(stderr),
        }
    except subprocess.TimeoutExpired as e:
        stdout = getattr(e, "stdout", "") or ""
        stderr = getattr(e, "stderr", "") or ""
        return {
            "ok": False,
            "exit_code": None,
            "duration_sec": timeout,
            "summary": f"timeout after {timeout}s running {action}",
            "stdout_head": _truncate(stdout),
            "stderr_head": _truncate(stderr),
        }
    except Exception as e:  # noqa: BLE001
        return {
            "ok": False,
            "exit_code": None,
            "duration_sec": None,
            "summary": f"internal error running {action}: {e.__class__.__name__}",
            "stdout_head": "",
            "stderr_head": "",
        }


class StatusHandler(http.server.BaseHTTPRequestHandler):
    def log_message(self, fmt: str, *args: Any) -> None:  # type: ignore[override]
        """Silence default stdout logging to keep host logs clean."""
        return

    def _send_json(self, status_code: int, payload: Dict[str, Any]) -> None:
        body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(status_code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self) -> None:  # type: ignore[override]
        path = self.path.split("?", 1)[0]
        if path.rstrip("/") == "/status":
            self.handle_status()
        else:
            self._send_json(404, {
                "error": "not_found",
                "path": path,
            })

    def handle_status(self) -> None:
        request_id = str(uuid.uuid4())
        timestamp = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())

        # Run tests sequentially so we do not overload Docker or the node.
        dns_realities = run_menu_test("test-dns-realities")
        full_e2e = run_menu_test("test-full-node-e2e")

        # Derive DNS mode primarily from the dns_realities summary, with a
        # fallback to the DNS_MODE environment variable if necessary.
        dns_mode: Any = None
        summary = str(dns_realities.get("summary", ""))
        lower = summary.lower()
        if "emerdns-only" in lower:
            dns_mode = "emerdns"
        else:
            # Look for the first (...) pair and treat its contents as a
            # candidate mode if it matches known modes like icann/hybrid.
            start = summary.find("(")
            if start != -1:
                end = summary.find(")", start + 1)
                if end != -1:
                    candidate = summary[start + 1 : end].strip()
                    if candidate in {"icann", "hybrid", "emerdns"}:
                        dns_mode = candidate

        if dns_mode is None:
            env_mode = os.environ.get("DNS_MODE")
            if env_mode:
                dns_mode = env_mode

        payload: Dict[str, Any] = {
            "timestamp": timestamp,
            "request_id": request_id,
            "dns_mode": dns_mode,
            "dns_realities": dns_realities,
            "full_e2e": full_e2e,
        }

        self._send_json(200, payload)


def main() -> None:
    if not os.path.isfile(MENU_SCRIPT):
        print(f"ness-menu-v0.4.2.sh not found at {MENU_SCRIPT}", file=sys.stderr)
        sys.exit(1)

    with socketserver.TCPServer(("0.0.0.0", PORT), StatusHandler) as httpd:
        print(f"NESS status HTTP listening on 0.0.0.0:{PORT}", file=sys.stderr)
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\nShutting down NESS status HTTP server.", file=sys.stderr)


if __name__ == "__main__":
    main()
