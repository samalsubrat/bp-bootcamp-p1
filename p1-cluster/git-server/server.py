"""Read-only Git smart-HTTP server for the self-hosted P1 classroom stand-in.

Serves every bare repository under /git through `git http-backend` (clone/fetch only, no push).
submit.sh places repositories there with `kubectl cp`; Argo CD reads them over HTTP.
"""
import os
import subprocess
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

ROOT = os.environ.get("GIT_PROJECT_ROOT", "/git")


class GitHandler(BaseHTTPRequestHandler):
    def _run(self):
        path, _, query = self.path.partition("?")
        if "git-receive-pack" in self.path:  # read-only: transport is submit.sh, never push
            self.send_error(403, "push disabled")
            return
        length = int(self.headers.get("Content-Length") or 0)
        body = self.rfile.read(length) if length else b""
        env = {
            "PATH": os.environ["PATH"],
            "GIT_PROJECT_ROOT": ROOT,
            "GIT_HTTP_EXPORT_ALL": "1",
            "REQUEST_METHOD": self.command,
            "PATH_INFO": path,
            "QUERY_STRING": query,
            "CONTENT_TYPE": self.headers.get("Content-Type", ""),
            "CONTENT_LENGTH": str(len(body)),
            "REMOTE_ADDR": self.client_address[0],
            "HTTP_GIT_PROTOCOL": self.headers.get("Git-Protocol", ""),
        }
        result = subprocess.run(["git", "http-backend"], input=body, env=env, capture_output=True)
        if result.returncode != 0 or not result.stdout:
            message = result.stderr.decode("utf-8", "replace").strip() or "git http-backend produced no output"
            print(f"BACKEND_ERROR {self.command} {self.path}: {message}")
            self.send_error(500, message[:200])
            return
        head, _, payload = result.stdout.partition(b"\r\n\r\n")
        status, headers = 200, []
        for line in head.decode("latin-1").split("\r\n"):
            if not line:
                continue
            name, _, value = line.partition(":")
            if name.lower() == "status":
                status = int(value.strip().split()[0])
            else:
                headers.append((name, value.strip()))
        self.send_response(status)
        for name, value in headers:
            self.send_header(name, value)
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

    do_GET = _run
    do_POST = _run


if __name__ == "__main__":
    os.makedirs(ROOT, exist_ok=True)
    ThreadingHTTPServer(("0.0.0.0", 8000), GitHandler).serve_forever()
