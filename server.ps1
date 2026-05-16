# ============================================
# 선두교회 신혼부부회 ｜ 로컬 웹서버
# ============================================
# Windows 10/11에 기본 포함된 PowerShell 만으로
# index.html 을 http://localhost 로 열어주는 미니 서버입니다.
# (별도 설치 / 회원가입 불필요)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$root = $PSScriptRoot

# 사용할 포트 후보 (앞 포트가 막혀 있으면 다음 후보로)
$ports = @(8000, 8080, 5500, 3000, 9000)

$mime = @{
    '.html' = 'text/html; charset=utf-8'
    '.htm'  = 'text/html; charset=utf-8'
    '.css'  = 'text/css; charset=utf-8'
    '.js'   = 'application/javascript; charset=utf-8'
    '.json' = 'application/json; charset=utf-8'
    '.mp4'  = 'video/mp4'
    '.webm' = 'video/webm'
    '.mp3'  = 'audio/mpeg'
    '.wav'  = 'audio/wav'
    '.png'  = 'image/png'
    '.jpg'  = 'image/jpeg'
    '.jpeg' = 'image/jpeg'
    '.gif'  = 'image/gif'
    '.svg'  = 'image/svg+xml'
    '.ico'  = 'image/x-icon'
    '.woff' = 'font/woff'
    '.woff2'= 'font/woff2'
    '.ttf'  = 'font/ttf'
    '.txt'  = 'text/plain; charset=utf-8'
}

# ── 사용 가능한 포트 찾기 ──
$listener = $null
$port = $null
foreach ($p in $ports) {
    try {
        $l = New-Object System.Net.HttpListener
        $l.Prefixes.Add("http://localhost:$p/")
        $l.Start()
        $listener = $l
        $port = $p
        break
    } catch {
        try { $l.Stop() } catch {}
    }
}

if (-not $listener) {
    Write-Host ""
    Write-Host "  [X] 사용 가능한 포트를 찾지 못했어요." -ForegroundColor Red
    Write-Host "      다른 프로그램이 8000, 8080, 5500, 3000, 9000 을 모두 쓰고 있어요." -ForegroundColor Yellow
    Write-Host ""
    Read-Host "엔터를 눌러 종료"
    exit 1
}

$url = "http://localhost:$port/"

Write-Host ""
Write-Host "  ============================================" -ForegroundColor Magenta
Write-Host "    선두교회 신혼부부회 | 편지 사이트" -ForegroundColor Magenta
Write-Host "  ============================================" -ForegroundColor Magenta
Write-Host ""
Write-Host "    주소  : $url" -ForegroundColor White
Write-Host "    폴더  : $root" -ForegroundColor Gray
Write-Host "    종료  : 이 창을 닫거나 Ctrl + C" -ForegroundColor Gray
Write-Host ""
Write-Host "  >> 잠시 후 브라우저가 자동으로 열립니다." -ForegroundColor Cyan
Write-Host ""

Start-Process $url

# ── 메인 루프 ──
while ($listener.IsListening) {
    try {
        $ctx = $listener.GetContext()
    } catch { break }

    $req = $ctx.Request
    $res = $ctx.Response

    try {
        $path = [System.Uri]::UnescapeDataString($req.Url.AbsolutePath)
        if ($path -eq '/' -or [string]::IsNullOrEmpty($path)) { $path = '/index.html' }

        # 경로 traversal 방지
        $rel = $path.TrimStart('/').Replace('/', '\')
        $file = [IO.Path]::GetFullPath((Join-Path $root $rel))
        $rootFull = [IO.Path]::GetFullPath($root)
        if (-not $file.StartsWith($rootFull, [StringComparison]::OrdinalIgnoreCase)) {
            $res.StatusCode = 403
            $res.Close()
            continue
        }

        if (Test-Path -LiteralPath $file -PathType Leaf) {
            $ext = [IO.Path]::GetExtension($file).ToLower()
            $ct = if ($mime.ContainsKey($ext)) { $mime[$ext] } else { 'application/octet-stream' }
            $res.ContentType = $ct
            $res.Headers.Add('Accept-Ranges', 'bytes')
            $res.Headers.Add('Cache-Control', 'no-cache')

            $fs = [IO.File]::Open($file, 'Open', 'Read', 'Read')
            try {
                $total = $fs.Length
                $rangeHdr = $req.Headers['Range']

                # ── Range 요청 처리 (영상 스트리밍) ──
                if ($rangeHdr -and $rangeHdr -match 'bytes=(\d+)-(\d*)') {
                    $start = [int64]$Matches[1]
                    $end = if ($Matches[2]) { [int64]$Matches[2] } else { $total - 1 }
                    if ($end -ge $total) { $end = $total - 1 }
                    $len = $end - $start + 1

                    $res.StatusCode = 206
                    $res.Headers.Add('Content-Range', "bytes $start-$end/$total")
                    $res.ContentLength64 = $len
                    $fs.Seek($start, 'Begin') | Out-Null

                    $buf = New-Object byte[] 65536
                    $remaining = $len
                    while ($remaining -gt 0) {
                        $toRead = [Math]::Min([int64]$buf.Length, $remaining)
                        $read = $fs.Read($buf, 0, [int]$toRead)
                        if ($read -le 0) { break }
                        $res.OutputStream.Write($buf, 0, $read)
                        $remaining -= $read
                    }
                } else {
                    $res.ContentLength64 = $total
                    $buf = New-Object byte[] 65536
                    while ($true) {
                        $read = $fs.Read($buf, 0, $buf.Length)
                        if ($read -le 0) { break }
                        $res.OutputStream.Write($buf, 0, $read)
                    }
                }
            } finally {
                $fs.Close()
            }
        } else {
            $res.StatusCode = 404
            $body = [Text.Encoding]::UTF8.GetBytes("404 Not Found: $path")
            $res.ContentType = 'text/plain; charset=utf-8'
            $res.ContentLength64 = $body.Length
            $res.OutputStream.Write($body, 0, $body.Length)
        }
    } catch {
        # 클라이언트 연결 끊김 등 -- 무시
    } finally {
        try { $res.Close() } catch {}
    }
}
