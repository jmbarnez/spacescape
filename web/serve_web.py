#!/usr/bin/env python3
"""
serve_web.py
-------------------------------------------------------------------------------
Small development HTTP server for the web build of Spacescape.

What this does:
  * Serves the current directory (the web/ folder) over HTTP.
  * Adds the headers required for SharedArrayBuffer / pthreads in browsers:
      - Cross-Origin-Opener-Policy: same-origin
      - Cross-Origin-Embedder-Policy: require-corp
  * Ensures .wasm files are served with the correct MIME type.

Usage (from the web/ folder):

    python serve_web.py --port 8000

Then open:

    http://localhost:8000/

This keeps everything self-contained inside the web/ directory and avoids
modifying your main game code.
"""

import argparse
import http.server
import os
import socketserver
from http.server import SimpleHTTPRequestHandler


class IsolatedHTTPRequestHandler(SimpleHTTPRequestHandler):
    """HTTP handler that adds COOP/COEP headers for cross-origin isolation.

    This is required for SharedArrayBuffer and pthread-enabled love.js builds
    to work in modern browsers.
    """

    # Make sure .wasm is served with the correct MIME type.
    extensions_map = {
        **getattr(SimpleHTTPRequestHandler, "extensions_map", {}),
        ".wasm": "application/wasm",
    }

    def end_headers(self) -> None:  # type: ignore[override]
        # Cross-origin isolation headers:
        #   - COOP ensures the top-level document is isolated from other
        #     browsing contexts.
        #   - COEP requires that all loaded resources are CORS-eligible or
        #     same-origin, which our local files are.
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        super().end_headers()


def main() -> None:
    parser = argparse.ArgumentParser(description="Serve the web build with COOP/COEP headers.")
    parser.add_argument("--port", type=int, default=8000, help="Port to listen on (default: 8000)")
    args = parser.parse_args()

    # Change working directory to the directory that contains this script so
    # that all files are served from the web/ folder.
    script_dir = os.path.dirname(os.path.abspath(__file__))
    os.chdir(script_dir)

    with socketserver.TCPServer(("", args.port), IsolatedHTTPRequestHandler) as httpd:
        print("Serving Spacescape web build on http://localhost:%d/" % args.port)
        print("Press Ctrl+C to stop the server.")
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\nShutting down server...")


if __name__ == "__main__":
    main()
