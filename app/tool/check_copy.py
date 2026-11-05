#!/usr/bin/env python3
"""The fallback and the separate API origin can regress without breaking normal search."""

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
  let speaking = false;
  setInterval(() => {
    const page = document.getElementById("app").contentDocument;
    page?.querySelector("flt-semantics-placeholder")?.click();
    const tree = page?.querySelector("flt-semantics-host")?.outerHTML ?? "";
    if (speaking || !/copy of the dictionary from/.test(tree) || !/\bpes\b/.test(tree)) return;
    const button = [...page.querySelectorAll('[role="button"]')].find(element =>
      (element.getAttribute("aria-label") ?? element.textContent).trim() === "Speak pronunciation");
    if (!button) return;
    speaking = true;
    page.defaultView.HTMLMediaElement.prototype.play = function () {
      const url = new URL(this.src);
      const correct = url.origin === "https://easydict.jiri.one" &&
        url.pathname === "/api/speech" && url.searchParams.get("lang") === "eng" &&
        url.searchParams.get("q") === "dog";
      fetch(correct ? "/found" : "/failed", { method: "POST", body: this.src });
      return Promise.resolve();
    };
    button.click();
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
        if self.path not in ("/found", "/failed"):
            self.send_error(404)
            return
        if self.path == "/failed":
            self.server.error = self.rfile.read(int(self.headers.get("Content-Length", 0))).decode()
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
    server.error = None
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
        if answered and server.error is not None:
            sys.exit(f"The speaker called the wrong API: {server.error}")
        if answered:
            print("The dictionary copy answers and the speaker calls the website API.")
            return
        log.seek(0)
        print(*(line for line in log if "CONSOLE" in line), sep="", file=sys.stderr)
    sys.exit(f"No result and speech request from the copy in {TIMEOUT} s.")


if __name__ == "__main__":
    main()
