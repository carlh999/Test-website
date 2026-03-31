#!/usr/bin/env python3
"""Simple local HTTP server for the test website."""

import http.server
import socketserver
import socket
import os

PORT = 8080
DIR  = os.path.dirname(os.path.abspath(__file__))

def get_local_ip():
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except Exception:
        return "127.0.0.1"

class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=DIR, **kwargs)

    def log_message(self, format, *args):
        print(f"  {self.address_string()} → {format % args}")

if __name__ == "__main__":
    ip = get_local_ip()
    with socketserver.TCPServer(("", PORT), Handler) as httpd:
        httpd.allow_reuse_address = True
        print()
        print("  Constellation is live!")
        print()
        print(f"  Local:   http://localhost:{PORT}")
        print(f"  iPad:    http://{ip}:{PORT}  ← open this on your iPad")
        print()
        print("  Press Ctrl+C to stop.")
        print()
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\n  Server stopped.")
