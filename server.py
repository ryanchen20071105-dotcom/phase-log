#!/usr/bin/env python3
"""阶段日志：本地小服务器。只用标准库。

数据存在同目录的 data.json；每天第一次保存时，把旧文件复制到 backups/。
环境变量：PORT（默认 8790）、DATA_FILE（数据文件路径）、NO_BROWSER=1（不自动打开浏览器）。
"""
import json
import os
import shutil
import socket
import sys
import threading
import webbrowser
from datetime import date
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer

ROOT = os.path.dirname(os.path.abspath(__file__))
DATA = os.environ.get("DATA_FILE", os.path.join(ROOT, "data.json"))
BACKUP_DIR = os.path.join(os.path.dirname(DATA), "backups")
PORT = int(os.environ.get("PORT", 8790))
EMPTY = {"version": 1, "domains": [], "phases": [], "entries": []}
LOCK = threading.Lock()


def load():
    if not os.path.exists(DATA):
        return dict(EMPTY)
    with open(DATA, encoding="utf-8") as f:
        return json.load(f)


def save(data):
    with LOCK:
        if os.path.exists(DATA):
            os.makedirs(BACKUP_DIR, exist_ok=True)
            bak = os.path.join(BACKUP_DIR, f"data-{date.today().isoformat()}.json")
            if not os.path.exists(bak):
                shutil.copy2(DATA, bak)
        tmp = DATA + ".tmp"
        with open(tmp, "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, indent=1)
        os.replace(tmp, DATA)


class Handler(SimpleHTTPRequestHandler):
    def __init__(self, *a, **k):
        super().__init__(*a, directory=ROOT, **k)

    def log_message(self, *a):
        pass

    def _json(self, code, obj):
        body = json.dumps(obj, ensure_ascii=False).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        path = self.path.split("?")[0]
        if path == "/api/data":
            return self._json(200, load())
        if path in ("/", "/index.html"):
            self.path = "/index.html"
            return super().do_GET()
        self.send_error(404)

    def do_PUT(self):
        if self.path != "/api/data":
            return self.send_error(404)
        try:
            n = int(self.headers.get("Content-Length", 0))
            data = json.loads(self.rfile.read(n).decode("utf-8"))
            if not all(isinstance(data.get(k), list) for k in ("domains", "phases", "entries")):
                raise ValueError("bad shape")
        except Exception as e:
            return self._json(400, {"ok": False, "error": str(e)})
        save(data)
        self._json(200, {"ok": True})


def main():
    url = f"http://127.0.0.1:{PORT}/"
    try:
        server = ThreadingHTTPServer(("127.0.0.1", PORT), Handler)
    except OSError:
        # 已经在运行：直接打开页面
        print(f"端口 {PORT} 已被占用，可能已经在运行。打开 {url}")
        if not os.environ.get("NO_BROWSER"):
            webbrowser.open(url)
        sys.exit(0)
    print(f"阶段日志已启动：{url}\n数据文件：{DATA}\n关掉这个窗口或按 Ctrl+C 即停止。")
    if not os.environ.get("NO_BROWSER"):
        threading.Timer(0.5, webbrowser.open, args=(url,)).start()
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
