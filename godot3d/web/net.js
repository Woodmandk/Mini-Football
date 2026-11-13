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
  var peer = null, conn = null, q = [], PRE = 'banebold3d-', tries = 0, timer = 0, gen = 0;
  // Plain JSON text on the wire: the packed binary format of PeerJS is the part that fails on iPhone (Safari).
  var OPT = { serialization: 'json', reliable: true };
  function note(o) { q.push(JSON.stringify(o)); }
  function wire(c) {
    conn = c;
    var was = false;
    c.on('open', function () { if (conn !== c) return; was = true; clearTimeout(timer); note({ _: 'open' }); });
    c.on('data', function (d) { if (conn !== c) return; if (typeof d === 'string') q.push(d); else if (d && typeof d === 'object') q.push(JSON.stringify(d)); });
    c.on('close', function () { if (conn === c) { conn = null; if (was) note({ _: 'close' }); } });
    c.on('error', function () { if (conn === c) { conn = null; if (was) note({ _: 'close' }); } });
  }
  function keep(p) {
    // phones drop the link to the meeting server when the page is hidden for a moment: pick it up again
    p.on('disconnected', function () { setTimeout(function () { if (peer === p && !p.destroyed && p.disconnected) { try { p.reconnect(); } catch (e) {} } }, 2500); });
  }
  // The guest calls the room. A first try often dies quietly on a phone network, so try a few times before giving up.
  function dial(code, g) {
    if (g !== gen || !peer || peer.destroyed) return;
    tries++;
    var c;
    try { c = peer.connect(PRE + code, OPT); } catch (e) { note({ _: 'err', m: 'connect' }); return; }
    if (!c) { note({ _: 'err', m: 'connect' }); return; }
    wire(c);
    clearTimeout(timer);
    timer = setTimeout(function () {
      if (g !== gen || (conn === c && c.open)) return;
      if (conn === c) conn = null;
      try { c.close(); } catch (e) {}
      if (tries < 4) dial(code, g); else note({ _: 'err', m: 'timeout' });
    }, 7000);
  }
  return {
    host: function (code) {
      this.stop();
      if (!window.Peer) { note({ _: 'err', m: 'nopeer' }); return; }
      var p = peer = new Peer(PRE + code);
      keep(p);
      p.on('open', function () { note({ _: 'ready' }); });
      p.on('connection', function (c) {
                // The newest call wins: a friend whose line dropped calls again before the old line is known to be dead.
        if (conn) { var old = conn, live = old.open; conn = null; try { old.close(); } catch (e) {} if (live) note({ _: 'close' }); }
        wire(c);
      });
      p.on('error', function (e) { if (peer === p) note({ _: 'err', m: String(e && e.type || e) }); });
    },
    join: function (code) {
      this.stop();
      if (!window.Peer) { note({ _: 'err', m: 'nopeer' }); return; }
      var p = peer = new Peer(), g = gen;
      keep(p);
      tries = 0;
      p.on('open', function () { dial(code, g); });
      p.on('error', function (e) {
        if (peer !== p) return;
        var t = String(e && e.type || e);
        // the room is not there yet (the host is a second late): try again before saying so
        if (t === 'peer-unavailable' && tries < 4 && !(conn && conn.open)) { clearTimeout(timer); timer = setTimeout(function () { dial(code, g); }, 1500); return; }
        note({ _: 'err', m: t });
      });
    },
    send: function (s) { if (conn && conn.open !== false) { try { conn.send(s); } catch (e) {} } },
    poll: function () { if (!q.length) return ''; var r = '[' + q.join(',') + ']'; q = []; return r; },
    stop: function () {
      gen++; clearTimeout(timer);
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
