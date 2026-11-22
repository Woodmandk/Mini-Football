extends RefCounted
# The career world: England's four leagues, Denmark's two, Spain, Italy, Germany and France with two each, the
# Netherlands and Portugal, and a few clubs that only meet in Europe. The clubs are made up, but each one is meant to
# remind you of a real club: its city, its colours and how strong it is. No real names, crests or players.
# A row: name, short name, shirt, shorts, socks, rating (how good the eleven is), formation index (FORM_NAMES).

# Every league in the world and its own rules, as in the real game:
#  t = level in the country (1 = top), s = short name for tabs
#  up = clubs that go up straight away, down = clubs that go down straight away
#  po = the promotion play-off of this league ("" none): "eng" 4 clubs (semis over two legs, a one-off final),
#       "esp" 4 clubs (semis and final over two legs), "ita" 6 clubs (one-off first round, then two legs; a level tie
#       goes to the club that finished higher; no play-off when 3rd is 15+ points clear of 4th), "fra" 3 clubs
#       (one-off games at the higher club) whose winner meets the top league's rp club over two legs, "ger" the
#       3rd club meets the top league's rp club over two legs; pf = the places that take part
#  rp = the place in this (top) league that plays the relegation play-off against the league below (0 = none)
#  tb = what splits clubs level on points: "gd" goal difference, "h2h" the games between them first
#  sp = the split, as in Denmark: after sp rounds the top and bottom halves play on among themselves (0 = none)
#  sc = start coins, pk = how much the league pays, pr = prestige (1 = the best), eu/eu2 = places in the
#       Champions Cup and the Euro Trophy
const LEAGUES := [
	{"n": "ENGLAND DIVISION 1", "s": "ENG 1", "c": "ENGLAND", "t": 1, "up": 0, "down": 3, "po": "", "pf": [], "rp": 0, "tb": "gd", "sp": 0, "sc": 2500, "pk": 3.0, "pr": 1, "eu": 4, "eu2": 3},
	{"n": "ENGLAND DIVISION 2", "s": "ENG 2", "c": "ENGLAND", "t": 2, "up": 2, "down": 3, "po": "eng", "pf": [3, 6], "rp": 0, "tb": "gd", "sp": 0, "sc": 1000, "pk": 2.0, "pr": 2, "eu": 0, "eu2": 0},
	{"n": "ENGLAND DIVISION 3", "s": "ENG 3", "c": "ENGLAND", "t": 3, "up": 2, "down": 4, "po": "eng", "pf": [3, 6], "rp": 0, "tb": "gd", "sp": 0, "sc": 450, "pk": 1.4, "pr": 3, "eu": 0, "eu2": 0},
	{"n": "ENGLAND DIVISION 4", "s": "ENG 4", "c": "ENGLAND", "t": 4, "up": 3, "down": 0, "po": "eng", "pf": [4, 7], "rp": 0, "tb": "gd", "sp": 0, "sc": 200, "pk": 1.0, "pr": 4, "eu": 0, "eu2": 0},
	{"n": "DENMARK DIVISION 1", "s": "DEN 1", "c": "DENMARK", "t": 1, "up": 0, "down": 2, "po": "", "pf": [], "rp": 0, "tb": "gd", "sp": 22, "sc": 700, "pk": 1.8, "pr": 2, "eu": 2, "eu2": 3},
	{"n": "DENMARK DIVISION 2", "s": "DEN 2", "c": "DENMARK", "t": 2, "up": 2, "down": 0, "po": "", "pf": [], "rp": 0, "tb": "gd", "sp": 22, "sc": 250, "pk": 1.1, "pr": 3, "eu": 0, "eu2": 0},
	{"n": "SPAIN DIVISION 1", "s": "ESP 1", "c": "SPAIN", "t": 1, "up": 0, "down": 3, "po": "", "pf": [], "rp": 0, "tb": "h2h", "sp": 0, "sc": 2800, "pk": 3.0, "pr": 1, "eu": 4, "eu2": 3},
	{"n": "SPAIN DIVISION 2", "s": "ESP 2", "c": "SPAIN", "t": 2, "up": 2, "down": 0, "po": "esp", "pf": [3, 6], "rp": 0, "tb": "h2h", "sp": 0, "sc": 800, "pk": 1.8, "pr": 2, "eu": 0, "eu2": 0},
	{"n": "ITALY DIVISION 1", "s": "ITA 1", "c": "ITALY", "t": 1, "up": 0, "down": 3, "po": "", "pf": [], "rp": 0, "tb": "h2h", "sp": 0, "sc": 2400, "pk": 2.8, "pr": 1, "eu": 4, "eu2": 3},
	{"n": "ITALY DIVISION 2", "s": "ITA 2", "c": "ITALY", "t": 2, "up": 2, "down": 0, "po": "ita", "pf": [3, 8], "rp": 0, "tb": "h2h", "sp": 0, "sc": 700, "pk": 1.7, "pr": 2, "eu": 0, "eu2": 0},
	{"n": "GERMANY DIVISION 1", "s": "GER 1", "c": "GERMANY", "t": 1, "up": 0, "down": 2, "po": "", "pf": [], "rp": 16, "tb": "gd", "sp": 0, "sc": 2400, "pk": 2.8, "pr": 1, "eu": 4, "eu2": 3},
	{"n": "GERMANY DIVISION 2", "s": "GER 2", "c": "GERMANY", "t": 2, "up": 2, "down": 0, "po": "ger", "pf": [3, 3], "rp": 0, "tb": "gd", "sp": 0, "sc": 800, "pk": 1.8, "pr": 2, "eu": 0, "eu2": 0},
	{"n": "FRANCE DIVISION 1", "s": "FRA 1", "c": "FRANCE", "t": 1, "up": 0, "down": 2, "po": "", "pf": [], "rp": 16, "tb": "gd", "sp": 0, "sc": 2000, "pk": 2.4, "pr": 1, "eu": 3, "eu2": 3},
	{"n": "FRANCE DIVISION 2", "s": "FRA 2", "c": "FRANCE", "t": 2, "up": 2, "down": 0, "po": "fra", "pf": [3, 5], "rp": 0, "tb": "gd", "sp": 0, "sc": 500, "pk": 1.4, "pr": 3, "eu": 0, "eu2": 0},
	{"n": "NETHERLANDS DIVISION 1", "s": "NED 1", "c": "NETHERLANDS", "t": 1, "up": 0, "down": 0, "po": "", "pf": [], "rp": 0, "tb": "gd", "sp": 0, "sc": 1200, "pk": 2.0, "pr": 2, "eu": 2, "eu2": 2},
	{"n": "PORTUGAL DIVISION 1", "s": "POR 1", "c": "PORTUGAL", "t": 1, "up": 0, "down": 0, "po": "", "pf": [], "rp": 0, "tb": "gd", "sp": 0, "sc": 1200, "pk": 2.0, "pr": 2, "eu": 2, "eu2": 2},
]

