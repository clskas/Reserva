"""Petit serveur local pour le workflow « Captures App Store ».

Le test d'intégration (dans le simulateur) appelle
GET http://127.0.0.1:8765/capture?nom=01-accueil ; le serveur prend la capture
avec `xcrun simctl io <UDID> screenshot` et ne répond qu'une fois le fichier écrit,
ce qui synchronise exactement l'écran affiché et la capture.

Usage : python3 serveur_captures.py <UDID> <dossier>
"""

import re
import subprocess
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import parse_qs, urlparse

UDID, DOSSIER = sys.argv[1], sys.argv[2]


class Gestionnaire(BaseHTTPRequestHandler):
    def do_GET(self):
        url = urlparse(self.path)
        nom = parse_qs(url.query).get("nom", [""])[0]
        if url.path != "/capture" or not re.fullmatch(r"[\w-]{1,40}", nom):
            self.send_response(400)
            self.end_headers()
            return
        chemin = f"{DOSSIER}/{nom}.png"
        r = subprocess.run(
            ["xcrun", "simctl", "io", UDID, "screenshot", "--type=png", chemin],
            capture_output=True,
            text=True,
        )
        ok = r.returncode == 0
        print(("📸 " if ok else "❌ ") + chemin + ("" if ok else " " + r.stderr), flush=True)
        self.send_response(200 if ok else 500)
        self.end_headers()
        self.wfile.write(b"ok" if ok else r.stderr.encode())

    def log_message(self, *args):
        pass


HTTPServer(("127.0.0.1", 8765), Gestionnaire).serve_forever()
