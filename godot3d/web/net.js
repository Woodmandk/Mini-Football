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
// iPhone (Safari) cannot lock the screen to landscape. When a phone shows the page standing up, the game is drawn
// turned on its side, so it always plays wide: turn the phone and it fits. The build (build.sh) makes Godot ask
// bbFit for the size of the page and for where a finger touched.
window.bbFit = (function () {
  var coarse = false, on = false;
  try { coarse = matchMedia('(pointer:coarse)').matches; } catch (e) {}
  function rot() {
    var r = coarse && innerHeight > innerWidth * 1.05;
    if (r !== on) {
      on = r;
      var c = document.getElementById('canvas');
      if (c) {
        c.style.position = r ? 'fixed' : '';
        c.style.left = r ? '0' : '';
        c.style.top = r ? '0' : '';
        c.style.transformOrigin = r ? '0 0' : '';
      }
    }
    if (r) { var cv = document.getElementById('canvas'); if (cv) cv.style.transform = 'translateX(' + innerWidth + 'px) rotate(90deg)'; }
    else { var cu = document.getElementById('canvas'); if (cu && cu.style.transform) cu.style.transform = ''; }
    return r;
  }
  return {
    rot: rot,
    w: function () { return rot() ? innerHeight : innerWidth; },
    h: function () { return rot() ? innerWidth : innerHeight; },
    pos: function (evt, rect, canvas) {
      if (on) return [(evt.clientY - rect.top) * canvas.width / rect.height, (rect.right - evt.clientX) * canvas.height / rect.width];
      return [(evt.clientX - rect.x) * canvas.width / rect.width, (evt.clientY - rect.y) * canvas.height / rect.height];
    }
  };
})();
// Tiny PeerJS glue for the Godot build: one host, one guest, JSON strings both ways.
window.bbNet = (function () {
  var peer = null, conn = null, q = [], seq = 0, PRE = 'banebold3d-', tries = 0, timer = 0, gen = 0;
  // Plain JSON text on the wire: the packed binary format of PeerJS is the part that fails on iPhone (Safari).
  var OPT = { serialization: 'json', reliable: true };
  function note(o) { q.push(JSON.stringify(o)); }
  function wire(c) {
    conn = c;
    var was = false;
    c.on('open', function () { if (conn !== c) return; was = true; clearTimeout(timer); note({ _: 'open' }); });
    var parts = {};
    c.on('data', function (d) {
      if (conn !== c) return;
      if (d && typeof d === 'object' && d._ === '~') {
        // one piece of a long message (see send): put it together again
        var b = parts[d.k] || (parts[d.k] = { n: d.n, got: 0, p: [] });
        if (b.p[d.i] === undefined) { b.p[d.i] = d.p; b.got++; }
        if (b.got >= b.n) { delete parts[d.k]; q.push(b.p.join('')); }
        return;
      }
      if (typeof d === 'string') q.push(d); else if (d && typeof d === 'object') q.push(JSON.stringify(d));
    });
    c.on('close', function () { if (conn === c) { conn = null; if (was) note({ _: 'close' }); } });
    // a message the line refused (too big) is not a broken line: keep it
    c.on('error', function (e) { if (e && e.type === 'message-too-big') return; if (conn === c) { conn = null; if (was) note({ _: 'close' }); } });
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
    // Find opponent: ranked matches against anyone, without a server. The meeting server lets only one phone own a
    // name, so a few fixed names are the waiting room: call each one; whoever answers 'hi' is waiting for you.
    // Nobody there: wait under the first free name yourself, and keep calling the lower names now and then,
    // so two phones that both wait always find each other.
    find: function () {
      this.stop();
      if (!window.Peer) { note({ _: 'err', m: 'nopeer' }); return; }
      var g = gen, SL = 8, nm = function (k) { return PRE + 'rk' + k; };
      var me = null, busy = false;
      function done(c, role) {
        if (g !== gen) return;
        busy = true; clearTimeout(timer);
        wire(c);
        note({ _: 'role', r: role });
        note({ _: 'open' });
      }
      // call name k on peer p; cb(true) when it answered and we are in its match
      function call(p, k, cb) {
        var c, fin = false;
        try { c = p.connect(nm(k), OPT); } catch (e) { cb(false); return; }
        if (!c) { cb(false); return; }
        var t = setTimeout(function () { if (fin) return; fin = true; try { c.close(); } catch (e) {} cb(false); }, 3500);
        c.on('data', function (d) {
          if (fin) return;
          var o = null; try { o = typeof d === 'string' ? JSON.parse(d) : d; } catch (e) {}
          if (o && o._ === 'hi') { fin = true; clearTimeout(t); if (g !== gen || busy) { try { c.close(); } catch (e) {} cb(false); return; } done(c, 'guest'); cb(true); }
        });
        c.on('close', function () { if (!fin) { fin = true; clearTimeout(t); cb(false); } });
        c.on('error', function () { if (!fin) { fin = true; clearTimeout(t); cb(false); } });
        p._fail = function () { if (!fin) { fin = true; clearTimeout(t); cb(false); } };
      }
      function wait(k) {
        if (g !== gen) return;
        if (k > SL) { note({ _: 'err', m: 'full' }); return; }
        var p = peer = new Peer(nm(k));
        keep(p);
        p.on('open', function () {
          if (g !== gen) { try { p.destroy(); } catch (e) {} return; }
          note({ _: 'wait', k: k });
          probe(p, k);
        });
        p.on('connection', function (c) {
          // already in a match: say no
          if (busy || g !== gen) { c.on('open', function () { try { c.close(); } catch (e) {} }); return; }
          c.on('open', function () {
            if (busy || g !== gen) { try { c.close(); } catch (e) {} return; }
            try { c.send(JSON.stringify({ _: 'hi' })); } catch (e) {}
            done(c, 'host');
          });
        });
        p.on('error', function (e) {
          var t = String(e && e.type || e);
          if (t === 'unavailable-id') { try { p.destroy(); } catch (x) {} if (!busy) wait(k + 1); return; }
          if (t === 'peer-unavailable') { if (p._fail) p._fail(); return; }
          if (peer === p && !busy) note({ _: 'err', m: t });
        });
      }
      function probe(p, k) {
        if (k <= 1) return;
        setTimeout(function () {
          if (g !== gen || busy || peer !== p) return;
          var j = 1;
          (function next() {
            if (g !== gen || busy || peer !== p) return;
            if (j >= k) { probe(p, k); return; }
            call(p, j++, function (ok) { if (!ok) next(); });
          })();
        }, 4000 + Math.random() * 2000);
      }
      // first call everyone who is waiting, then wait yourself
      me = peer = new Peer();
      keep(me);
      me.on('open', function () {
        var k = 1;
        (function next() {
          if (g !== gen || busy) return;
          if (k > SL) { try { me.destroy(); } catch (e) {} peer = null; wait(1); return; }
          call(me, k++, function (ok) { if (!ok) next(); });
        })();
      });
      me.on('error', function (e) {
        var t = String(e && e.type || e);
        if (t === 'peer-unavailable') { if (me._fail) me._fail(); return; }
        if (peer === me && !busy) note({ _: 'err', m: t });
      });
    },
    // PeerJS refuses any message over 16 KB in JSON mode (and the old code then took that for a lost line, so the
    // friend vanished from the room as soon as the host's career was sent). Long messages go in pieces.
    send: function (s) {
      if (!conn || conn.open === false) return;
      try {
        if (s.length <= 4000) { conn.send(s); return; }
        var n = Math.ceil(s.length / 4000), k = (++seq) + '' + Math.floor(Math.random() * 1000);
        for (var i = 0; i < n; i++) conn.send({ _: '~', k: k, i: i, n: n, p: s.substr(i * 4000, 4000) });
      } catch (e) {}
    },
    poll: function () { if (!q.length) return ''; var r = '[' + q.join(',') + ']'; q = []; return r; },
    stop: function () {
      gen++; clearTimeout(timer);
      try { if (conn) conn.close(); } catch (e) {}
      try { if (peer) peer.destroy(); } catch (e) {}
      conn = null; peer = null; q = [];
    },
    share: function (code) {
      var u = location.origin + location.pathname + '?join=' + code;
      if (navigator.share) { navigator.share({ title: 'Pitch Boss', text: 'Join my match! Room code ' + code, url: u }).catch(function () {}); return 'shared'; }
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