# the countries in the order the menus show them
const COUNTRIES := ["ENGLAND", "SPAIN", "GERMANY", "ITALY", "FRANCE", "NETHERLANDS", "PORTUGAL", "DENMARK"]

# each country's cup and its own rules: two = the rounds before the final played over two legs (counted back from
# the semi-final: 1 = the semis), low = in the real cup the smaller club is at home, desc = the line on the cup screen
const CUPS := {
	"ENGLAND": {"n": "THE ENGLISH CUP", "two": 0, "low": false, "desc": "Every club from the top league to the fourth. One match each round, extra time and penalties, and the big clubs come in later."},
	"SPAIN": {"n": "THE SPANISH CUP", "two": 1, "low": true, "desc": "One match each round, the semi-finals over two legs, then the final."},
	"GERMANY": {"n": "THE GERMAN CUP", "two": 0, "low": true, "desc": "One match every round, all the way to the final in the capital. Lose once and you are out."},
	"ITALY": {"n": "THE ITALIAN CUP", "two": 1, "low": false, "desc": "The best clubs come in late. One match each round, the semi-finals over two legs."},
	"FRANCE": {"n": "THE FRENCH CUP", "two": 0, "low": true, "desc": "One match every round, every club in the country: the cup of the giant-killers."},
	"NETHERLANDS": {"n": "THE DUTCH CUP", "two": 0, "low": false, "desc": "One match every round, then the final."},
	"PORTUGAL": {"n": "THE PORTUGUESE CUP", "two": 1, "low": false, "desc": "One match every round, the semi-finals over two legs, then the final."},
	"DENMARK": {"n": "THE DANISH CUP", "two": 1, "low": true, "desc": "One match each round, the semi-finals over two legs, then the final."},
}

# where every league is in the list above
static func leagues_of(ctry: String) -> Array:
	var out := []
	for li in LEAGUES.size():
		if str(LEAGUES[li]["c"]) == ctry:
			out.append(li)
	return out

