import http.server
import urllib.request
import urllib.error
import os

BACKEND = 'http://127.0.0.1:8001'
WEB_ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'build', 'web')

class ProxyHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=WEB_ROOT, **kwargs)

    def do_GET(self):
        if self.path.startswith('/api/') or self.path == '/uploads/':
            self._proxy('GET')
        else:
            super().do_GET()

    def do_POST(self):
        if self.path.startswith('/api/'):
            self._proxy('POST')
        else:
            super().do_POST()

    def do_PUT(self):
        if self.path.startswith('/api/'):
            self._proxy('PUT')
        else:
            super().do_PUT()

    def do_DELETE(self):
        if self.path.startswith('/api/'):
            self._proxy('DELETE')
        else:
            super().do_DELETE()

    def do_PATCH(self):
        if self.path.startswith('/api/'):
            self._proxy('PATCH')
        else:
            super().do_PATCH()

    def _proxy(self, method):
        url = BACKEND + self.path
        content_len = int(self.headers.get('Content-Length', 0))
        body = self.rfile.read(content_len) if content_len > 0 else None
        req = urllib.request.Request(url, data=body, method=method)
        for k, v in self.headers.items():
            if k.lower() in ('host', 'content-length'):
                continue
            req.add_header(k, v)
        try:
            with urllib.request.urlopen(req, timeout=30) as resp:
                self.send_response(resp.status)
                for k, v in resp.headers.items():
                    if k.lower() == 'transfer-encoding':
                        continue
                    self.send_header(k, v)
                self.send_header('Cache-Control', 'no-store')
                self.end_headers()
                self.wfile.write(resp.read())
        except urllib.error.HTTPError as e:
            self.send_response(e.code)
            for k, v in e.headers.items():
                if k.lower() == 'transfer-encoding':
                    continue
                self.send_header(k, v)
            self.send_header('Cache-Control', 'no-store')
            self.end_headers()
            self.wfile.write(e.read())
        except Exception as e:
            self.send_response(502)
            self.end_headers()
            self.wfile.write(f'{{"detail":"Backend unreachable: {e}"}}'.encode())

    def log_message(self, fmt, *args):
        pass  # silent

if __name__ == '__main__':
    print(f'[Server] Serving {WEB_ROOT} + proxy /api/* -> {BACKEND}')
    http.server.HTTPServer(('0.0.0.0', 8000), ProxyHandler).serve_forever()
