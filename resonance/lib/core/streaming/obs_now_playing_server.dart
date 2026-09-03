import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:resonance/domain/entities/playback_state.dart';

final class ObsNowPlayingServer {
  ObsNowPlayingServer({this.preferredPort = 17654});

  final int preferredPort;
  HttpServer? _server;
  Map<String, Object?> _snapshot = const {
    'active': false,
    'playing': false,
    'title': 'Resonance',
    'artist': 'Ожидание воспроизведения',
    'artworkUrl': null,
    'positionMs': 0,
    'durationMs': 0,
  };

  bool get running => _server != null;
  int? get port => _server?.port;
  Uri? get uri => port == null ? null : Uri.parse('http://127.0.0.1:$port/');

  Future<void> start() async {
    if (_server != null) return;
    final server = await HttpServer.bind(
      InternetAddress.loopbackIPv4,
      preferredPort,
      shared: false,
    );
    _server = server;
    unawaited(_serve(server));
  }

  void update(ResonancePlaybackState state) {
    final track = state.currentTrack;
    _snapshot = {
      'active': track != null,
      'playing': state.playing,
      'title': track?.title ?? 'Resonance',
      'artist': track?.artist ?? 'Ожидание воспроизведения',
      'album': track?.album,
      'artworkUrl': track?.artworkUrl?.toString(),
      'positionMs': state.position.inMilliseconds,
      'durationMs': state.duration.inMilliseconds,
      'provider': state.activeTrackSource?.provider.name,
    };
  }

  Future<void> stop() async {
    final server = _server;
    _server = null;
    await server?.close(force: true);
  }

  Future<void> _serve(HttpServer server) async {
    try {
      await for (final request in server) {
        await _handle(request);
      }
    } on Object {
      // Closing the local server ends the request loop.
    }
  }

  Future<void> _handle(HttpRequest request) async {
    final response = request.response;
    response.headers
      ..set(HttpHeaders.cacheControlHeader, 'no-store')
      ..set('X-Content-Type-Options', 'nosniff')
      ..set('Referrer-Policy', 'no-referrer')
      ..set(
        'Content-Security-Policy',
        "default-src 'none'; img-src https: data:; style-src 'unsafe-inline'; "
            "script-src 'unsafe-inline'; connect-src 'self'",
      );
    if (request.method != 'GET') {
      response.statusCode = HttpStatus.methodNotAllowed;
      await response.close();
      return;
    }
    switch (request.uri.path) {
      case '/':
        response.headers.contentType = ContentType.html;
        response.write(_overlayHtml);
      case '/state.json':
        response.headers.contentType = ContentType.json;
        response.write(jsonEncode(_snapshot));
      default:
        response.statusCode = HttpStatus.notFound;
    }
    await response.close();
  }
}

const _overlayHtml = r'''<!doctype html>
<html lang="ru">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <title>Resonance — сейчас играет</title>
  <style>
    :root{color-scheme:dark;font-family:Inter,Segoe UI,Arial,sans-serif}
    *{box-sizing:border-box}html,body{width:100%;height:100%;margin:0;overflow:hidden;background:transparent}
    body{display:flex;align-items:flex-end;padding:24px;color:#f6f2eb}
    #card{width:min(560px,100%);min-height:118px;display:grid;grid-template-columns:92px 1fr;gap:18px;padding:13px;border:1px solid rgba(255,255,255,.14);border-radius:22px;background:linear-gradient(120deg,rgba(11,10,10,.92),rgba(25,22,20,.78));box-shadow:0 22px 70px rgba(0,0,0,.42);backdrop-filter:blur(24px);opacity:0;transform:translateY(16px);transition:opacity .28s ease,transform .28s cubic-bezier(.2,.8,.2,1)}
    #card.active{opacity:1;transform:none}.art{width:92px;height:92px;border-radius:14px;object-fit:cover;background:#201e1c}.copy{min-width:0;padding:8px 8px 5px 0}.kicker{color:#f05a49;font-size:10px;font-weight:800;letter-spacing:.17em;text-transform:uppercase}.title,.artist{white-space:nowrap;overflow:hidden;text-overflow:ellipsis}.title{margin-top:9px;font-size:23px;font-weight:750;letter-spacing:-.03em}.artist{margin-top:5px;color:#aaa49c;font-size:14px}.rail{height:3px;margin-top:16px;border-radius:4px;background:rgba(255,255,255,.13);overflow:hidden}.progress{width:0;height:100%;border-radius:inherit;background:#f05a49;transition:width .5s linear}.paused .kicker::after{content:' · пауза'}
    @media(max-width:420px){body{padding:12px}#card{grid-template-columns:72px 1fr;min-height:98px;border-radius:18px}.art{width:72px;height:72px}.copy{padding-top:3px}.title{font-size:18px}.rail{margin-top:11px}}
    @media(prefers-reduced-motion:reduce){#card,.progress{transition:none}}
  </style>
</head>
<body>
  <main id="card" aria-live="polite">
    <img id="art" class="art" alt="">
    <section class="copy"><div class="kicker">Сейчас играет</div><div id="title" class="title">Resonance</div><div id="artist" class="artist"></div><div class="rail"><div id="progress" class="progress"></div></div></section>
  </main>
  <script>
    const card=document.getElementById('card'),art=document.getElementById('art'),title=document.getElementById('title'),artist=document.getElementById('artist'),progress=document.getElementById('progress');
    async function sync(){try{const r=await fetch('/state.json',{cache:'no-store'});if(!r.ok)return;const s=await r.json();card.classList.toggle('active',!!s.active);card.classList.toggle('paused',!s.playing);title.textContent=s.title||'Resonance';artist.textContent=s.artist||'';if(s.artworkUrl){art.src=s.artworkUrl;art.hidden=false}else{art.removeAttribute('src');art.hidden=true}const value=s.durationMs>0?Math.max(0,Math.min(100,s.positionMs/s.durationMs*100)):0;progress.style.width=value+'%'}catch(_){}}
    sync();setInterval(sync,750);
  </script>
</body>
</html>''';
