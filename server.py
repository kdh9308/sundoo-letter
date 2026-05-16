"""
선두교회 신혼부부회 | 편지 사이트 로컬 서버
Python 3 의 기본 모듈만 사용 (별도 설치 불필요)
- localhost 와 LAN IP 양쪽에서 접속 가능
- /_lan_info JSON 엔드포인트로 QR 페이지에 IP 정보 전달
"""
import http.server
import json
import socketserver
import os
import re
import socket
import sys
import webbrowser
from functools import partial

PORTS = [8000, 8080, 5500, 3000, 9000]
ROOT = os.path.dirname(os.path.abspath(__file__))


def get_lan_ip():
    """외부 연결 시도로 자기 LAN IP 알아내기 (실제 연결은 안 함)."""
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.connect(("8.8.8.8", 80))
        return s.getsockname()[0]
    except Exception:
        return "127.0.0.1"
    finally:
        s.close()


class RangeHTTPRequestHandler(http.server.SimpleHTTPRequestHandler):
    """HTTP Range 요청(영상 스트리밍)을 지원하는 핸들러."""

    # main() 에서 채워주는 값 (LAN URL 등)
    LAN_URL = ""
    LAN_IP = ""
    PORT = 8000

    def do_GET(self):
        # ── 특수 엔드포인트: LAN 정보 JSON ──
        if self.path.startswith("/_lan_info"):
            body = json.dumps({
                "lan_url": self.LAN_URL,
                "lan_ip": self.LAN_IP,
                "port": self.PORT,
            }).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return

        range_header = self.headers.get("Range")
        if not range_header:
            return super().do_GET()

        m = re.match(r"bytes=(\d+)-(\d*)", range_header)
        if not m:
            return super().do_GET()

        path = self.translate_path(self.path)
        if not os.path.isfile(path):
            self.send_error(404, "File not found")
            return

        size = os.path.getsize(path)
        start = int(m.group(1))
        end = int(m.group(2)) if m.group(2) else size - 1
        if end >= size:
            end = size - 1
        length = end - start + 1

        ctype = self.guess_type(path)
        self.send_response(206)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Range", f"bytes {start}-{end}/{size}")
        self.send_header("Content-Length", str(length))
        self.end_headers()

        with open(path, "rb") as f:
            f.seek(start)
            remaining = length
            while remaining > 0:
                chunk = f.read(min(65536, remaining))
                if not chunk:
                    break
                try:
                    self.wfile.write(chunk)
                except (ConnectionAbortedError, BrokenPipeError, ConnectionResetError):
                    break
                remaining -= len(chunk)

    def end_headers(self):
        self.send_header("Accept-Ranges", "bytes")
        self.send_header("Cache-Control", "no-store, no-cache, must-revalidate, max-age=0")
        self.send_header("Pragma", "no-cache")
        self.send_header("Expires", "0")
        super().end_headers()

    def log_message(self, fmt, *args):
        sys.stdout.write(f"  · {self.address_string()} {fmt % args}\n")


def find_port():
    """LAN 접속도 가능하도록 0.0.0.0 에 바인딩 가능한지 확인."""
    for port in PORTS:
        try:
            with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
                s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
                s.bind(("0.0.0.0", port))
            return port
        except OSError:
            continue
    return None


def main():
    os.chdir(ROOT)
    port = find_port()
    if port is None:
        print("\n  [X] 사용 가능한 포트를 찾지 못했어요. (8000/8080/5500/3000/9000 모두 사용 중)\n")
        input("엔터를 눌러 종료: ")
        sys.exit(1)

    lan_ip = get_lan_ip()
    url_local = f"http://localhost:{port}/"
    url_lan   = f"http://{lan_ip}:{port}/"
    url_qr    = f"http://localhost:{port}/qr.html"

    # 핸들러에 LAN 정보 주입 (/_lan_info 엔드포인트가 사용)
    RangeHTTPRequestHandler.LAN_URL = url_lan
    RangeHTTPRequestHandler.LAN_IP = lan_ip
    RangeHTTPRequestHandler.PORT = port

    handler = partial(RangeHTTPRequestHandler, directory=ROOT)

    print()
    print("  ============================================")
    print("    선두교회 신혼부부회 | 편지 사이트")
    print("  ============================================")
    print()
    print(f"    PC 미리보기   : {url_local}")
    print(f"    모바일 QR     : {url_qr}")
    print(f"    LAN 주소      : {url_lan}")
    print(f"    폴더          : {ROOT}")
    print("    종료          : 이 창을 닫거나 Ctrl + C")
    print()
    print("  >> QR 페이지가 자동으로 열립니다.")
    print("  >> 같은 WiFi 의 폰으로 화면의 QR 을 스캔하세요.")
    print()
    print("  ※ 처음 실행 시 Windows 방화벽이 뜨면 '액세스 허용' 을 눌러주세요.")
    print()

    # QR 페이지를 먼저 열어 바로 공유 가능하게 함
    webbrowser.open(url_qr)

    with socketserver.ThreadingTCPServer(("0.0.0.0", port), handler) as httpd:
        httpd.allow_reuse_address = True
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\n  서버를 종료합니다.\n")


if __name__ == "__main__":
    main()