# where every league starts; the first index in the world list is FIRST (the 8 quick-match clubs come before)
const START := [
	# England 1
	[["MANCHESTER SKY", "MSK", "6cabdd", "ffffff", "6cabdd", 85, 4], ["MERSEYSIDE RED", "MER", "c8102e", "c8102e", "c8102e", 86, 0],
	["NORTH LONDON RED", "NLR", "ef0107", "ffffff", "ffffff", 85, 0], ["WEST LONDON BLUE", "WLB", "034694", "034694", "ffffff", 82, 4],
	["TYNESIDE STRIPES", "TYN", "1c1c1c", "1c1c1c", "1c1c1c", 80, 0], ["N. LONDON WHITE", "NLW", "ffffff", "132257", "ffffff", 79, 4],
	["MANCHESTER RED", "MRE", "da291c", "ffffff", "1c1c1c", 79, 4], ["BIRMINGHAM CLARET", "BCL", "670e36", "ffffff", "95bfe5", 79, 4],
	["BRIGHTON SEAGULLS", "BRS", "0057b8", "ffffff", "ffffff", 77, 4], ["TRENT REDS", "TRE", "dd0000", "ffffff", "dd0000", 77, 0],
	["SOUTH LONDON EAGLES", "SLE", "1b458f", "1b458f", "1b458f", 76, 2], ["SOUTH COAST CHERRIES", "SCC", "da291c", "1c1c1c", "1c1c1c", 76, 4],
	["WEST LONDON BEES", "WLE", "e30613", "1c1c1c", "e30613", 75, 0], ["THAMES WHITES", "THW", "ffffff", "1c1c1c", "ffffff", 75, 4],
	["EAST LONDON IRONS", "ELI", "7a263a", "ffffff", "7a263a", 75, 4], ["MERSEYSIDE BLUE", "MEB", "003399", "ffffff", "003399", 74, 4],
	["MIDLANDS WOLVES", "MWO", "fdb913", "231f20", "fdb913", 74, 2], ["YORKSHIRE WHITES", "YOW", "ffffff", "ffffff", "ffffff", 73, 0],
	["WEARSIDE STRIPES", "WEA", "eb172b", "1c1c1c", "1c1c1c", 72, 0], ["LANCASHIRE CLARETS", "LCL", "6c1d45", "ffffff", "6c1d45", 72, 1]],
	# England 2
	[["LEICESTER FOXES", "LFO", "003090", "ffffff", "003090", 72, 0], ["SOUTHAMPTON SAINTS", "SSA", "d71920", "1c1c1c", "1c1c1c", 71, 0],
	["IPSWICH BLUES", "IPB", "0044a9", "ffffff", "0044a9", 71, 4], ["SHEFFIELD BLADES", "SHB", "ee2737", "1c1c1c", "1c1c1c", 70, 2],
	["MIDDLESBROUGH RED", "MBR", "e11b22", "ffffff", "e11b22", 70, 4], ["COVENTRY SKY", "COS", "73b3e7", "ffffff", "73b3e7", 70, 4],
	["WEST BROM STRIPES", "WBS", "122f67", "ffffff", "ffffff", 69, 4], ["NORWICH CANARIES", "NCA", "fff200", "00a650", "fff200", 69, 0],
	["WREXHAM DRAGONS", "WRD", "d71920", "ffffff", "d71920", 69, 1], ["BIRMINGHAM BLUE", "BBL", "0000ff", "ffffff", "ffffff", 69, 4],
	["WATFORD HORNETS", "WAT", "fbee23", "1c1c1c", "fbee23", 68, 4], ["BRISTOL REDS", "BRR", "e21a23", "ffffff", "e21a23", 68, 0],
	["SWANSEA SWANS", "SWA", "ffffff", "ffffff", "ffffff", 67, 4], ["STOKE POTTERS", "STP", "e03a3e", "ffffff", "ffffff", 67, 1],
	["HULL TIGERS", "HUT", "f5a12d", "1c1c1c", "f5a12d", 67, 4], ["SOUTH LONDON LIONS", "SLL", "001d5e", "ffffff", "001d5e", 67, 1],
	["PRESTON LILYWHITES", "PRL", "ffffff", "1c2a4f", "ffffff", 67, 2], ["DERBY RAMS", "DRA", "ffffff", "1c1c1c", "ffffff", 66, 4],
	["WEST LONDON HOOPS", "WLH", "1d5ba4", "ffffff", "ffffff", 66, 0], ["PORTSMOUTH BLUE", "POB", "001489", "ffffff", "e4002b", 66, 4],
	["SHEFFIELD OWLS", "SHO", "0e00f7", "1c1c1c", "ffffff", 65, 1], ["OXFORD YELLOWS", "OXY", "f8e600", "001f5b", "001f5b", 65, 4],
	["LONDON ADDICKS", "LAD", "d4021d", "ffffff", "d4021d", 65, 1], ["BLACKBURN HALVES", "BBH", "009ee0", "ffffff", "009ee0", 66, 4]],
	# England 3
	[["LUTON HATTERS", "LUH", "f78f1e", "002d62", "f78f1e", 66, 2], ["CARDIFF BLUEBIRDS", "CAB", "0070b5", "0070b5", "ffffff", 65, 4],
	["HUDDERSFIELD STRIPES", "HUS", "0e63ad", "ffffff", "ffffff", 65, 4], ["BOLTON WHITES", "BOW", "ffffff", "263c7e", "ffffff", 65, 2],
	["READING ROYALS", "RER", "004494", "ffffff", "004494", 64, 0], ["WIGAN LATICS", "WIL", "1d59af", "ffffff", "ffffff", 64, 1],
	["PLYMOUTH GREENS", "PLG", "005e3c", "ffffff", "005e3c", 64, 4], ["BARNSLEY TYKES", "BAT", "e2231a", "ffffff", "e2231a", 64, 1],
	["STOCKPORT HATTERS", "STH", "1d4f9c", "ffffff", "ffffff", 64, 2], ["BIRMINGHAM GREENS", "BGR", "00a650", "1c1c1c", "00a650", 63, 0],
	["LINCOLN IMPS", "LIM", "e32219", "1c1c1c", "e32219", 63, 1], ["WYCOMBE QUARTERS", "WYQ", "8bd3f7", "002147", "002147", 63, 1],
	["BLACKPOOL TANGERINES", "BLT", "f68712", "ffffff", "f68712", 63, 4], ["ROTHERHAM MILLERS", "ROM", "e30613", "ffffff", "e30613", 62, 1],
	["PETERBOROUGH POSH", "PEP", "005ba6", "ffffff", "005ba6", 62, 0], ["EAST LONDON O'S", "ELO", "e2001a", "e2001a", "e2001a", 62, 4],
	["MANSFIELD STAGS", "MAS", "f2b31c", "0057a8", "f2b31c", 62, 1], ["BRADFORD BANTAMS", "BRB", "781f34", "f9b233", "781f34", 63, 1],
	["DONCASTER ROVERS", "DOR", "e30613", "1c1c1c", "e30613", 62, 1], ["EXETER GRECIANS", "EXG", "e30613", "ffffff", "ffffff", 61, 2],
	["NORTHAMPTON COBBLERS", "NOC", "7e1d36", "ffffff", "7e1d36", 61, 1], ["STEVENAGE BORO", "STB", "ffffff", "e30613", "ffffff", 61, 1],
	["SOUTH LONDON DONS", "SLD", "1b2c5b", "fcd116", "1b2c5b", 61, 0], ["STAFFORDSHIRE VALE", "SVA", "ffffff", "1c1c1c", "ffffff", 61, 1]],
	# England 4
	[["MILTON KEYNES WHITE", "MKW", "ffffff", "ffffff", "ffffff", 61, 4], ["BURTON BREWERS", "BUB", "fcd116", "1c1c1c", "fcd116", 60, 1],
	["NOTTS MAGPIES", "NOM", "1c1c1c", "ffffff", "1c1c1c", 60, 0], ["GRIMSBY MARINERS", "GRM", "1c1c1c", "1c1c1c", "e30613", 60, 1],
	["BRISTOL GAS", "BRG", "005ba6", "ffffff", "005ba6", 60, 1], ["CHESTERFIELD SPIREITES", "CHS", "0049ad", "ffffff", "0049ad", 60, 0],
	["SWINDON ROBINS", "SWR", "e30613", "ffffff", "e30613", 59, 1], ["SALFORD AMMIES", "SAA", "e30613", "ffffff", "e30613", 59, 0],
	["CREWE RAILWAYMEN", "CRR", "e30613", "ffffff", "e30613", 59, 1], ["GILLINGHAM GILLS", "GIG", "0055a5", "ffffff", "0055a5", 59, 1],
	["CAMBRIDGE AMBER", "CAA", "fcb415", "1c1c1c", "fcb415", 59, 1], ["WALSALL SADDLERS", "WAS", "e30613", "ffffff", "e30613", 59, 1],
	["SHREWSBURY SHREWS", "SHR", "0050a0", "fcd116", "0050a0", 58, 1], ["TRANMERE WHITES", "TRW", "ffffff", "0050a0", "ffffff", 58, 1],
	["OLDHAM LATICS", "OLL", "0050a0", "0050a0", "ffffff", 58, 1], ["FLEETWOOD COD ARMY", "FCA", "e30613", "ffffff", "e30613", 58, 3],
	["CHELTENHAM ROBINS", "CHR", "e30613", "ffffff", "e30613", 58, 1], ["COLCHESTER U'S", "COU", "005ba6", "ffffff", "005ba6", 58, 1],
	["CRAWLEY REDS", "CRA", "e30613", "e30613", "e30613", 58, 0], ["NEWPORT EXILES", "NEE", "f7a81b", "1c1c1c", "f7a81b", 57, 1],
	["ACCRINGTON REDS", "ACR", "e30613", "ffffff", "e30613", 57, 1], ["BARROW BLUEBIRDS", "BAB", "ffffff", "0050a0", "ffffff", 57, 3],
	["HARROGATE SULPHUR", "HAS", "fcd116", "1c1c1c", "fcd116", 57, 1], ["NORTH LONDON BEES", "NLB", "f5a12d", "1c1c1c", "f5a12d", 57, 1]],
	# Denmark 1
	[["COPENHAGEN LIONS", "COL", "ffffff", "1e3a8a", "ffffff", 74, 1], ["HERNING WOLVES", "HEW", "1c1c1c", "1c1c1c", "e30613", 74, 0],
	["BRØNDBY YELLOW", "BRY", "fcd116", "1e3a8a", "fcd116", 71, 2], ["AARHUS WHITES", "AAW", "ffffff", "ffffff", "ffffff", 70, 4],
	["FARUM TIGERS", "FAT", "e30613", "ffffff", "e30613", 69, 0], ["RANDERS HORSES", "RAH", "1c75bc", "ffffff", "1c75bc", 67, 1],
	["SILKEBORG REDS", "SIR", "e30613", "ffffff", "e30613", 67, 0], ["VIBORG GREENS", "VIG", "00843d", "ffffff", "00843d", 66, 4],
	["ODENSE STRIPES", "ODS", "1e3a8a", "ffffff", "1e3a8a", 66, 1], ["HADERSLEV BLUES", "HAB", "75b2dd", "ffffff", "75b2dd", 65, 1],
	["VEJLE REDS", "VER", "e30613", "ffffff", "e30613", 64, 1], ["FREDERICIA REDS", "FRR", "e30613", "1c1c1c", "e30613", 63, 3]],
	# Denmark 2
	[["AALBORG REDS", "AAR", "e30613", "ffffff", "e30613", 64, 4], ["LYNGBY BLUES", "LYB", "1e3a8a", "ffffff", "1e3a8a", 64, 1],
	["HORSENS YELLOW", "HOY", "fcd116", "1c1c1c", "fcd116", 61, 1], ["ESBJERG BLUES", "ESB", "1e5aa8", "ffffff", "1e5aa8", 61, 0],
	["KOLDING WHITES", "KOW", "ffffff", "1e3a8a", "ffffff", 60, 1], ["HVIDOVRE REDS", "HVR", "e30613", "1e3a8a", "e30613", 60, 1],
	["KØGE BLUES", "KOB", "1e3a8a", "ffffff", "1e3a8a", 59, 1], ["HOBRO YELLOW", "HOB", "fcd116", "1e3a8a", "fcd116", 59, 1],
	["ØSTERBRO STRIPES", "OST", "ffffff", "1e3a8a", "ffffff", 58, 1], ["HILLERØD GREENS", "HIG", "00843d", "ffffff", "00843d", 57, 1],
	["MIDDELFART BLUES", "MIB", "0050a0", "ffffff", "0050a0", 56, 1], ["AARHUS FREMAD BLACK", "AFB", "1c1c1c", "fcd116", "1c1c1c", 56, 1]],
]

