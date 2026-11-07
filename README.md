# Mini Football

Et simpelt fodboldspil i arkadestil, lavet til mobilen (hold telefonen på langs).

Spil: https://woodmandk.github.io/Mini-Football/

- **1, 2, 3, 5 eller 11 spillere pr. hold** på en bane der vokser med holdene. Ved 5 og 11 vælger hvert hold formation (fx 4-4-2, 4-3-3, 3-5-2, 5-3-2), og der er offside.
- **Mod computeren** (Let, Normal, Svær), **2 spillere på én telefon** eller **online** via en 4-cifret kode eller et invitationslink. I lobbyen trykker alle Klar, så starter kampen. Tomme pladser spilles af computeren.
- Bolden følger spilleren, der har den. **SKYD** (hold inde for hårdere, to tryk for lob) og **AFLEVER** (to tryk for stikning). Uden bolden bliver knapperne **TACKLE** og **SKIFT**. Frit joystick, træk langt ud for at spurte.
- Indkast, hjørnespark, målspark og frispark. Gentagelse af målene i slowmotion, publikumslyd, statistik efter kampen og en stilling med topscorer på telefonen.
- Navne og fire trøjesæt, hurtige beskeder online ("Flot!", "GG") og revanche-knap. Power-ups kan slås til (superskud, turbo, kæmpebold).
- Spillet ligger altid ned, også hvis telefonen holdes oprejst. Kan lægges på hjemmeskærmen som en app.

Tastatur: WASD + mellemrum + Shift. Spiller 2: piletaster + Enter + punktum.

## Sådan er det bygget

- `game.html` er hele spillet (canvas og JavaScript, ingen biblioteker). Den bruges også som claude.ai-artefakt.
- `./build.sh` laver `index.html` (siden på GitHub Pages) ud fra `game.html`.
- Online går direkte mellem telefonerne med WebRTC via `peerjs.min.js` (PeerJS 1.5.4, MIT) og PeerJS' gratis forbindelsesserver. Værten kører kampen, og de andre sender deres styring.
