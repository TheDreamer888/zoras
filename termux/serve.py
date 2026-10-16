#!/usr/bin/env python3
"""Servidor estático do ZoraS para Termux.

Serve a pasta public/ com os mesmos cabeçalhos de segurança da configuração
do Caddy. Liga-se apenas a 127.0.0.1: quem chega de fora vem pelo túnel da
Cloudflare, nunca diretamente ao telemóvel.

Uso:  python serve.py [porta]
"""

import os
import sys
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer

_AQUI = os.path.dirname(os.path.abspath(__file__))
# public/ fica ao lado do script, ou um nível acima quando corre dentro do repositório.
RAIZ = next(
    (p for p in (os.path.join(_AQUI, "public"), os.path.join(_AQUI, os.pardir, "public"))
     if os.path.isfile(os.path.join(p, "index.html"))),
    os.path.join(_AQUI, "public"),
)
RAIZ = os.path.normpath(RAIZ)
PORTA = int(sys.argv[1]) if len(sys.argv) > 1 else 8080

# A Cloudflare termina o TLS, por isso o HSTS vai daqui para o browser.
CABECALHOS = {
    "Strict-Transport-Security": "max-age=63072000; includeSubDomains",
    "Content-Security-Policy": (
        "default-src 'none'; script-src 'self'; "
        "style-src 'self' https://fonts.googleapis.com; "
        "font-src https://fonts.gstatic.com; img-src 'self' data:; "
        "connect-src 'none'; form-action 'none'; frame-ancestors 'none'; "
        "base-uri 'none'; object-src 'none'; upgrade-insecure-requests"
    ),
    "X-Content-Type-Options": "nosniff",
    "Referrer-Policy": "strict-origin-when-cross-origin",
    "Cross-Origin-Opener-Policy": "same-origin",
    "Cross-Origin-Resource-Policy": "same-origin",
    "X-Frame-Options": "DENY",
    "Permissions-Policy": (
        "accelerometer=(), camera=(), geolocation=(), gyroscope=(), "
        "magnetometer=(), microphone=(), payment=(), usb=(), interest-cohort=()"
    ),
}

CACHE_LONGA = (".css", ".js", ".woff2", ".png", ".svg", ".jpg", ".webp")


class Handler(SimpleHTTPRequestHandler):
    server_version = "ZoraS"
    sys_version = ""

    def end_headers(self):
        for nome, valor in CABECALHOS.items():
            self.send_header(nome, valor)
        caminho = self.path.split("?", 1)[0]
        if caminho.endswith(CACHE_LONGA):
            self.send_header("Cache-Control", "public, max-age=31536000, immutable")
        else:
            self.send_header("Cache-Control", "no-cache")
        super().end_headers()

    def do_POST(self):
        self.send_error(405, "Method Not Allowed")

    do_PUT = do_DELETE = do_PATCH = do_POST

    def log_message(self, fmt, *args):
        # Sem IPs nos registos: o do túnel seria sempre o mesmo e o do
        # visitante é dado pessoal que não precisamos de guardar.
        sys.stderr.write("%s - %s\n" % (self.log_date_time_string(), fmt % args))


def main():
    if not os.path.isdir(RAIZ):
        sys.exit("Falta a pasta public/ em %s" % RAIZ)
    if not os.path.isfile(os.path.join(RAIZ, "index.html")):
        sys.exit("Falta o index.html dentro de public/")

    handler = partial(Handler, directory=RAIZ)
    with ThreadingHTTPServer(("127.0.0.1", PORTA), handler) as servidor:
        print("ZoraS a servir %s em http://127.0.0.1:%d" % (RAIZ, PORTA))
        print("Para parar: Ctrl+C")
        try:
            servidor.serve_forever()
        except KeyboardInterrupt:
            print("\nServidor parado.")


if __name__ == "__main__":
    main()