# The rest of Europe: clubs that only play in the Champions Cup (no league of their own here). Made up too.
const FOREIGN := [
	["MADRID WHITES", "MAW", "ffffff", "ffffff", "ffffff", 88, 0, "SPAIN"], ["CATALAN STRIPES", "CAT", "a50044", "004d98", "a50044", 87, 0, "SPAIN"],
	["MADRID STRIPES", "MST", "cb3524", "1c2c5b", "cb3524", 83, 1, "SPAIN"], ["BASQUE LIONS", "BAL", "ee2523", "1c1c1c", "1c1c1c", 78, 1, "SPAIN"],
	["SEVILLE WHITES", "SEW", "ffffff", "ffffff", "e30613", 77, 4, "SPAIN"], ["VALENCIA BATS", "VAB", "ffffff", "1c1c1c", "1c1c1c", 75, 1, "SPAIN"],
	["MILAN SERPENTS", "MSE", "0068a8", "1c1c1c", "1c1c1c", 84, 2, "ITALY"], ["TURIN ZEBRAS", "TUZ", "1c1c1c", "ffffff", "ffffff", 82, 0, "ITALY"],
	["NAPLES SKY", "NAS", "12a0d7", "ffffff", "12a0d7", 82, 0, "ITALY"], ["MILAN DEVILS", "MDE", "fb090b", "ffffff", "1c1c1c", 80, 0, "ITALY"],
	["BERGAMO GODDESS", "BEG", "1e71b8", "1c1c1c", "1c1c1c", 80, 2, "ITALY"], ["ROME WOLVES", "ROW", "8e1f2f", "ffffff", "8e1f2f", 78, 4, "ITALY"],
	["MUNICH REDS", "MUR", "dc052d", "dc052d", "dc052d", 88, 4, "GERMANY"], ["LEVERKUSEN LIONS", "LEL", "e32221", "1c1c1c", "1c1c1c", 84, 2, "GERMANY"],
	["DORTMUND BEES", "DOB", "fde100", "1c1c1c", "fde100", 83, 4, "GERMANY"], ["LEIPZIG BULLS", "LEB", "ffffff", "ffffff", "dd0741", 80, 1, "GERMANY"],
	["PARIS BLUES", "PAB", "004170", "004170", "004170", 87, 0, "FRANCE"], ["MONACO DIAMONDS", "MOD", "e51b22", "ffffff", "e51b22", 78, 4, "FRANCE"],
	["MARSEILLE WHITES", "MAR", "ffffff", "ffffff", "2faee0", 76, 0, "FRANCE"], ["LILLE MASTIFFS", "LLM", "e01e13", "1c2c5b", "e01e13", 76, 4, "FRANCE"],
	["LISBON EAGLES", "LIE", "e20e0e", "ffffff", "e20e0e", 80, 4, "PORTUGAL"], ["LISBON LIONS", "LIL", "008057", "1c1c1c", "008057", 79, 0, "PORTUGAL"],
	["PORTO DRAGONS", "POD", "00428c", "00428c", "00428c", 79, 4, "PORTUGAL"], ["EINDHOVEN LIGHTS", "EIL", "ed1c24", "1c1c1c", "1c1c1c", 79, 0, "NETHERLANDS"],
	["AMSTERDAM LANCERS", "AML", "ffffff", "ffffff", "ffffff", 78, 0, "NETHERLANDS"], ["ROTTERDAM PORT", "ROP", "ffffff", "1c1c1c", "1c1c1c", 76, 0, "NETHERLANDS"],
	# the second level of Europe: the clubs of the Euro Trophy
	["SAN SEBASTIAN WAVES", "SSW", "0067b1", "ffffff", "0067b1", 74, 0, "SPAIN"], ["SEVILLE GREENS", "SEG", "00954c", "ffffff", "00954c", 73, 1, "SPAIN"],
	["FLORENCE LILIES", "FLL", "5b2b82", "ffffff", "5b2b82", 75, 0, "ITALY"], ["ROME EAGLES", "ROE", "87d8f7", "ffffff", "87d8f7", 74, 1, "ITALY"],
	["BOLOGNA TOWERS", "BOT", "a21c26", "1a2f48", "1a2f48", 72, 2, "ITALY"], ["TURIN BULLS", "TUB", "8a1e03", "ffffff", "8a1e03", 70, 4, "ITALY"],
	["FRANKFURT EAGLES", "FRE", "e1000f", "1c1c1c", "1c1c1c", 75, 1, "GERMANY"], ["STUTTGART STAGS", "STS", "ffffff", "ffffff", "e32219", 74, 0, "GERMANY"],
	["WOLFSBURG WOLVES", "WOW", "65b32e", "ffffff", "65b32e", 72, 4, "GERMANY"], ["FREIBURG FOREST", "FRF", "1c1c1c", "1c1c1c", "e2001a", 71, 1, "GERMANY"],
	["LYON LIONS", "LYL", "ffffff", "ffffff", "da0812", 75, 0, "FRANCE"], ["NICE EAGLES", "NIE", "c8102e", "1c1c1c", "1c1c1c", 73, 1, "FRANCE"],
	["LENS MINERS", "LEM", "fff200", "e30613", "e30613", 72, 4, "FRANCE"], ["RENNES REDS", "RNS", "e13327", "1c1c1c", "1c1c1c", 71, 0, "FRANCE"],
	["GLASGOW HOOPS", "GLH", "018749", "ffffff", "ffffff", 74, 0, "SCOTLAND"], ["GLASGOW BLUES", "GLB", "1b458f", "ffffff", "1c1c1c", 73, 4, "SCOTLAND"],
	["BRUGES BLUES", "BGB", "0072ce", "1c1c1c", "1c1c1c", 73, 0, "BELGIUM"], ["BRUSSELS PURPLE", "BRP", "4f2d7f", "ffffff", "4f2d7f", 71, 1, "BELGIUM"],
	["ISTANBUL LIONS", "ISL", "a90432", "fdb912", "a90432", 74, 0, "TURKEY"], ["ISTANBUL CANARIES", "ISC", "fff200", "002b7f", "002b7f", 73, 4, "TURKEY"],
	["PIRAEUS REDS", "PIR", "e30613", "ffffff", "e30613", 71, 0, "GREECE"], ["SALZBURG BULLS", "SAB", "ffffff", "e2001a", "ffffff", 73, 2, "AUSTRIA"],
	["BODO LIGHTS", "BOL", "fff200", "1c1c1c", "fff200", 69, 0, "NORWAY"], ["PRAGUE SLAVS", "PRS", "e30613", "ffffff", "e30613", 70, 1, "CZECHIA"],
	["ZAGREB BLUES", "ZAB", "0057a8", "ffffff", "0057a8", 70, 0, "CROATIA"], ["BELGRADE STARS", "BES", "e30613", "ffffff", "e30613", 70, 4, "SERBIA"],
]


