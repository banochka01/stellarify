import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:resonance/domain/entities/playback_state.dart';
import 'package:resonance/shared/widgets/track_artwork.dart';

/// Строка текста для OBS: только время и текст, без источника и токенов.
final class ObsLyricLine {
  const ObsLyricLine(this.startMs, this.text);
  final int startMs;
  final String text;
}

/// Локальный сервер виджета «Сейчас играет» для OBS Browser Source.
///
/// Страница получает состояние через Server-Sent Events (с запасным опросом),
/// сама плавно двигает прогресс между событиями и берёт обложку с этого же
/// адреса (`/art`), поэтому OBS не упирается в CORS, `%%`-шаблоны Яндекса и
/// хотлинк-защиту CDN.
final class ObsNowPlayingServer {
  ObsNowPlayingServer({
    this.preferredPort = 17654,
    this.portAttempts = 10,
    HttpClient? artworkClient,
  }) : _artworkClient = artworkClient ?? HttpClient();

  final int preferredPort;
  final int portAttempts;
  final HttpClient _artworkClient;
  HttpServer? _server;
  final _listeners = <HttpResponse>{};
  Timer? _heartbeat;

  Map<String, Object?> _snapshot = const {
    'active': false,
    'playing': false,
    'title': 'Resonance',
    'artist': 'Ожидание воспроизведения',
    'artworkUrl': null,
    'positionMs': 0,
    'durationMs': 0,
  };
  String? _trackId;
  bool? _playing;
  int _durationMs = 0;
  Uri? _sentArtwork;
  int _positionMs = 0;
  int _sentAtMs = 0;
  List<ObsLyricLine> _lyrics = const [];
  String? _lyricsTrackId;

  Uri? _artworkSource;
  ({Uri url, Uint8List bytes, String contentType})? _artworkCache;
  Uri? _loadingUrl;
  Future<void>? _artworkLoading;

  bool get running => _server != null;
  int? get port => _server?.port;
  Uri? get uri => port == null ? null : Uri.parse('http://127.0.0.1:$port/');

  Future<void> start() async {
    if (_server != null) return;
    SocketException? lastError;
    final attempts = preferredPort == 0 ? 1 : portAttempts;
    for (var offset = 0; offset < attempts; offset++) {
      try {
        final server = await HttpServer.bind(
          InternetAddress.loopbackIPv4,
          preferredPort == 0 ? 0 : preferredPort + offset,
          shared: false,
        );
        _server = server;
        unawaited(_serve(server));
        _heartbeat = Timer.periodic(
          const Duration(seconds: 15),
          (_) => _broadcastRaw(': keep-alive\n\n'),
        );
        return;
      } on SocketException catch (error) {
        lastError = error;
      }
    }
    throw lastError ?? const SocketException('OBS port unavailable');
  }

  void update(ResonancePlaybackState state) {
    final track = state.currentTrack;
    final now = DateTime.now().millisecondsSinceEpoch;
    final position = state.position.inMilliseconds;
    final artwork = track?.artworkUrl;
    _snapshot = {
      'active': track != null,
      'playing': state.playing,
      'trackId': track?.id,
      'title': track?.title ?? 'Resonance',
      'artist': track?.artist ?? 'Ожидание воспроизведения',
      'album': track?.album,
      'artworkUrl': artwork == null ? null : '/art?v=${artwork.hashCode}',
      'positionMs': position,
      'durationMs': state.duration.inMilliseconds,
      'provider': state.activeTrackSource?.provider.name,
      'updatedAt': now,
    };
    if (artwork != _artworkSource) {
      _artworkSource = artwork;
      if (artwork != null) unawaited(_prefetchArtwork(artwork));
    }
    if (track?.id != _lyricsTrackId) _lyrics = const [];

    // Шлём событие, только когда что-то заметно изменилось: смена трека,
    // пауза или перемотка. Между событиями страница считает время сама.
    final expected = _playing == true
        ? _positionMs + (now - _sentAtMs)
        : _positionMs;
    final duration = state.duration.inMilliseconds;
    final changed =
        track?.id != _trackId ||
        state.playing != _playing ||
        duration != _durationMs ||
        artwork != _sentArtwork ||
        (position - expected).abs() > 1500;
    if (changed) {
      _trackId = track?.id;
      _playing = state.playing;
      _durationMs = duration;
      _sentArtwork = artwork;
      _positionMs = position;
      _sentAtMs = now;
      _broadcastState();
    }
  }

