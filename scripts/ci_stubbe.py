#!/usr/bin/env python3
"""Serverer et øyeblikksbilde av hjemmeserverens svar, lokalt i byggekjøringen.

Byggeserveren står i USA og slipper ikke gjennom brannmuren hjemme. For at skjermbildene
skal vise noe som helst av verdi må dataene være ekte, så de tas med inn i kjøringen som
et komprimert datasett og legges ut her — samme stier, samme kropper. Ingenting finnes
på maskinen etter at jobben er ferdig.
"""
import json
import ssl
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer

datafil, port, cert, nokkel = sys.argv[1], int(sys.argv[2]), sys.argv[3], sys.argv[4]
SVAR = json.load(open(datafil, encoding="utf8"))


class Behandler(BaseHTTPRequestHandler):
    def do_GET(self):
        sti = self.path.split("?")[0]
        kropp = SVAR.get(sti)
        if kropp is None and sti == "/api/health":
            kropp = '{"ok":true}'
        if kropp is None:
            self.send_error(404)
            return
        rå = kropp.encode("utf8")
        self.send_response(200)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(rå)))
        self.end_headers()
        self.wfile.write(rå)

    def log_message(self, *_):
        pass            # stille; loggen er allerede full av simulatorstøy


tjener = HTTPServer(("127.0.0.1", port), Behandler)
kontekst = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
kontekst.load_cert_chain(cert, nokkel)
tjener.socket = kontekst.wrap_socket(tjener.socket, server_side=True)
tjener.serve_forever()