# The new leagues (2026-11-22). A row is a new club; a name in quotes is a club from FOREIGN that now plays in this league
# (it keeps its place in the world list, so old saves still point at the right clubs).
const START2 := [
	# Spain 1
	["MADRID WHITES", "CATALAN STRIPES",
	"MADRID STRIPES", "BASQUE LIONS",
	"SEVILLE WHITES", "VALENCIA BATS",
	"SAN SEBASTIAN WAVES", "SEVILLE GREENS",
	["VILLARREAL SUBMARINES", "VIL", "ffe114", "ffe114", "ffe114", 79, 4], ["GIRONA STRIPES", "GIR", "e4002b", "ffffff", "e4002b", 74, 0],
	["VIGO SKY", "VGO", "8ac3ee", "ffffff", "8ac3ee", 73, 1], ["PAMPLONA REDS", "PAM", "d91a21", "0a346f", "0a346f", 73, 4],
	["MADRID SASH", "MSH", "ffffff", "ffffff", "ffffff", 72, 1], ["MALLORCA ISLANDERS", "MLL", "c8102e", "1c1c1c", "1c1c1c", 71, 1],
	["GETAFE AZULES", "GET", "005999", "005999", "005999", 71, 3], ["CATALAN PARAKEETS", "CPA", "007fc8", "ffffff", "007fc8", 71, 1],
	["VITORIA BLUES", "VIT", "0761af", "ffffff", "0761af", 70, 1], ["ELCHE PALMS", "ELC", "ffffff", "ffffff", "00843d", 69, 4],
	["VALENCIA FROGS", "VFR", "b4053f", "004d98", "004d98", 69, 1], ["OVIEDO BLUES", "OVI", "0033a0", "ffffff", "0033a0", 68, 1]],
	# Spain 2
	[["PALMAS CANARIES", "LPA", "ffe114", "0055a5", "0055a5", 68, 0], ["VALLADOLID VIOLETS", "VLD", "5d2d91", "ffffff", "5d2d91", 67, 1],
	["CORUNA BLUES", "CRN", "0050a0", "ffffff", "0050a0", 67, 4], ["ALMERIA STRIPES", "ARI", "e30613", "ffffff", "ffffff", 67, 4],
	["LEGANES STRIPES", "LGN", "0050a0", "ffffff", "0050a0", 66, 1], ["GIJON STRIPES", "GIJ", "e30613", "ffffff", "1c3a7a", 66, 1],
	["SANTANDER GREENS", "SAN", "00843d", "ffffff", "00843d", 66, 1], ["MALAGA BLUES", "MAL", "0080c8", "ffffff", "0080c8", 66, 1],
	["CADIZ YELLOWS", "CAD", "fdd400", "0050a0", "fdd400", 66, 1], ["GRANADA HOOPS", "GRA", "d71920", "ffffff", "ffffff", 66, 1],
	["ZARAGOZA LIONS", "ZAR", "ffffff", "0050a0", "ffffff", 65, 1], ["EIBAR ARMOURERS", "EIB", "7b1e3a", "1c3a7a", "7b1e3a", 64, 1],
	["BURGOS WHITES", "BUR", "ffffff", "1c1c1c", "1c1c1c", 63, 3], ["HUESCA CLARETS", "HUE", "7b1e3a", "1c3a7a", "7b1e3a", 63, 1],
	["ALBACETE WHITES", "ALB", "ffffff", "ffffff", "ffffff", 63, 1], ["CASTELLON STRIPES", "CAS", "ffffff", "1c1c1c", "1c1c1c", 64, 0],
	["CORDOBA GREENS", "CDB", "00843d", "ffffff", "ffffff", 63, 1], ["MIRANDA REDS", "MIR", "e30613", "1c1c1c", "e30613", 62, 1],
	["CEUTA STRAITS", "CEU", "ffffff", "1c1c1c", "ffffff", 61, 3], ["LEON CULTURALS", "LEO", "ffffff", "ffffff", "ffffff", 61, 1],
	["ANDORRA TRICOLOURS", "AND", "0033a0", "fdd400", "e30613", 62, 0], ["TENERIFE BLUES", "TEN", "ffffff", "0050a0", "0050a0", 63, 1]],
	# Italy 1
	["MILAN SERPENTS", "TURIN ZEBRAS",
	"NAPLES SKY", "MILAN DEVILS",
	"BERGAMO GODDESS", "ROME WOLVES",
	"FLORENCE LILIES", "ROME EAGLES",
	"BOLOGNA TOWERS", "TURIN BULLS",
	["COMO LAKESIDE", "COM", "1e4fa0", "ffffff", "1e4fa0", 75, 4], ["UDINE STRIPES", "UDI", "ffffff", "1c1c1c", "ffffff", 72, 2],
	["GENOA GRIFFINS", "GEN", "a2142a", "1c3a7a", "1c1c1c", 71, 2], ["CAGLIARI ISLANDERS", "CAG", "a2142a", "1c3a7a", "1c3a7a", 70, 1],
	["LECCE WOLVES", "LEC", "fdd400", "e30613", "e30613", 69, 0], ["PARMA CRUSADERS", "PAR", "ffffff", "1c1c1c", "ffffff", 70, 2],
	["VERONA MASTIFFS", "VRN", "1c3a7a", "fdd400", "1c3a7a", 69, 2], ["SASSUOLO GREENS", "SAS", "00843d", "1c1c1c", "00843d", 70, 0],
	["CREMONA VIOLINS", "CRE", "b31b1b", "9ea2a2", "b31b1b", 67, 2], ["PISA KNIGHTS", "PIS", "1c3a7a", "1c1c1c", "1c1c1c", 67, 2]],
	# Italy 2
	[["PALERMO PINKS", "PAL", "f4a7c4", "1c1c1c", "1c1c1c", 68, 0], ["VENICE LIONS", "VEN", "1c1c1c", "1c1c1c", "f47b20", 68, 2],
	["MONZA REDS", "MON", "e30613", "ffffff", "e30613", 67, 2], ["GENOA SAILORS", "SMP", "1e4fa0", "ffffff", "1e4fa0", 66, 1],
	["EMPOLI BLUES", "EMP", "0050a0", "ffffff", "0050a0", 66, 0], ["SPEZIA WHITES", "SPE", "ffffff", "1c1c1c", "ffffff", 65, 2],
	["BARI ROOSTERS", "BAR", "ffffff", "e30613", "ffffff", 65, 0], ["MODENA CANARIES", "MDN", "fdd400", "1e4fa0", "fdd400", 64, 2],
	["CESENA SEAHORSES", "CES", "ffffff", "1c1c1c", "1c1c1c", 63, 2], ["CATANZARO EAGLES", "CTZ", "fdd400", "e30613", "e30613", 63, 2],
	["FROSINONE CANARIES", "FRO", "fdd400", "1e4fa0", "1e4fa0", 64, 2], ["BOLZANO WHITES", "BOZ", "ffffff", "e30613", "ffffff", 63, 1],
	["REGGIO GRANATAS", "REG", "8a1e03", "ffffff", "8a1e03", 62, 2], ["PADUA SHIELDS", "PAD", "ffffff", "e30613", "ffffff", 62, 2],
	["CARRARA MARBLE", "CAR", "fdd400", "1e4fa0", "fdd400", 61, 2], ["STABIA WASPS", "JST", "fdd400", "1e4fa0", "fdd400", 61, 2],
	["AVELLINO WOLVES", "AVE", "00843d", "ffffff", "00843d", 62, 2], ["PESCARA DOLPHINS", "PES", "3ea0dc", "ffffff", "3ea0dc", 62, 0],
	["MANTUA BEARS", "MNT", "ffffff", "e30613", "ffffff", 61, 2], ["CHIAVARI SKY", "ENT", "3ea0dc", "1c3a7a", "1c3a7a", 60, 2]],
	# Germany 1
	["MUNICH REDS", "LEVERKUSEN LIONS",
	"DORTMUND BEES", "LEIPZIG BULLS",
	"FRANKFURT EAGLES", "STUTTGART STAGS",
	"WOLFSBURG WOLVES", "FREIBURG FOREST",
	["SINSHEIM BLUES", "SIN", "1c63b7", "ffffff", "1c63b7", 73, 4], ["GLADBACH FOALS", "GLF", "ffffff", "1c1c1c", "ffffff", 72, 4],
	["MAINZ CARNIVALS", "MAI", "e30613", "ffffff", "e30613", 71, 2], ["BERLIN IRONS", "BER", "e30613", "ffffff", "e30613", 71, 3],
	["BREMEN GREENS", "BRE", "1d9053", "ffffff", "1d9053", 71, 4], ["AUGSBURG FUGGERS", "AUG", "ba3733", "ffffff", "ba3733", 70, 2],
	["COLOGNE GOATS", "KOE", "ffffff", "e30613", "ffffff", 70, 4], ["HAMBURG DINOS", "HAM", "ffffff", "e30613", "1c3a7a", 70, 4],
	["HEIDENHEIM REDS", "HEI", "e30613", "1c3a7a", "e30613", 68, 1], ["HAMBURG PIRATES", "HPI", "6b4423", "ffffff", "6b4423", 68, 2]],
	# Germany 2
	[["GELSENKIRCHEN BLUES", "GEL", "004d9d", "ffffff", "004d9d", 69, 4], ["BERLIN STRIPES", "HER", "005ca9", "ffffff", "005ca9", 68, 4],
	["HANOVER REDS", "HAN", "e30613", "1c1c1c", "e30613", 66, 4], ["NUREMBERG REDS", "NUR", "9b1c31", "1c1c1c", "9b1c31", 66, 4],
	["LAUTERN DEVILS", "KAI", "e30613", "ffffff", "e30613", 66, 1], ["DUSSELDORF REDS", "DUS", "e30613", "ffffff", "ffffff", 66, 4],
	["KARLSRUHE BLUES", "KSC", "0050a0", "ffffff", "0050a0", 65, 4], ["PADERBORN BLUES", "PDB", "1c3a7a", "1c1c1c", "1c3a7a", 65, 2],
	["DARMSTADT LILIES", "DAR", "0050a0", "ffffff", "0050a0", 65, 4], ["BOCHUM BLUES", "BOC", "0050a0", "0050a0", "ffffff", 66, 1],
	["KIEL STORKS", "KIE", "1c3a7a", "ffffff", "e30613", 66, 2], ["ELVERSBERG BLACKS", "ELV", "1c1c1c", "ffffff", "1c1c1c", 64, 4],
	["MAGDEBURG BLUES", "MAG", "1a5da8", "ffffff", "1a5da8", 65, 4], ["FURTH CLOVERS", "FUR", "00843d", "ffffff", "00843d", 64, 4],
	["BRUNSWICK LIONS", "BRA", "fdd400", "0050a0", "fdd400", 64, 1], ["MUNSTER EAGLES", "MUN", "1c1c1c", "ffffff", "00843d", 63, 1],
	["BIELEFELD BLUES", "BIE", "1c3a7a", "1c1c1c", "ffffff", 64, 1], ["DRESDEN YELLOWS", "DRE", "fdd400", "1c1c1c", "fdd400", 64, 4]],
	# France 1
	["PARIS BLUES", "MONACO DIAMONDS",
	"MARSEILLE WHITES", "LILLE MASTIFFS",
	"LYON LIONS", "NICE EAGLES",
	"LENS MINERS", "RENNES REDS",
	["STRASBOURG BLUES", "SBG", "0098d7", "ffffff", "0098d7", 73, 2], ["TOULOUSE VIOLETS", "TOU", "5b2b82", "ffffff", "5b2b82", 71, 2],
	["NANTES CANARIES", "NAN", "fdd400", "00843d", "fdd400", 70, 1], ["BREST PIRATES", "BRT", "e30613", "ffffff", "e30613", 70, 0],
	["AUXERRE BLUES", "AUX", "ffffff", "0050a0", "ffffff", 68, 4], ["ANGERS STRIPES", "ANG", "1c1c1c", "ffffff", "1c1c1c", 68, 1],
	["LE HAVRE SKY", "HAV", "87ceeb", "1c3a7a", "87ceeb", 68, 1], ["LORIENT ORANGES", "LOR", "f47b20", "1c1c1c", "f47b20", 67, 4],
	["METZ GRENATS", "MET", "8a1e03", "ffffff", "8a1e03", 66, 1], ["PARIS CITY", "PFC", "1c3a7a", "ffffff", "1c3a7a", 68, 4]],
	# France 2
	[["ST ETIENNE GREENS", "STE", "00843d", "ffffff", "00843d", 67, 4], ["MONTPELLIER BLUES", "MTP", "1c3a7a", "f47b20", "1c3a7a", 66, 4],
	["REIMS REDS", "REI", "e30613", "ffffff", "e30613", 66, 4], ["TROYES BLUES", "TRO", "0050a0", "ffffff", "0050a0", 64, 1],
	["GUINGAMP REDS", "GUI", "e30613", "1c1c1c", "e30613", 63, 1], ["CORSICA BLUES", "BAS", "0050a0", "ffffff", "0050a0", 62, 1],
	["PARIS STARS", "RSP", "00843d", "ffffff", "00843d", 62, 4], ["PAU YELLOWS", "PAU", "fdd400", "1c3a7a", "fdd400", 62, 1],
	["GRENOBLE BLUES", "GBL", "0050a0", "ffffff", "0050a0", 61, 1], ["AMIENS WHITES", "AMI", "ffffff", "1c1c1c", "ffffff", 62, 1],
	["RODEZ REDS", "ROD", "e30613", "fdd400", "e30613", 61, 1], ["ANNECY REDS", "ANN", "e30613", "ffffff", "e30613", 61, 1],
	["CLERMONT VOLCANOES", "CLE", "9b1c31", "1c3a7a", "9b1c31", 63, 4], ["LAVAL TANGOS", "LAV", "f47b20", "1c1c1c", "f47b20", 61, 1],
	["DUNKIRK MARINERS", "DUN", "ffffff", "1c3a7a", "ffffff", 60, 1], ["LE MANS RACERS", "LMA", "e30613", "fdd400", "e30613", 60, 1],
	["NANCY THISTLES", "NCY", "e30613", "ffffff", "e30613", 61, 1], ["BOULOGNE HERRINGS", "BOU", "e30613", "1c1c1c", "e30613", 60, 1]],
	# Netherlands 1
	["EINDHOVEN LIGHTS", "AMSTERDAM LANCERS",
	"ROTTERDAM PORT", ["ALKMAAR REDS", "ALK", "e30613", "ffffff", "e30613", 73, 0],
	["ENSCHEDE REDS", "ENS", "e30613", "ffffff", "e30613", 72, 0], ["UTRECHT DOMS", "UTR", "e30613", "ffffff", "ffffff", 70, 0],
	["NIJMEGEN STRIPES", "NIJ", "e30613", "1c1c1c", "1c1c1c", 68, 4], ["DEVENTER EAGLES", "DEV", "e30613", "fdd400", "e30613", 67, 0],
	["FRISIAN HEARTS", "HEE", "1e4fa0", "ffffff", "1e4fa0", 67, 0], ["GRONINGEN PRIDE", "GRO", "00843d", "ffffff", "00843d", 66, 0],
	["ROTTERDAM SPARTANS", "SPR", "e30613", "1c1c1c", "1c1c1c", 65, 0], ["SITTARD FORTUNES", "SIT", "fdd400", "00843d", "fdd400", 64, 4],
	["ZWOLLE BLUES", "ZWO", "0050a0", "ffffff", "0050a0", 64, 0], ["ALMELO STRIPES", "AHE", "1c1c1c", "ffffff", "1c1c1c", 63, 1],
	["KRALINGEN REDS", "KRA", "e30613", "1c1c1c", "1c1c1c", 62, 0], ["VELSEN STARS", "VEL", "ffffff", "e30613", "ffffff", 61, 1],
	["BREDA YELLOWS", "BRD", "fdd400", "1c1c1c", "fdd400", 63, 0], ["VOLENDAM ORANGES", "VOL", "f47b20", "1c1c1c", "f47b20", 61, 0]],
	# Portugal 1
	["LISBON EAGLES", "LISBON LIONS",
	"PORTO DRAGONS", ["BRAGA WARRIORS", "BRW", "e30613", "ffffff", "e30613", 74, 4],
	["GUIMARAES KNIGHTS", "GUM", "ffffff", "1c1c1c", "ffffff", 70, 4], ["FAMALICAO BLUES", "FAM", "1c3a7a", "ffffff", "1c3a7a", 66, 0],
	["BARCELOS ROOSTERS", "GIL", "e30613", "1c3a7a", "e30613", 65, 1], ["MOREIRA GREENS", "MOR", "00843d", "ffffff", "00843d", 64, 1],
	["AZORES ISLANDERS", "AZO", "e30613", "ffffff", "e30613", 65, 1], ["VILA CONDE GREENS", "VCG", "00843d", "ffffff", "00843d", 64, 4],
	["ESTORIL CANARIES", "EST", "fdd400", "1c3a7a", "fdd400", 64, 0], ["LISBON BLACKS", "LBK", "1c1c1c", "ffffff", "1c1c1c", 63, 3],
	["AROUCA WOLVES", "ARO", "fdd400", "1c3a7a", "fdd400", 63, 1], ["MADEIRA BLACKS", "MAD", "1c1c1c", "ffffff", "1c1c1c", 62, 1],
	["AMADORA STARS", "AMA", "e30613", "00843d", "e30613", 62, 1], ["ALVERCA REDS", "ALV", "e30613", "ffffff", "e30613", 61, 1],
	["TONDELA YELLOWS", "TON", "fdd400", "00843d", "fdd400", 61, 1], ["AVES REDS", "AVS", "e30613", "ffffff", "e30613", 60, 1]],
]

