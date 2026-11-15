extends RefCounted
# The career world: England's four leagues and Denmark's two. The clubs are made up, but each one is meant to
# remind you of a real club: its city, its colours and how strong it is. No real names, crests or players.
# A row: name, short name, shirt, shorts, socks, rating (how good the eleven is), formation index (FORM_NAMES).

const LEAGUES := [
	{"n": "ENGLAND DIVISION 1", "c": "ENGLAND", "t": 1, "up": 0, "down": 3},
	{"n": "ENGLAND DIVISION 2", "c": "ENGLAND", "t": 2, "up": 3, "down": 3},
	{"n": "ENGLAND DIVISION 3", "c": "ENGLAND", "t": 3, "up": 3, "down": 4},
	{"n": "ENGLAND DIVISION 4", "c": "ENGLAND", "t": 4, "up": 4, "down": 0},
	{"n": "DENMARK DIVISION 1", "c": "DENMARK", "t": 1, "up": 0, "down": 2},
	{"n": "DENMARK DIVISION 2", "c": "DENMARK", "t": 2, "up": 2, "down": 0},
]

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

# every club as {n, s, k, a, r, f, lg}: the quick-match clubs first, then the career clubs in league order
static func clubs(first: Array) -> Array:
	var out := first.duplicate(true)
	for li in START.size():
		for row in START[li]:
			var light: bool = Color(str(row[2])).get_luminance() > 0.6
			var alt := "1c1c20" if light else "f4f4f4"
			out.append({"n": row[0], "s": row[1], "k": [row[2], row[3], row[4]], "a": [alt, str(row[2]) if not light else "f4f4f4", alt], "r": int(row[5]), "f": int(row[6]), "lg": li})
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
	return out
