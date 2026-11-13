// The game data must never be a stale copy: always ask the server whether index.pck has changed.
(function () {
	var f = window.fetch;
	window.fetch = function (u, o) {
		try {
			if (typeof u === 'string' && /\.pck(\?|$)/.test(u)) {
				o = Object.assign({}, o || {}, { cache: 'no-cache' });
			}
		} catch (e) {}
		return f.call(this, u, o);
	};
})();
// Tiny PeerJS glue for the Godot build: one host, one guest, JSON strings both ways.
window.bbNet = (function () {
  var peer = null, conn = null, q = [], PRE = 'banebold3d-';
  function note(o) { q.push(JSON.stringify(o)); }
  function wire(c) {
    conn = c;
    c.on('open', function () { note({ _: 'open' }); });
    c.on('data', function (d) { if (typeof d === 'string') q.push(d); });
    c.on('close', function () { if (conn === c) { conn = null; note({ _: 'close' }); } });
    c.on('error', function () { if (conn === c) { conn = null; note({ _: 'close' }); } });
  }
  return {
    host: function (code) {
      this.stop();
      if (!window.Peer) { note({ _: 'err', m: 'nopeer' }); return; }
      peer = new Peer(PRE + code);
      peer.on('open', function () { note({ _: 'ready' }); });
      peer.on('connection', function (c) { if (conn) { try { c.close(); } catch (e) {} return; } wire(c); });
      peer.on('error', function (e) { note({ _: 'err', m: String(e && e.type || e) }); });
    },
    join: function (code) {
      this.stop();
      if (!window.Peer) { note({ _: 'err', m: 'nopeer' }); return; }
      peer = new Peer();
      peer.on('open', function () { wire(peer.connect(PRE + code)); });
      peer.on('error', function (e) { note({ _: 'err', m: String(e && e.type || e) }); });
    },
    send: function (s) { if (conn && conn.open !== false) { try { conn.send(s); } catch (e) {} } },
    poll: function () { if (!q.length) return ''; var r = '[' + q.join(',') + ']'; q = []; return r; },
    stop: function () {
      try { if (conn) conn.close(); } catch (e) {}
      try { if (peer) peer.destroy(); } catch (e) {}
      conn = null; peer = null; q = [];
    },
    share: function (code) {
      var u = location.origin + location.pathname + '?join=' + code;
      if (navigator.share) { navigator.share({ title: 'Banebold 3D', text: 'Join my match! Room code ' + code, url: u }).catch(function () {}); return 'shared'; }
      if (navigator.clipboard) { navigator.clipboard.writeText(u).catch(function () {}); return 'copied'; }
      return '';
    },
    joinCode: function () { try { return new URLSearchParams(location.search).get('join') || ''; } catch (e) { return ''; } },
    say: function (t) {
      try {
        if (!window.speechSynthesis) return;
        var u = new SpeechSynthesisUtterance(t); u.lang = 'en-GB'; u.rate = 1.08; u.pitch = 1.0; u.volume = 0.9;
        speechSynthesis.cancel(); speechSynthesis.speak(u);
      } catch (e) {}
    }
  };
})();

// Install and update: the game can be put on the home screen, and it knows when a newer version is out.
window.bbApp = (function () {
  var dp = null, latest = '';
  addEventListener('beforeinstallprompt', function (e) { e.preventDefault(); dp = e; });
  try { if ('serviceWorker' in navigator) navigator.serviceWorker.register('sw.js').catch(function () {}); } catch (e) {}
  function check() {
    try {
      fetch('version.txt?t=' + Date.now(), { cache: 'no-store' }).then(function (r) { return r.ok ? r.text() : ''; })
        .then(function (t) { latest = String(t || '').trim(); }).catch(function () {});
    } catch (e) {}
  }
  check(); setInterval(check, 120000);
  document.addEventListener('visibilitychange', function () { if (!document.hidden) check(); });
  return {
    installed: function () { try { return (matchMedia('(display-mode: standalone)').matches || matchMedia('(display-mode: fullscreen)').matches && !document.fullscreenElement || navigator.standalone) ? 1 : 0; } catch (e) { return 0; } },
    install: function () { if (dp) { dp.prompt(); dp = null; return 'asked'; } return 'manual'; },
    latest: function () { return latest; },
    update: function () { location.replace(location.pathname + '?u=' + Date.now()); }
  };
})();