static func _club(row: Array, li: int) -> Dictionary:
	var light: bool = Color(str(row[2])).get_luminance() > 0.6
	var alt := "1c1c20" if light else "f4f4f4"
	var c := {"n": row[0], "s": row[1], "k": [row[2], row[3], row[4]], "a": [alt, str(row[2]) if not light else "f4f4f4", alt], "r": int(row[5]), "f": int(row[6]), "lg": li}
	if li >= 0:
		c["c"] = str(LEAGUES[li]["c"])
	elif row.size() > 7:
		c["c"] = str(row[7])
	return c

# the league a FOREIGN club now plays in (-1 = only Europe)
static func _foreign_lg() -> Dictionary:
	var out := {}
	for k in START2.size():
		for e in START2[k]:
			if e is String:
				out[e] = START.size() + k
	return out

# every club as {n, s, k, a, r, f, lg, c}: the quick-match clubs first, then the English and Danish clubs in league
# order, then the clubs of FOREIGN (now mostly in the new leagues; lg -1 = Europe only), then the new clubs
static func clubs(first: Array) -> Array:
	var out := first.duplicate(true)
	for li in START.size():
		for row in START[li]:
			out.append(_club(row, li))
	var fl := _foreign_lg()
	for row in FOREIGN:
		out.append(_club(row, int(fl.get(str(row[0]), -1))))
	for k in START2.size():
		for e in START2[k]:
			if e is Array:
				out.append(_club(e, START.size() + k))
	return out

