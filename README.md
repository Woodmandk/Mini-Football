# Mini Football

Et simpelt fodboldspil i arkadestil, lavet til mobilen (hold telefonen på langs).

Spil: https://woodmandk.github.io/Mini-Football/

- **1 mod 1, 2 mod 2 eller 3 mod 3**, med computerstyrede holdkammerater og målmand
- **Mod computeren** (Let, Normal, Svær), **2 spillere på én telefon** eller **online med op til 6** via en 4-cifret kode. Tomme pladser spilles af computeren.
- Du styrer automatisk den spiller, der er tættest på bolden.
- Én knap til **SKYD** (hold inde for et hårdere skud) og **TACKLE** når du ikke har bolden, plus **SPURT** med udholdenhed.
- Nedtælling, golden goal ved uafgjort, pause, lyd, vibration og fuld skærm. Kan lægges på hjemmeskærmen som en app.

Tastatur: WASD + mellemrum + Shift. Spiller 2: piletaster + Enter + punktum.

## Sådan er det bygget

- `game.html` er hele spillet (canvas og JavaScript, ingen biblioteker). Den bruges også som claude.ai-artefakt.
- `./build.sh` laver `index.html` (siden på GitHub Pages) ud fra `game.html`.
- Online går direkte mellem telefonerne med WebRTC via `peerjs.min.js` (PeerJS 1.5.4, MIT) og PeerJS' gratis forbindelsesserver. Værten kører kampen, og de andre sender deres styring.
