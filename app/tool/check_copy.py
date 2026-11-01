#!/usr/bin/env python3
"""Opens the output of tool/build_pages.sh in a real browser and looks a word up in the copy.

Outages are rare, so nothing else would show that the copy stopped working. Served from here, the
app cannot reach the website: the API allows only the origin of the web app. So it falls back the
way it would in an outage. Flutter draws on a canvas, so the check reads the accessibility tree.
"""

import http.server
import os
import shutil
import subprocess
import sys
import tempfile
import threading
from pathlib import Path

WEB = Path(__file__).resolve().parent.parent / "build" / "web"
TIMEOUT = 120
PAGE = rb"""<!doctype html>
<iframe id="app" src="/?q=dog" width="500" height="800"></iframe>
<script>
  setInterval(() => {
    const page = document.getElementById("app").contentDocument;
    page?.querySelector("flt-semantics-placeholder")?.click();
    const tree = page?.querySelector("flt-semantics-host")?.outerHTML ?? "";
    if (/copy of the dictionary from/.test(tree) && /\bpes\b/.test(tree)) {
      fetch("/found", { method: "POST" });
    }
  }, 500);
</script>
"""


class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=WEB, **kwargs)

    def do_GET(self):
        if self.path != "/check.html":
            super().do_GET()
            return
        self.send_response(200)
        self.send_header("Content-Type", "text/html")
        self.send_header("Content-Length", str(len(PAGE)))
        self.end_headers()
        self.wfile.write(PAGE)

    def do_POST(self):
        self.send_response(204)
        self.end_headers()
        self.server.found.set()

    def log_message(self, *args):
        pass


def browser():
    for name in (os.environ.get("CHROME_EXECUTABLE"), "google-chrome", "chromium"):
        if name and (path := shutil.which(name)):
            return path
    sys.exit("No Chrome or Chromium: set CHROME_EXECUTABLE.")


def main():
    server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    server.found = threading.Event()
    threading.Thread(target=server.serve_forever, daemon=True).start()
    with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as profile, open(Path(profile) / "log", "w+") as log:
        chrome = subprocess.Popen(
            [
                browser(),
                "--headless=new",
                # only our own build runs here, and runners may not allow the sandbox
                "--no-sandbox",
                "--enable-logging=stderr",
                "--lang=en",
                f"--user-data-dir={profile}",
                f"http://127.0.0.1:{server.server_port}/check.html",
            ],
            stdout=subprocess.DEVNULL,
            stderr=log,
        )
        try:
            answered = server.found.wait(TIMEOUT)
        finally:
            chrome.terminate()
            chrome.wait()
        if answered:
            print("The copy of the dictionary answers in the browser.")
            return
        log.seek(0)
        print(*(line for line in log if "CONSOLE" in line), sep="", file=sys.stderr)
    sys.exit(f"No result from the copy in {TIMEOUT} s.")


if __name__ == "__main__":
    main()