# the world indices of the clubs that play only in Europe (no league of their own)
static func foreign_ids(first_n: int) -> Array:
	var i := first_n
	for li in START.size():
		i += (START[li] as Array).size()
	var fl := _foreign_lg()
	var out := []
	for k in FOREIGN.size():
		if not fl.has(str(FOREIGN[k][0])):
			out.append(i + k)
	return out

# the world indices of each league at the start
static func start_leagues(first_n: int) -> Array:
	var out := []
	var i := first_n
	for li in START.size():
		var ids := []
		for _r in START[li]:
			ids.append(i)
			i += 1
		out.append(ids)
	var fo0 := i
	var at := {}
	for k in FOREIGN.size():
		at[str(FOREIGN[k][0])] = fo0 + k
	i = fo0 + FOREIGN.size()
	for k in START2.size():
		var ids2 := []
		for e in START2[k]:
			if e is String:
				ids2.append(int(at[e]))
			else:
				ids2.append(i)
				i += 1
		out.append(ids2)
	return out

# ---------------------------------------------------------------- how each club plays
# Every club has its own way of playing, like in FIFA and Top Eleven: how hard it presses (pr), how high its back
# line stands (ln), how wide it plays (wd), how quickly it moves the ball on (tp) and how direct it is: the ball
# over the top and long early (dr) or short and patient. All 0..1. Each club also has a manager with his own
# nerve (bold): a bold one chases a game early and goes for the win, a careful one protects what he has.
# [shown name, pr, ln, wd, tp, dr, what it means]
const STYLES := {
	"possession": ["POSSESSION", 0.70, 0.72, 0.60, 0.15, 0.12, "Keeps the ball and passes short and patiently, and presses to win it back"],
	"press": ["HIGH PRESS", 1.00, 0.88, 0.50, 0.80, 0.55, "Hunts the ball high up the pitch and attacks fast the moment it wins it"],
	"counter": ["COUNTER-ATTACK", 0.30, 0.22, 0.45, 0.92, 0.88, "Sits off you and breaks at speed with balls in behind the moment it has it"],
	"long": ["LONG BALL", 0.48, 0.40, 0.65, 0.72, 1.00, "Plays it long early, over the top to the forwards, and fights for the second ball"],
	"wing": ["WING PLAY", 0.52, 0.55, 1.00, 0.55, 0.50, "Stretches the pitch, goes down the flanks and gets crosses in"],
	"block": ["LOW BLOCK", 0.10, 0.05, 0.22, 0.45, 0.72, "Compact and deep, hard to break down, and it hits you on the break"],
	"balanced": ["BALANCED", 0.50, 0.50, 0.50, 0.50, 0.50, "A bit of everything: it presses in its own half and mixes short and long"],
}
# the clubs that are known for a way of playing (by short name)
const CLUB_STYLE := {
	"BIS": "press", "SHA": "wing", "ROV": "possession", "LIO": "balanced", "WOL": "block", "STO": "counter", "KIN": "possession", "FOX": "long",
	"MSK": "possession", "MER": "press", "NLR": "possession", "WLB": "balanced", "TYN": "press", "NLW": "press", "MRE": "counter", "BCL": "balanced",
	"BRS": "possession", "TRE": "counter", "SLE": "counter", "SCC": "press", "WLE": "long", "MEB": "block", "MWO": "counter", "YOW": "press",
	"MAW": "counter", "CAT": "possession", "MST": "block", "BAL": "press", "SEW": "balanced", "VIL": "possession",
	"MSE": "wing", "TUZ": "block", "NAS": "possession", "MDE": "counter", "BEG": "press", "ROW": "block",
	"MUR": "possession", "LEL": "possession", "DOB": "counter", "LEB": "press",
	"PAB": "possession", "MOD": "counter", "MAR": "press", "LLM": "balanced",
	"LIE": "wing", "LIL": "possession", "POD": "press", "EIL": "wing", "AML": "possession", "ROP": "press",
}
# the rest play the way football is played in their country (picked by the club's name, so always the same)
const COUNTRY_STYLES := {
	"ENGLAND": ["long", "press", "counter", "balanced", "wing", "block", "long", "balanced"],
	"SPAIN": ["possession", "balanced", "counter", "block", "possession", "wing"],
	"ITALY": ["block", "balanced", "counter", "possession", "block", "wing"],
	"GERMANY": ["press", "counter", "balanced", "wing", "press"],
	"FRANCE": ["counter", "balanced", "wing", "press", "block"],
	"NETHERLANDS": ["possession", "wing", "balanced", "press"],
	"PORTUGAL": ["possession", "balanced", "counter", "wing"],
	"DENMARK": ["balanced", "press", "long", "counter", "wing", "block"],
}