  /// Синхронизированные строки текущего трека для режима `?lyrics=1`.
  void updateLyrics(String trackId, List<ObsLyricLine> lines) {
    if (trackId != _trackId) return;
    _lyricsTrackId = trackId;
    _lyrics = List.unmodifiable(lines);
    _broadcastState();
  }

  Map<String, Object?> get _payload => {
    ..._snapshot,
    'lyrics': _lyricsTrackId == _trackId
        ? [
            for (final line in _lyrics) {'t': line.startMs, 'x': line.text},
          ]
        : const <Object>[],
  };

  Future<void> stop() async {
    _heartbeat?.cancel();
    _heartbeat = null;
    for (final listener in _listeners.toList()) {
      unawaited(listener.close().catchError((Object _) {}));
    }
    _listeners.clear();
    final server = _server;
    _server = null;
    await server?.close(force: true);
  }

  void dispose() {
    unawaited(stop());
    _artworkClient.close(force: true);
  }

  void _broadcastState() =>
      _broadcastRaw('event: state\ndata: ${jsonEncode(_payload)}\n\n');

  void _broadcastRaw(String chunk) {
    for (final listener in _listeners.toList()) {
      try {
        listener.write(chunk);
        unawaited(
          listener.flush().catchError((Object _) {
            _listeners.remove(listener);
          }),
        );
      } on Object {
        _listeners.remove(listener);
      }
    }
  }

  /// Одна загрузка на адрес обложки; после неудачи следующая попытка
  /// начинается заново.
  Future<void> _prefetchArtwork(Uri artwork) {
    final running = _artworkLoading;
    if (running != null && _loadingUrl == artwork) return running;
    late final Future<void> loading;
    loading = _loadArtwork(artwork).whenComplete(() {
      if (identical(_artworkLoading, loading)) {
        _artworkLoading = null;
        _loadingUrl = null;
      }
    });
    _loadingUrl = artwork;
    _artworkLoading = loading;
    return loading;
  }

  Future<void> _loadArtwork(Uri artwork) async {
    if (_artworkCache?.url == artwork) return;
    final candidates = <Uri>{
      Uri.parse(highQualityArtworkUrl(artwork, targetSize: 640)),
      artwork,
    }.where((uri) => uri.isScheme('https') || uri.isScheme('http'));
    for (final candidate in candidates) {
      try {
        final request = await _artworkClient
            .getUrl(candidate)
            .timeout(const Duration(seconds: 8));
        request.followRedirects = true;
        final response = await request.close().timeout(
          const Duration(seconds: 10),
        );
        if (response.statusCode != HttpStatus.ok) {
          await response.drain<void>();
          continue;
        }
        final type = response.headers.contentType?.mimeType ?? 'image/jpeg';
        if (!type.startsWith('image/')) {
          await response.drain<void>();
          continue;
        }
        final builder = BytesBuilder(copy: false);
        await for (final chunk in response) {
          builder.add(chunk);
          if (builder.length > 6 * 1024 * 1024) break;
        }
        if (_artworkSource != artwork) return;
        _artworkCache = (
          url: artwork,
          bytes: builder.takeBytes(),
          contentType: type,
        );
        return;
      } on Object {
        // Следующий кандидат или заглушка на странице.
      }
    }
  }

