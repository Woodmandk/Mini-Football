# Mini Football

Et simpelt 1 mod 1 fodboldspil i arkadestil, lavet til mobilen (hold telefonen på langs).

- **Mod computeren** eller **2 spillere på én telefon**
- **Online** med en 4-cifret kampkode. På et almindeligt link går forbindelsen direkte mellem telefonerne (WebRTC via PeerJS og dens gratis forbindelsesserver). Inde på claude.ai bruges claude.ai's egen `room`-funktion.
- Styring: venstre tommelfinger styrer, tryk i højre side for at skyde. På computer: WASD + mellemrum, piletaster + Enter for spiller 2.

Spillet ligger i `index.html` (ren canvas og JavaScript). `peerjs.min.js` er PeerJS 1.5.4 (MIT-licens).

Næste skridt: egen server (Colyseus) så online virker uden for claude.ai.