static func _h(s: String) -> int:
	var h := 7
	for i in s.length():
		h = (h * 31 + s.unicode_at(i)) % 1000003
	return h

# a club's way of playing: {k, n, pr, ln, wd, tp, dr, bold, d}
static func style(c: Dictionary) -> Dictionary:
	var sh := str(c.get("s", "")).to_upper()
	var h := _h(str(c.get("n", "")) + sh)
	var k := str(CLUB_STYLE.get(sh, ""))
	if k == "":
		var opts: Array = COUNTRY_STYLES.get(str(c.get("c", "")), ["balanced", "press", "counter", "possession", "long", "wing", "block"])
		k = str(opts[h % opts.size()])
	var r: Array = STYLES[k]
	# each club its own shade of it, and a big club stands higher than a small one
	var rt := float(c.get("r", 74))
	var lnk := clampf((rt - 75.0) / 30.0, -0.2, 0.15)
	var o := {"k": k, "n": str(r[0]), "d": str(r[6])}
	var keys := ["pr", "ln", "wd", "tp", "dr"]
	for i in 5:
		var v: float = float(r[i + 1]) + (float((h >> (i * 3)) % 17) / 16.0 - 0.5) * 0.14
		if keys[i] == "ln":
			v += lnk
		o[keys[i]] = clampf(v, 0.0, 1.0)
	o["bold"] = float((h >> 4) % 101) / 100.0
	if k in ["press", "counter"]:
		o["bold"] = 0.35 + o["bold"] * 0.65
	elif k == "block":
		o["bold"] = o["bold"] * 0.6
	return o

# the plan a club starts a match with: its style, how much stronger or weaker it is (gap, in rating points:
# a big favourite comes at you, an underdog sits deeper) and a derby. [mentality 0-4, press 0-2, width 0-2]
static func plan_for(st: Dictionary, gap: float, derby := false) -> Array:
	var mv: float = (float(st.get("ln", 0.5)) - 0.5) * 1.6 + clampf(gap / 7.0, -2.0, 2.0) * 0.75
	var pv: float = (float(st.get("pr", 0.5)) - 0.5) * 2.2 + clampf(gap / 9.0, -1.0, 1.0) * 0.5 + (0.6 if derby else 0.0)
	var ment := clampi(2 + roundi(mv), 0, 4)
	var wv: float = (float(st.get("wd", 0.5)) - 0.5) * 2.2 - (0.45 if ment <= 1 else 0.0)
	return [ment, clampi(1 + roundi(pv), 0, 2), clampi(1 + roundi(wv), 0, 2)]