  Future<void> _serve(HttpServer server) async {
    try {
      await for (final request in server) {
        unawaited(_handle(request).catchError((Object _) {}));
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
        "default-src 'none'; img-src 'self' data:; style-src 'unsafe-inline'; "
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
        response.write(jsonEncode(_payload));
      case '/events':
        response.headers
          ..contentType = ContentType('text', 'event-stream', charset: 'utf-8')
          ..set('Connection', 'keep-alive');
        response.bufferOutput = false;
        response.write(
          'retry: 2000\nevent: state\n'
          'data: ${jsonEncode(_payload)}\n\n',
        );
        await response.flush();
        _listeners.add(response);
        unawaited(
          response.done
              .catchError((Object _) {})
              .whenComplete(() => _listeners.remove(response)),
        );
        return;
      case '/art':
        final source = _artworkSource;
        if (source != null && _artworkCache?.url != source) {
          // Неудачная загрузка не запоминается: каждый запрос пробует снова.
          await _prefetchArtwork(source);
        }
        final cached = _artworkCache;
        if (cached == null || cached.url != _artworkSource) {
          response.statusCode = HttpStatus.notFound;
        } else {
          response.headers
            ..set(HttpHeaders.contentTypeHeader, cached.contentType)
            ..set(HttpHeaders.cacheControlHeader, 'private, max-age=3600');
          response.add(cached.bytes);
        }
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
    :root{color-scheme:dark;--accent:#b69cff;--live:#d8f15a;--ink:#0e0b14;--text:#efe9f5;--muted:#b2a9bb;--glass:rgba(23,18,31,.78);--line:rgba(255,255,255,.12);--scale:1;font-family:Manrope,Inter,"Segoe UI",Arial,sans-serif}
    *{box-sizing:border-box}html,body{width:100%;height:100%;margin:0;overflow:hidden;background:transparent}
    body{display:flex;align-items:flex-end;justify-content:flex-start;padding:24px;color:var(--text)}
    body.right{justify-content:flex-end}body.top{align-items:flex-start}body.center{justify-content:center}
    #card{position:relative;width:min(560px,100%);display:grid;grid-template-columns:auto 1fr;gap:18px;align-items:center;padding:14px;border:1px solid var(--line);border-radius:24px;background:var(--glass);box-shadow:0 22px 70px rgba(0,0,0,.42);backdrop-filter:blur(26px) saturate(1.3);overflow:hidden;opacity:0;transform:translateY(16px) scale(var(--scale));transform-origin:bottom left;transition:opacity .35s ease,transform .45s cubic-bezier(.2,.8,.2,1)}
    body.right #card{transform-origin:bottom right}
    #card.active{opacity:1;transform:translateY(0) scale(var(--scale))}
    #card.hidden-paused{opacity:0;transform:translateY(16px) scale(var(--scale))}
    #glow{position:absolute;inset:-40%;background:radial-gradient(circle at 20% 30%,var(--accent),transparent 55%);opacity:.28;filter:blur(30px);transition:background 1s ease;pointer-events:none}
    .art{position:relative;width:96px;height:96px;border-radius:16px;overflow:hidden;background:linear-gradient(135deg,#3a2a55,#120d19);box-shadow:0 10px 30px rgba(0,0,0,.45)}
    .art img{position:absolute;inset:0;width:100%;height:100%;object-fit:cover;opacity:0;transition:opacity .5s ease}
    .art img.on{opacity:1}
    .art .ph{position:absolute;inset:0;display:grid;place-items:center;font-weight:800;font-size:30px;color:rgba(255,255,255,.7)}
    .copy{position:relative;min-width:0;padding-right:6px}
    .kicker{display:flex;align-items:center;gap:8px;color:var(--live);font-size:10px;font-weight:800;letter-spacing:.18em;text-transform:uppercase}
    .eq{display:inline-flex;gap:2px;align-items:flex-end;height:10px}.eq i{width:3px;background:var(--live);border-radius:2px;animation:eq 1s ease-in-out infinite}.eq i:nth-child(2){animation-delay:-.4s}.eq i:nth-child(3){animation-delay:-.7s}
    .paused .eq i{animation:none;height:3px}.paused .kicker{color:var(--muted)}
    @keyframes eq{0%,100%{height:3px}50%{height:10px}}
    .viewport{overflow:hidden;white-space:nowrap;mask-image:linear-gradient(90deg,#000 88%,transparent)}
    .viewport.fit{mask-image:none}
    .title{display:inline-block;margin-top:8px;font-size:23px;font-weight:800;letter-spacing:-.03em;line-height:1.15}
    .title.scroll{animation:marquee var(--dur,12s) linear infinite;padding-right:48px}
    @keyframes marquee{0%,15%{transform:translateX(0)}85%,100%{transform:translateX(var(--shift))}}
    .artist{margin-top:4px;color:var(--muted);font-size:14px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
    .rail{display:flex;align-items:center;gap:10px;margin-top:14px;font:600 11px/1 "JetBrains Mono",Consolas,monospace;color:var(--muted);font-variant-numeric:tabular-nums}
    .bar{flex:1;height:4px;border-radius:4px;background:rgba(255,255,255,.12);overflow:hidden}
    .fill{width:100%;height:100%;border-radius:inherit;background:linear-gradient(90deg,var(--accent),var(--live));transform-origin:left;transform:scaleX(0)}
    #lyric{grid-column:1/-1;min-height:0;max-height:0;opacity:0;font-size:17px;font-weight:700;line-height:1.3;transition:opacity .3s ease,max-height .3s ease}
    body.lyrics #lyric{max-height:3.2em;opacity:1}
    #lyric.swap{opacity:.15}
    .swap-out{animation:swap .5s ease}
    @keyframes swap{0%{opacity:0;transform:translateY(6px)}100%{opacity:1;transform:none}}
    /* Компактная плашка */
    body.compact #card{width:min(420px,100%);grid-template-columns:auto 1fr;gap:12px;padding:10px;border-radius:18px}
    body.compact .art{width:58px;height:58px;border-radius:12px}body.compact .title{font-size:17px;margin-top:4px}body.compact .artist{font-size:12px}body.compact .rail{margin-top:8px}body.compact .time{display:none}
    /* Узкая полоса для нижнего края сцены */
    body.bar #card{width:min(760px,100%);grid-template-columns:auto 1fr;padding:8px 14px 8px 8px;border-radius:999px}
    body.bar .art{width:44px;height:44px;border-radius:999px}body.bar .kicker{display:none}body.bar .title{font-size:16px;margin-top:0}body.bar .artist{font-size:12px;margin-top:2px}body.bar .rail{margin-top:6px}body.bar .time{display:none}
    /* Квадрат: обложка сверху */
    body.square #card{width:min(320px,100%);grid-template-columns:1fr;gap:14px;padding:14px}
    body.square .art{width:100%;height:auto;aspect-ratio:1}
    /* Без подложки — только текст с тенью */
    body.clean #card{background:transparent;border-color:transparent;box-shadow:none;backdrop-filter:none}
    body.clean #glow{display:none}body.clean .copy{text-shadow:0 2px 12px rgba(0,0,0,.8)}
    body.light{--glass:rgba(250,247,252,.86);--text:#17121f;--muted:#5d5268;--line:rgba(0,0,0,.08)}
    @media(max-width:420px){body{padding:12px}}
    @media(prefers-reduced-motion:reduce){*{animation:none!important;transition:none!important}}
  </style>
</head>
<body>
  <main id="card" aria-live="polite">
    <div id="glow"></div>
    <div class="art"><div id="ph" class="ph">♪</div><img id="artA" alt=""><img id="artB" alt=""></div>
    <section class="copy">
      <div class="kicker"><span class="eq"><i></i><i></i><i></i></span><span id="kick">Сейчас играет</span></div>
      <div id="vp" class="viewport"><div id="title" class="title">Resonance</div></div>
      <div id="artist" class="artist"></div>
      <div class="rail"><span id="pos" class="time">0:00</span><div class="bar"><div id="fill" class="fill"></div></div><span id="dur" class="time">0:00</span></div>
    </section>
    <div id="lyric"></div>
  </main>
  <script>
    const q=new URLSearchParams(location.search),$=id=>document.getElementById(id);
    const card=$('card'),title=$('title'),vp=$('vp'),artist=$('artist'),fill=$('fill'),pos=$('pos'),dur=$('dur'),kick=$('kick'),lyric=$('lyric'),ph=$('ph'),glow=$('glow');
    const layout=q.get('layout')||'card';document.body.classList.add(layout);
    for(const k of ['right','top','center','light','clean'])if(q.get('align')===k||q.get('theme')===k||q.has(k))document.body.classList.add(k);
    if(q.get('lyrics')==='1')document.body.classList.add('lyrics');
    const hidePaused=q.get('hidePaused')==='1';
    const scale=parseFloat(q.get('scale'));if(scale>0&&scale<4)document.documentElement.style.setProperty('--scale',scale);
    const fixedAccent=/^[0-9a-f]{6}$/i.test(q.get('accent')||'')?'#'+q.get('accent'):null;
    if(fixedAccent)document.documentElement.style.setProperty('--accent',fixedAccent);
    let s={active:false},base=0,baseAt=performance.now(),trackId=null,art='',front=$('artA'),back=$('artB'),lines=[],lineIdx=-2;
    const fmt=ms=>{ms=Math.max(0,ms|0);const t=Math.floor(ms/1000),m=Math.floor(t/60),x=t%60;return m+':'+String(x).padStart(2,'0')};
    function initials(a){const w=(a||'').trim().split(/[\s,;&]+/).filter(Boolean);return w.length?(w[0][0]+(w[1]?w[1][0]:'')).toUpperCase():'♪'}
    function fitTitle(){title.classList.remove('scroll');vp.classList.add('fit');const over=title.scrollWidth-vp.clientWidth;if(over>4){vp.classList.remove('fit');title.style.setProperty('--shift',-(over+48)+'px');title.style.setProperty('--dur',Math.max(8,over/22)+'s');title.classList.add('scroll')}}
    function tint(img){if(fixedAccent)return;try{const c=document.createElement('canvas');c.width=c.height=12;const g=c.getContext('2d');g.drawImage(img,0,0,12,12);const d=g.getImageData(0,0,12,12).data;let r=0,gg=0,b=0,n=0;for(let i=0;i<d.length;i+=4){const mx=Math.max(d[i],d[i+1],d[i+2]),mn=Math.min(d[i],d[i+1],d[i+2]);const w=(mx-mn)/255+.05;r+=d[i]*w;gg+=d[i+1]*w;b+=d[i+2]*w;n+=w}if(n>0){const k=v=>Math.min(255,Math.round(v/n*1.25+20));document.documentElement.style.setProperty('--accent',`rgb(${k(r)},${k(gg)},${k(b)})`)}}catch(_){}}
    function setArt(url){if(url===art)return;art=url;if(!url){front.classList.remove('on');back.classList.remove('on');ph.hidden=false;return}const next=back;next.onload=()=>{next.classList.add('on');front.classList.remove('on');[front,back]=[next,front];ph.hidden=true;tint(next)};next.onerror=()=>{front.classList.remove('on');ph.hidden=false;art=''};next.src=url+(url.includes('?')?'&':'?')+'r='+Date.now()}
    function apply(n){const changed=n.trackId!==trackId;s=n;base=n.positionMs||0;baseAt=performance.now()-(Date.now()-(n.updatedAt||Date.now()));
      card.classList.toggle('active',!!n.active);card.classList.toggle('paused',!n.playing);card.classList.toggle('hidden-paused',hidePaused&&!n.playing);
      kick.textContent=n.playing?'Сейчас играет':'Пауза';ph.textContent=initials(n.artist);
      if(changed){trackId=n.trackId;title.textContent=n.title||'Resonance';artist.textContent=n.artist||'';card.classList.remove('swap-out');void card.offsetWidth;card.classList.add('swap-out');requestAnimationFrame(fitTitle);lineIdx=-2;lyric.textContent=''}
      lines=Array.isArray(n.lyrics)?n.lyrics:[];setArt(n.artworkUrl||'');dur.textContent=fmt(n.durationMs)}
    function now(){return s.playing?base+(performance.now()-baseAt):base}
    function frame(){const d=s.durationMs||0,p=Math.min(now(),d||Infinity);fill.style.transform='scaleX('+(d>0?Math.max(0,Math.min(1,p/d)):0)+')';pos.textContent=fmt(p);
      if(lines.length){let i=-1;for(let k=0;k<lines.length&&lines[k].t<=p+150;k++)i=k;if(i!==lineIdx){lineIdx=i;lyric.classList.add('swap');setTimeout(()=>{lyric.textContent=i>=0?lines[i].x:'';lyric.classList.remove('swap')},140)}}
      requestAnimationFrame(frame)}
    async function poll(){try{const r=await fetch('/state.json',{cache:'no-store'});if(r.ok)apply(await r.json())}catch(_){}}
    function connect(){if(!window.EventSource){setInterval(poll,1000);return}const es=new EventSource('/events');es.addEventListener('state',e=>{try{apply(JSON.parse(e.data))}catch(_){}});es.onerror=()=>{poll()}}
    poll();connect();setInterval(poll,10000);requestAnimationFrame(frame);addEventListener('resize',fitTitle);
  </script>
</body>
</html>''';
