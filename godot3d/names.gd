extends RefCounted
const ClubDB := preload("res://clubdb.gd")

# Player names (2026-11-22, Daniel: "many names repeat, they should be very unique, the surnames too").
# Every country has its own first names and surnames, and most countries also build more surnames from
# roots and endings that sound like the language (Ash + worth, Lind + gaard, Bel + lini). A club's men are
# mostly from its own country with a few from abroad. All names are made up: the generator never makes
# the same full name twice in the whole world, never two men with one surname in a squad, and it spreads
# the surnames so each one turns up as rarely as possible. A "_" inside a surname is a space (de_Vries).

const POOLS := {
	"ENGLAND": {
		"f": "Jack Harry Oliver George Charlie Thomas James Joe Alfie Freddie Archie Leo Oscar Henry William Jacob Ethan Mason Lewis Callum Ryan Connor Jamie Kieran Aaron Liam Nathan Ben Sam Luke Adam Dan Tom Josh Reece Tyler Jordan Kyle Owen Dean Lee Mark Scott Craig Jake Max Toby Ollie Elliot Rhys Kai Marcus Jayden Curtis Darren Wes Jonah Rory Ellis Finley Theo Louie Dexter Spencer Harvey Billy Bradley Ashley Morgan Joel Kian Alex Zach Ronnie Stanley Arthur Teddy Albert Sonny Ezra Jude",
		"s": "Ashworth Barlow Bentley Birch Blackwood Bradshaw Brook Burrows Carver Chadwick Clayton Cotton Crawley Dawson Dixon Eastwood Fairclough Fenwick Fletcher Garside Gibbs Goddard Greenwood Hadley Halliwell Hargreaves Hartley Hawkins Haywood Hodgson Holloway Horton Ingram Jarvis Kendall Kirby Lambert Langley Lawson Marsden Mellor Merritt Norris Oakley Ogden Parkes Pemberton Platt Pollard Pritchard Radcliffe Ramsden Rigby Royle Sadler Shackleton Sharples Slater Stanton Stubbs Sutcliffe Swann Tanner Thornton Townsend Tranter Warburton Webster Whitaker Wilkins Winslow Woodcock Yardley Atherton Bramwell Catterall Dunmore Elwood Furness Gaskell Hollins Kershaw Lockwood Mottram Naylor Openshaw Pickles Ridley Sowerby Thwaite Unsworth Varley Wainwright Whitehead Bickerstaff Cartwright Entwistle Fothergill Illingworth Lowther Moorcroft Abbott Allsop Arkwright Bagshaw Bamford Beckett Birtles Boden Booth Brindley Cheetham Clegg Cowell Crabtree Dobbs Duckworth Emsley Fawcett Fenton Gledhill Gooch Greaves Haigh Heald Hepworth Holroyd Hurst Jagger Kitching Leadbetter Mallinson Moxon Nuttall Ollerton Pilling Priestley Rawlinson Rothwell Scholey Shuttleworth Stott Tattersall Tetley Toothill Walmsley Whittle Wilde Worrall Taylor Brown Wilson Walker Wright Robinson Thompson White Hughes Edwards Green Hall Wood Harris Clarke Jackson Turner Hill Moore Cooper Ward Morris King Watson Harrison Baker Young Allen Mitchell Bell Bennett Parker Price Knight Mason Marshall Hunt Holmes Mills Palmer Butler Barker Barnes Payne Fox Pearson Rose Lane Chapman Matthews Gibson Russell Fisher Spencer Stevens Burton Kemp Saunders Field Barber Gill Hammond Lucas Moss Simpson Stone Wade West Webb Wells Wilkinson Woodward Atkinson Bailey Carr Cross Davison Elliott Ford Gardner Gray Hawkes Hopkins Howard Jennings Kelly Lowe Mann Newman Nicholls Page Pope Read Reeves Rowe Sharp Short Steele Sutton Thorpe Tucker Vincent Walton Weston Wheeler Wyatt",
		"half": true,
		"r": "Ash Black Brad Brook Clay Cran Dun Fair Green Hal Hart Haw Holl Lang Mars Oak Pen Rad Red Stan Thorn Whit Wood Ald Bar Brom Cal Ell Fen Gar Har Kel Lin Mor Nor Pres Ray Shel Stam Tal Wal Wes Wint Ack Bel Bur Cars Dal Eg Hamp Hill Kings Mid Mil Ned Ox Pick Rush Sef Sher Silver Stock Thur Wake Wil",
		"x": "ford worth ley ton field wood well by shaw ham bridge more wick stone dale croft land ridge hurst cliffe",
	},
	"SCOTLAND": {
		"f": "Callum Ryan Lewis Jamie Kyle Scott Craig Ross Euan Fraser Calum Kieran Lachlan Finlay Struan Ewan Angus Murray Hamish Gregor Alistair Dougie Graeme Kenny Stuart Gordon Neil Grant Blair Rory Robbie Cammy Ali Iain Duncan Fergus Ruaridh Logan Cole",
		"s": "Campbell Stewart Robertson Ross Reid Paterson Henderson Morrison Hamilton Graham Mackenzie Mackay Kerr Johnston Cameron Hunter Docherty Gallacher Gillespie Kinnear Lennox Lindsay Maxwell Munro Ogilvie Rennie Ritchie Sinclair Sutherland Wallace Baird Buchanan Craigie Drummond Forsyth Galbraith Guthrie Imrie Laidlaw Lumsden Menzies Moffat Nisbet Rankin Tennant Urquhart Weir Aitken Blackie Carmichael Chalmers Duthie Fyfe Gourlay Haig Inglis Jamieson Kidd Leckie Mowat Pirie Rattray Telfer Wishart Crichton Dunlop Elder Findlay Mackinnon Macleod Mackie Macrae Lamont Shanks Dalziel Halliday Kinloch Lockhart Macaulay Ramage Sneddon Tosh",
		"r": "Aber Bal Ben Craig Dal Dun Glen Inver Kil Kin Loch Strath Auch Bal Car Fin",
		"x": "nie lie ton gour more lay rie don",
	},
	"IRELAND": {
		"f": "Sean Conor Cian Darragh Oisin Eoin Ciaran Padraig Niall Ronan Fionn Cathal Shane Declan Colm Donal Killian Rory Aidan Dara Tadhg Liam Jack Evan Dylan Ruairi Eamon Cormac Brendan Kevin Fiachra",
		"s": "Murphy Kelly Byrne Ryan Doyle Walsh Kennedy Lynch Murray Quinn Moore Doherty Brennan Gallagher Duffy Nolan Kavanagh Dunne Carroll Connolly Daly Farrell Fitzgerald Hogan Kearney Mulligan Nugent Reilly Sheridan Tierney Whelan Brady Callaghan Cullen Devlin Egan Flanagan Foley Geraghty Hennessy Hickey Keogh Lennon Mahony Moran Nevin Phelan Scanlon Toner Behan Corrigan Delaney Finnegan Gilroy Horgan Kinsella Lalor Meehan Noonan Power Regan Shiels Costello Dempsey Fahy Galvin Hanrahan Kiely Lonergan Madden Moynihan Quigley Ruane Tobin",
	},
	"WALES": {
		"f": "Rhys Gareth Dylan Owen Iwan Huw Cai Osian Gethin Aled Dafydd Emyr Ieuan Tomos Llyr Rhodri Steffan Morgan Jac Ioan Wyn Elis Ifan Ffion Bryn Geraint Lloyd",
		"s": "Jones Williams Davies Evans Thomas Roberts Hughes Lewis Morgan Griffiths Owen Price Jenkins Lloyd Parry Pritchard Powell Rees Vaughan Bowen Howells Llewellyn Meredith Pugh Prosser Bevan Gwynne Probert Hopkins Phillips Watkins Hywel Rowlands Ellis Edwards Harries Mathias Morris Tudor Cadwalader Bevan Gittins Jarman Prydderch Treharne",
	},
	"USA": {
		"f": "Tyler Brandon Christian Zack Jordan Austin Cody Chase Logan Hunter Mason Caleb Garrett Dylan Wyatt Gavin Cole Trevor Brady Landon Bryce Colton Derek Jared Gio Malik Andre Jalen Darius Isaiah Tyrell Brenden Cade Easton Jace Kellen Paxton Tanner Riley",
		"s": "Rodriguez Johnson Miller Davis Anderson Taylor Jackson Thompson White Harris Clark Robinson Walker Young Allen King Wright Hill Green Baker Nelson Carter Mitchell Turner Campbell Parker Collins Stewart Cook Rogers Peterson Cooper Bailey Bell Howard Richardson Watson Brooks Bennett Gray Sanders Myers Foster Jenkins Perry Russell Sullivan Barnes Fisher Coleman Simmons Patterson Reynolds Hayes Gibson Tucker Porter Hicks Crawford Boyd Warren Burns Gordon Holmes Rice Hunt Daniels Palmer Mills Knight Rose Stone Perkins Hudson Gardner Payne Pierce Berry Matthews Willis Olson Duncan Snyder Cunningham Lane Andrews Harper Fox Riley Carpenter Weaver Greene Elliott Sims Kelley Franklin Bishop Dalton Hendricks Kowalczyk Lindgren Novak Ostrander Pruitt Sawyer Whitman",
	},
	"DENMARK": {
		"f": "Mads Jonas Mikkel Rasmus Kasper Frederik Mathias Emil Oliver Lucas Magnus Christian Anders Nikolaj Simon Søren Jesper Morten Thomas Martin Jakob Andreas Tobias Viktor Oskar Villads Malthe Asger Gustav Aksel Laurits Johan Esben Troels Rune Kristian Bjarke Jeppe Mikael Nicklas Patrick Sebastian Alexander Carl August Valdemar Silas Elias Noah William Philip Holger Kim Lasse Ulrik Kenneth Claus Henrik Bastian Benjamin Hjalte Marius Theis Sylvester Albert Anton Ludvig",
		"s": "Andersen Christiansen Mortensen Thygesen Kristoffersen Lauridsen Mikkelsen Bertelsen Vestergaard Kjærgaard Lindgaard Nørgaard Søndergaard Østergaard Holmgaard Damgaard Bækgaard Overgaard Skovgaard Bundgaard Krogh Bach Brix Busk Dalsgaard Fogh Frost Hald Høj Juul Kjeldsen Kragh Lykke Mølgaard Nygaard Riis Rønn Schou Sloth Stampe Thorup Toft Vinther Winther Bonde Borup Brøndum Dyhr Egholm Fruergaard Gade Grønbech Hvid Ibsen Jessen Kirk Kold Lund Melby Nissen Pallesen Ravn Refslund Rytter Schack Skou Steffensen Svane Tang Thybo Uhre Vang Wiborg Aaskov Bjerre Bruun Degn Elmholt Fisker Gram Hedegaard Isaksen Kaae Lauge Malling Nyholm Okholm Plauborg Qvist Rosendahl Sejer Tingleff Ulstrup Vad Westh Bisgaard Brink Dreyer Fabricius Glud Hauge Holst Kamp Klitgaard Lerche Munch Nordahl Pihl Raun Seier Stokholm Thrane Bendix Elkjær Feldt Graversen Haslund Iversen Kock Ladefoged Lassen Mejlby Nørby Poulsgaard Rask Skytte Storgaard Thomsen Tvede Vesterlund",
		"r": "Lind Holm Skov Dal Bæk Ny Øster Vester Sønder Nør Mølle Kirke Bro Eng Strand Birk Rose Sand Kjær Hede Fjord Stub Mose Bjerg Dam Grøn Hvid Lille Kro Hjort Ege Ask Bøg Elm Fur Lyng Mark Rav Tved",
		"x": "gaard holm berg bæk lund dahl strup bjerg skov rup by høj vig sø mark lev sted",
		"half": true,
	},
	"SWEDEN": {
		"f": "Erik Johan Lars Anders Gustav Oscar Viktor Axel Hugo Filip Isak Emil Linus Albin Elias Ludvig Nils Olle Sixten Hampus Melker Alvin Jonatan Pontus Rasmus Sebastian Kristoffer Joel Simon Marcus Henrik Mattias Robin Dennis Jesper Kalle Sven Arvid Love Valter",
		"s": "Lindqvist Sjöberg Holmström Bergkvist Nyström Wikström Lundgren Ekström Sandberg Dahlin Hedlund Åberg Engström Blomqvist Söderberg Wallin Strand Hägg Norén Lindahl Ström Björk Falk Ek Gran Lind Ahlberg Berglund Edlund Fransson Grahn Hultgren Jönsson Kjellberg Lövgren Magnusson Nordin Öberg Persson Rydberg Sundqvist Thörn Unger Westerberg",
		"r": "Berg Lind Sjö Holm Ny Wik Fors Lund Ek Sand Dahl Hed Eng Blom Söder Norr Ström Ahl Hag Fjäll Gran Häll Kvarn Lönn Rönn Ulv Vall",
		"x": "ström qvist berg gren lund dahl holm man bäck by mark",
	},
	"NORWAY": {
		"f": "Ole Magnus Sondre Eirik Håkon Sigurd Torbjørn Vegard Kristian Henrik Mathias Jonas Sander Tobias Aksel Jørgen Anders Espen Fredrik Martin Stian Kjetil Lars Bjørn Mats Halvor Iver Jostein Morten Vetle Eskil",
		"s": "Haugen Solberg Moen Bakken Strand Lie Dahl Brekke Nygaard Aas Sæther Myhre Hagen Fjeld Vik Løken Tangen Tveit Rønning Holte Engen Sandvik Lunde Kvamme Bjerke Skaug Rød Eide Grønli Aune Berntsen Dybvik Fossum Grimstad Hovde Kleiven Lien Nesheim Opdal Rustad Skjelbred Tollefsen Ulvestad Vestby",
		"r": "Haug Sol Bakk Brekk Fjeld Sand Lund Tveit Ask Bjerk Holt Eng Rød Vest Nord Kvam Myr Stav Fors Grov Lyng Hel",
		"x": "en berg vik land lie dal stad heim nes rud ås",
	},
	"ICELAND": {
		"f": "Gunnar Hörður Jóhann Birkir Kári Rúnar Arnór Sverrir Einar Ólafur Jón Stefán Bjarki Viðar Haukur Eiður Atli Sindri Elías Andri Hilmar",
		"s": "Jónsson Einarsson Stefánsson Arnarsson Óskarsson Björnsson Þórsson Haraldsson Pálsson Magnússon Ingason Guðnason Helgason Ólafsson Sveinsson Baldursson Hallsson Kristjánsson Eggertsson Valsson Hjaltason Ásgeirsson Bergsson",
	},
	"FINLAND": {
		"f": "Mikko Jukka Teemu Juho Antti Joni Lauri Eetu Onni Aleksi Ville Sami Tuomas Jere Niko Oskari Kalle Petri Veikko Rasmus Elias Leevi Topias",
		"s": "Virtanen Korhonen Mäkinen Nieminen Heikkinen Laine Koskinen Järvinen Lehtonen Salo Hakala Rantanen Kallio Peltonen Tikkanen Hämäläinen Väisänen Ojala Leppänen Kivelä Saarinen Valtonen Mattila Laaksonen Aaltonen",
		"r": "Virt Kosk Järv Mäk Niem Lehto Rant Pelt Kivi Saari Laak Aalto Hirv Kuus Mets Suo Vuor Lah Kank Tikk",
		"x": "anen inen onen ala nen",
	},
	"NETHERLANDS": {
		"f": "Daan Sem Thijs Lars Bram Ruben Jesse Stijn Joost Niels Sven Luuk Milan Jens Tim Bas Teun Jasper Floris Wout Jelle Koen Rick Maarten Gijs Hidde Siem Tygo Mees Noud Pim Roel Wessel Youri Dirk Jorrit Kees Sjoerd Thom Jurre Ties Lucas Finn Joep Olaf",
		"s": "de_Vries Bakker Visser Smit Meijer de_Boer Mulder de_Groot Bos Vos Hendriks van_Leeuwen Dekker Brouwer de_Wit Dijkstra Smits de_Graaf van_der_Meer van_der_Linden Kok de_Haan Vermeulen van_den_Berg van_Beek Kuipers Veenstra Schouten Hoekstra Bosman Brink Dijkman Evers Groenewegen Hoogland Jonker Koster Lammers Nijhuis Oosterhuis Post Roelofs Schipper Timmermans Verbeek Wolters Zwart Blom Claassen Driessen Gerritsen Huisman Kramer Molenaar Prins Scholten Tromp Veldman Willemsen",
		"r": "Hoek Veen Dijk Kamp Brink Hof Kroon Smal Groen Wester Ooster Mol Stam Klaas Jans Wouter Dirk Berk Bruin Elzen Haver Kuil Lin Meer Ruiter Stoel Vogel Wit",
		"x": "stra ma inga sen ink huis man kamp veld",
		"half": true,
		"pre": "van_ van_der_ van_de_ ter_ ",
		"pr": "Ommen Zwolle Delden Hoorn Gelder Rijn Aken Dam Wijk Bergen Leer Lent Tol Marle Daal Vliet Holt Dongen Kessel Eck Loon Haaren Velde Dalen Hulst Goor Asten Bree",
	},
	"BELGIUM": {
		"f": "Wout Arne Jens Bram Lander Kobe Senne Stijn Thibault Maxime Romain Arthur Victor Nathan Louis Mathias Ruben Siebe Wannes Jarne Brecht Hugo Lucas Jules Cédric Olivier Elias Milan Rayane",
		"s": "Claes Peeters Janssens Maes Jacobs Willems Goossens Wouters De_Smet Dubois Lambert Dupont Leclercq Lemaire Hermans Verbeke Van_Damme Vandenberghe Desmet Verhaegen Coppens Segers Pauwels Declercq Hendrickx Michiels Vermeiren Wuyts Cools De_Wilde Martens Van_Hove Lemmens Vanhoutte Bogaert Callens Delvaux Dewaele Geerts Lievens Moens Pieters Raes Stevens Thys Vercammen Vlaeminck",
		"alt": ["NETHERLANDS", 0.25],
	},
	"GERMANY": {
		"f": "Lukas Leon Finn Jonas Paul Felix Maximilian Elias Noah Ben Luis Niklas Tim Jan Moritz Julian Tobias Florian Sebastian Fabian Dominik Marcel Kevin Dennis Pascal Philipp Matthias Johannes Simon Lennart Jannik Malte Henrik Kilian Constantin Benedikt Vincent Lars Timo Nils Robin Sven Christoph Stefan Marvin Jonathan Niko Till Bastian Hannes Ole Anton Emil Jakob Linus Mattis Theo Erik Valentin Joel Leonhard",
		"s": "Schneider Fischer Weber Wagner Becker Schäfer Richter Klein Wolf Schröder Neumann Schwarz Zimmermann Braun Krüger Hartmann Lange Schmitt Krause Meier Lehmann Köhler Herrmann König Walter Mayer Huber Kaiser Fuchs Lang Scholz Möller Weiß Jung Hahn Vogel Keller Roth Berger Winkler Lorenz Ludwig Pohl Kuhn Engel Haas Sommer Graf Seidel Heinrich Schulte Dietrich Ziegler Kühn Arnold Bauer Voigt Busch Franke Beck Böhm Jäger Albrecht Pfeiffer Ernst Kraft Seifert Wendt Ebert Stahl Brenner Hauser Kessler Riedel Winter Gerber Kraus Hesse Brinkmann Dreher Eberle Feldmann Gärtner Hagedorn Janssen Kirchner Lindemann Marquardt Oberle Pfeifer Reimann Sauer Thiele Ulrich Vollmer Wetzel Zander",
		"r": "Stein Berg Hof Wald Feld Bach Rosen Lichten Eichen Kirch Linden Brunn Hohen Falken Schön Grün Ober Unter Alt Neu Mühl Holz Sonnen Adler Kalten Hirsch Buch Dorn Eisen Fels Hag Kamm Lauten Moor Reh Sand Tann Wies",
		"x": "mann berger bauer hofer ner meier feld haus bach stein brink reuter dorf hagen",
		"half": true,
	},
	"AUSTRIA": {
		"f": "Lukas David Florian Stefan Michael Christoph Konrad Xaver Philipp Marco Valentin Raphael Matthias Andreas Alexander Thomas Sebastian Patrick Dominik Manuel Leopold Maximilian Jakob Tobias Simon",
		"s": "Gruber Huber Leitner Pichler Moser Steiner Hofer Eder Wimmer Lechner Haider Brunner Schwaiger Aigner Wallner Mayrhofer Strasser Holzer Ebner Reiter Fink Egger Auer Winkler Hofbauer Kofler Lindner Obermair Pölzl Rainer Stadler Unterberger Wieser Zauner Grabner Hinterseer Kogler Maier Pucher Riegler",
		"alt": ["GERMANY", 0.3],
	},
	"SWITZERLAND": {
		"f": "Luca Noah Nico Fabian Remo Silvan Cedric Jonas Yannick Kevin Fabio Granit Xherdan Michel Pascal Gian Reto Andrin Joel Nils Loris Elia Timo Dario",
		"s": "Frei Meier Keller Gerber Baumann Brunner Kälin Zürcher Schärer Steiner Wyss Hürlimann Zbinden Rüegg Imhof Ammann Bühler Egli Fässler Gisler Hess Inderbitzin Kuster Lüthi Marti Nägeli Oberholzer Rohner Schnyder Tanner Vogt Widmer Zollinger Bachmann Christen",
		"alt": ["GERMANY", 0.2],
	},
	"SPAIN": {
		"f": "Pablo Alejandro Daniel Javier Sergio Carlos David Adrián Álvaro Diego Hugo Mario Iván Raúl Rubén Marcos Jorge Víctor Alberto Fernando Manuel Miguel Antonio Ángel Gonzalo Iker Unai Asier Aitor Íñigo Mikel Jon Oriol Pau Jordi Marc Xavi Gerard Joan Nacho Dani Rodrigo Héctor Samuel Andrés Guillermo Enrique Tomás Borja Kike Julen Óscar Ignacio Martín Lucas Bruno Eric Izan Aleix Ander Iago Lander Ximo Toni Rafa Quique",
		"s": "García Fernández López Martínez Sánchez Pérez Gómez Jiménez Ruiz Hernández Díaz Muñoz Álvarez Romero Gutiérrez Navarro Domínguez Vázquez Gil Ramírez Serrano Blanco Morales Suárez Ortega Delgado Castro Ortiz Rubio Marín Sanz Iglesias Medina Garrido Cortés Castillo Santos Lozano Guerrero Cano Prieto Méndez Cruz Calvo Gallego Vidal León Márquez Herrera Peña Flores Cabrera Campos Vega Fuentes Carrasco Diez Caballero Reyes Nieto Aguilar Pascual Santana Herrero Lorenzo Hidalgo Montero Ibáñez Giménez Ferrer Durán Santiago Benítez Mora Vicente Vargas Arias Carmona Crespo Román Pastor Soto Sáez Velasco Moya Parra Esteban Bravo Gallardo Rojas Pardo Espinosa Izquierdo Lara Rivas Rivera Casado Arroyo Redondo Camacho Rey Vera Otero Luque Galán Montes Ríos Sierra Segura Carrillo Soriano Mendoza Etxeberria Aranburu Goikoetxea Urrutia Arrieta Elizalde Mendizabal Larrañaga Agirre Olabarria Bengoetxea Ibarra Txurruka Puig Vila Roca Pujol Font Casals Batlle Riera Bosch Mas Sala Planas Coll Prats Vives Rovira Alarcón Barrientos Bermejo Cuesta Escudero Figueroa Granados Lucena Madrid Manzano Miranda Ocaña Palacios Quintana Robles Salinas Toledo Valero Villalobos Zamora Andújar Bustos Cámara Echeverría Gamarra Jurado Lanza Llamas Maroto Novoa Olmedo Pizarro Quesada Rosales Tejada Uriarte Valverde Yáñez Zurita Arteaga Beltrán Cisneros Echevarría Ferreras Garcés Lasa Medrano Oyarzabal Recio Solana Trujillo Vallejo",
	},
	"PORTUGAL": {
		"f": "João Tiago Rui Diogo Gonçalo Rodrigo Pedro Miguel Francisco André Bruno Nuno Ricardo Hugo Fábio Daniel Vítor Rafael Tomás Afonso Duarte Martim Gustavo Henrique Luís Paulo Sérgio Hélder Jorge Filipe Simão Renato Gil Vasco Leonel Fausto Telmo Ivo Xavier Lourenço Salvador Rúben Dinis Bernardo Valter",
		"s": "Silva Santos Ferreira Pereira Oliveira Costa Rodrigues Martins Sousa Fernandes Gonçalves Gomes Lopes Marques Alves Almeida Ribeiro Pinto Carvalho Teixeira Moreira Correia Mendes Nunes Soares Vieira Monteiro Cardoso Rocha Raposo Neves Coelho Cruz Cunha Pires Ramos Reis Simões Antunes Matos Fonseca Machado Araújo Barbosa Tavares Lourenço Castro Figueiredo Azevedo Freitas Henriques Baptista Faria Brito Esteves Mota Lima Barros Pacheco Campos Magalhães Valente Pimenta Seabra Brandão Calado Amaral Barreto Leite Couto Guerreiro Abreu Vaz Domingues Morais Loureiro Sequeira Bastos Dias Paiva Rebelo Salgado Caldeira Portela Marinho Peixoto Torres Cerqueira Viana Vilela Andrade Belo Carneiro Damião Encarnação Frade Galvão Jardim Lacerda Meireles Nogueira Ornelas Quintas Rosário Serrão Taveira Varela Xavier Amorim Botelho Cordeiro Esteves Ferraz Garrido Lobo Medeiros Moniz Penedo Sampaio Teles Valadares",
	},
	"BRAZIL": {
		"f": "Gabriel Lucas Matheus Pedro Guilherme Gustavo Rafael Felipe Bruno Thiago Vinícius Leonardo Caio Igor Diego Rodrigo Danilo Eduardo Marcelo Renan Wesley Willian Douglas Everton Anderson Jefferson Wellington Robson Cleiton Luan Kaio Yuri Breno Davi Arthur Heitor Enzo Murilo Juninho Paulinho Fabrício Maicon Rogério Talles Wendel Ygor Kauã Ruan Erick Joaquim",
		"s": "Silva Santos Oliveira Souza Lima Pereira Ferreira Costa Rodrigues Almeida Nascimento Alves Carvalho Araújo Ribeiro Gomes Martins Rocha Barbosa Moura Cardoso Teixeira Correia Dias Cavalcanti Monteiro Mendes Freitas Barros Pinto Moreira Vieira Campos Nunes Azevedo Batista Fonseca Machado Andrade Lopes Ramos Siqueira Peixoto Brandão Queiroz Rezende Prado Tavares Bezerra Guimarães Farias Medeiros Leal Aguiar Pacheco Xavier Sampaio Bastos Damasceno Fagundes Paixão Moraes Vasconcelos Magalhães Duarte Bittencourt Cordeiro Drummond Esteves Falcão Gusmão Holanda Junqueira Lacerda Macedo Nóbrega Pimentel Quintela Rangel Sobral Toledo Valença",
	},
	"ARGENTINA": {
		"f": "Juan Santiago Matías Nicolás Facundo Agustín Franco Joaquín Tomás Ezequiel Gonzalo Federico Maximiliano Leandro Emiliano Germán Ramiro Thiago Valentín Bautista Lucas Mauro Gastón Cristian Marcos Diego Pablo Hernán Julián Ignacio Rodrigo Fernando Sebastián Esteban Alejo Nahuel Exequiel Lisandro Benjamín Mateo Luciano Darío Ariel Claudio Walter",
		"s": "González Rodríguez Gómez Fernández López Díaz Martínez Pérez Romero Sosa Álvarez Torres Ruiz Ramírez Flores Benítez Acosta Medina Herrera Suárez Aguirre Giménez Gutiérrez Pereyra Rojas Molina Castro Ortiz Silva Núñez Luna Juárez Cabrera Ríos Ferreyra Godoy Morales Domínguez Moreno Peralta Vega Carrizo Quiroga Castillo Ledesma Muñoz Ojeda Ponce Vera Vázquez Villalba Cardozo Navarro Coronel Figueroa Paz Correa Cáceres Vargas Rivero Toledo Ibarra Arias Maldonado Mansilla Farías Rivas Garrido Chávez Bustos Lucero Bianchi Ferrari Romano Rossi Colombo Barrios Insúa Zárate Palacios Funes Albornoz Benedetto Cufré Echeverri Galarza Iturbe Lanús Marchesín Olmos Pizzi Quinteros Retamar Sabella Tagliafico Urquiza Villar Zabala",
	},
	"URUGUAY": {"alt": ["ARGENTINA", 1.0]},
	"MEXICO": {
		"f": "José Luis Jesús Alejandro Miguel Ángel Jorge Carlos Juan Fernando Eduardo Ricardo Roberto Raúl Héctor Hugo Erick Edson Diego Andrés Uriel Alexis Santiago Rodrigo Jair Jonathan Brayan Kevin Emilio Gerardo Omar",
		"s": "Hernández García Martínez López González Rodríguez Pérez Sánchez Ramírez Cruz Flores Gómez Morales Vázquez Reyes Jiménez Torres Díaz Gutiérrez Ruiz Mendoza Aguilar Ortiz Moreno Castillo Romero Álvarez Méndez Chávez Rivera Juárez Ramos Domínguez Herrera Medina Castro Vargas Guzmán Velázquez Rojas Contreras Salazar Ortega Delgado Estrada Cervantes Ochoa Ibarra Navarro Montes Ávila Lozano Zamora Guerrero Cortés Fuentes Villanueva Robles Esquivel Escobar",
	},
	"ITALY": {
		"f": "Lorenzo Alessandro Francesco Leonardo Mattia Andrea Gabriele Riccardo Tommaso Edoardo Matteo Giuseppe Antonio Federico Davide Marco Luca Simone Stefano Nicola Daniele Paolo Fabio Giacomo Pietro Filippo Michele Salvatore Vincenzo Alberto Emanuele Cristian Manuel Gianluca Roberto Enrico Massimo Claudio Dario Samuele Christian Raffaele Gennaro Ciro Domenico Carmine Nicolò Jacopo Diego Valerio Alessio Elia Mirko Sergio Ivan Fausto Giulio",
		"s": "Rossi Russo Ferrari Esposito Bianchi Romano Colombo Ricci Marino Greco Bruno Gallo Conti De_Luca Mancini Costa Giordano Rizzo Lombardi Moretti Barbieri Fontana Santoro Mariani Rinaldi Caruso Ferrara Galli Martini Leone Longo Gentile Martinelli Vitale Lombardo Serra Coppola De_Santis Marchetti Parisi Villa Conte Ferraro Ferri Fabbri Bianco Marini Grasso Valentini Messina Sala De_Angelis Gatti Pellegrini Palumbo Sanna Farina Rizzi Monti Cattaneo Morelli Amato Silvestri Mazza Testa Grassi Pellegrino Carbone Giuliani Benedetti Barone Rossetti Caputo Montanari Guerra Palmieri Bernardi Martino Fiore De_Rosa Ferretti Bellini Basile Riva Donati Piras Vitali Battaglia Sartori Neri Costantini Milani Pagano Ruggiero Sorrentino Orlando Negri Bassi Fumagalli Brambilla Colonna Pozzi Cocco Borghi Bertolini Tedesco Lucchesi Ferrante Moro Orsini Tosi",
		"r": "Bel Cor Fer Gal Mar Ross Sant Vit Bert Cast Lan Mor Pell Ser Tor Zan Bon Cap Del Fal Gior Lomb Mart Nar Orl Pir Rug Sal Ten Val Bar Cam Dor Fon Gual Mas Pad Ric Spin Tam",
		"x": "ini elli etti oni ucci ato ari esi ardi azzi ello otti asso",
	},
	"FRANCE": {
		"f": "Lucas Hugo Théo Louis Nathan Mathis Enzo Maxime Thomas Antoine Clément Alexandre Baptiste Quentin Romain Nicolas Julien Kevin Florian Benjamin Paul Arthur Jules Gabriel Raphaël Adrien Valentin Bastien Corentin Damien Jérémy Loïc Mathieu Rémi Sacha Tristan Yann Yanis Rayan Wesley Jordan Aurélien Gaël Hervé Pierre Olivier Vincent Grégory Christophe Léo Noé Timothée Evan Axel Malo Gaspard Elouan Mattéo Killian Lenny Johan",
		"s": "Martin Bernard Dubois Robert Richard Petit Durand Leroy Moreau Simon Laurent Lefèvre Michel David Bertrand Roux Vincent Fournier Morel Girard André Lefebvre Mercier Dupont Lambert Bonnet François Legrand Garnier Faure Rousseau Blanc Guérin Henry Roussel Perrin Morin Clément Gauthier Dumont Fontaine Chevalier Robin Masson Gérard Boyer Denis Lemaire Duval Joly Gautier Roger Roche Roy Noël Lucas Meunier Marchand Dufour Blanchard Barbier Brun Dumas Brunet Leroux Colin Renard Arnaud Rolland Caron Aubert Giraud Leclerc Bourgeois Renaud Lemoine Picard Gaillard Lacroix Fabre Dupuis Hubert Guillot Rivière Le_Gall Le_Goff Guillaume Adam Moulin Lecomte Ménard Fleury Carpentier Benoît Maillard Marchal Aubry Vasseur Le_Roux Renault Jacquet Collet Prévost Poirier Charpentier Royer Huet Baron Dupuy Pons Carré Breton Rémy Perrot Guyot Barre Marty Cousin",
		"r": "Bel Bou Char Chev Dur Fon Gar Lam Mar Mor Per Rou Sau Tour Val Ver Beau Cham Font Gir Mont Lav Ross Bréd Cour Gren Lach Mail Pel Riv",
		"x": "ard ier on et eau ac ais aud in ot elle ière ille",
		"alt": ["FRANCE_AF", 0.25],
	},
	"FRANCE_AF": {
		"f": "Moussa Ibrahima Mamadou Youssouf Bakary Souleymane Adama Ismaël Kader Malik Amine Nabil Sofiane Issa Ousmane Yacine Mohamed Karim Samir Lassana Boubacar Djibril Kalidou Ilyes",
		"s": "Diallo Traoré Koné Camara Cissé Konaté Doucouré Diaby Touré Sylla Keita Diakité Bakayoko Fofana Coulibaly Sangaré Diarra Ndiaye Diop Sow Gueye Benali Haddad Mansouri Belkacem Bensaïd Zerrouki Kanouté Dramé Soumaré Tounkara Sidibé Niakaté Baldé Kouyaté Djaló Gassama Sakho Mbemba",
	},
	"SENEGAL": {
		"f": "Moussa Ibrahima Mamadou Cheikh Abdou Ousmane Pape Lamine Babacar Saliou Alioune Modou Malick Idrissa Boubacar Youssouf Bakary Seydou Souleymane Aliou Khadim Fallou Amadou Serigne Ndiaga Ablaye",
		"s": "Diallo Ndiaye Diop Sarr Faye Fall Gueye Sow Ba Cissé Mbaye Seck Sy Niang Thiam Diouf Ndour Badji Diatta Sagna Camara Traoré Koné Touré Coulibaly Diarra Keita Konaté Bamba Kouassi Yao Kouamé Zahui Seri Mbengue Ndao Samb Tall Wade Diedhiou Goudiaby Sané Dieng",
	},
	"NIGERIA": {
		"f": "Chukwuemeka Emeka Chidi Ikenna Obinna Tochukwu Uche Kelechi Victor Samuel Daniel Kwame Kofi Kwabena Yaw Kojo Kwasi Abdul Ibrahim Joseph Emmanuel Godfrey Felix Isaac Ebuka Femi Tunde Ademola Segun Chinedu Nnamdi Osas",
		"s": "Okafor Okonkwo Eze Nwosu Adeyemi Balogun Okoro Uzoma Obi Nwankwo Onyekachi Adebayo Afolabi Ogunleye Olawale Chukwu Mensah Asante Owusu Appiah Agyemang Ofori Amponsah Darko Adjei Osei Frimpong Ansah Opoku Annan Quaye Tetteh Kyei Bonsu Nkansah Akpan Ekong Etim Udoh Ogbonna Nwachukwu Oduya Abiodun Bassey",
	},
	"MOROCCO": {
		"f": "Youssef Hakim Sofiane Amine Ayoub Nabil Karim Mehdi Yassine Ilias Zakaria Hamza Anass Bilal Ismail Walid Adel Rachid Tarik Nordin Soufiane Oussama Said Mounir Badr Othmane Reda Imran",
		"s": "El_Amrani Benali Bennani Alaoui Tazi El_Idrissi Berrada Chraibi El_Fassi Ziani Bouzid Haddad Mansouri Belhadj Saidi Ouali El_Khalfi Benjelloun Lahlou Bouhaddi Naciri Rami Tahiri Kabbaj Sabri Zerouali Hamdani El_Mansouri Bakkali Ghazi Aziz Ennaji Lamrani Ouazzani Skalli Tounsi",
	},
	"TURKEY": {
		"f": "Emre Burak Mehmet Mustafa Ahmet Ali Can Cem Kerem Yusuf Ozan Onur Hakan Serkan Volkan Selim Umut Eren Efe Berk Kaan Tolga Oguz Halil Ismail Furkan Enes Taha Doruk Alp Baris Mert Okan",
		"s": "Yilmaz Kaya Demir Sahin Celik Yildiz Yildirim Öztürk Aydin Özdemir Arslan Dogan Kilic Aslan Cetin Kara Koc Kurt Özkan Simsek Polat Korkmaz Erdem Tekin Aksoy Keskin Bulut Tas Uysal Yavuz Acar Duman Karaca Ergin Sezer Bozkurt Kaplan Toprak Altun Ünal Akbulut Coskun Durmaz Gürbüz Karakus Sarac Tunc",
	},
	"GREECE": {
		"f": "Giorgos Dimitris Nikos Kostas Giannis Christos Panagiotis Vasilis Thanasis Stelios Lefteris Manolis Sotiris Petros Michalis Alexandros Andreas Spyros Kyriakos Tasos Fotis Apostolos",
		"s": "Papadopoulos Papadakis Georgiou Nikolaidis Konstantinou Dimitriou Ioannou Vasileiou Pappas Karagiannis Oikonomou Makris Antoniou Christodoulou Theodorou Alexiou Mavridis Stavrou Kostopoulos Petridis Galanis Sideris Zervas Karras Lamprou Vlachos Fotiou Raptis Kyriakidis Anagnostou Daskalakis Economou Kalogeropoulos Lazaridis Manolakis",
	},
	"POLAND": {
		"f": "Jakub Kacper Szymon Filip Mateusz Bartosz Kamil Piotr Pawel Michal Tomasz Krzysztof Lukasz Marcin Dawid Adrian Damian Patryk Wojciech Grzegorz Maciej Przemyslaw Sebastian Karol Oskar Igor Hubert Krystian",
		"s": "Nowak Kowalski Wisniewski Wojcik Kowalczyk Szymanski Wozniak Dabrowski Jankowski Mazur Kwiatkowski Krawczyk Piotrowski Grabowski Nowakowski Pawlowski Michalski Nowicki Adamczyk Dudek Zajac Wieczorek Jablonski Krol Majewski Olszewski Jaworski Wrobel Malinowski Pawlak Witkowski Walczak Stepien Gorski Rutkowski Michalak Sikora Ostrowski Baran Duda Szewczyk Tomaszewski Pietrzak Marciniak Zalewski Jakubowski Jasinski Zawadzki Sadowski Chmielewski Borkowski Czarnecki Sawicki Sokolowski Urbanski Kubiak Maciejewski Kucharski Wilk Kalinowski Mazurek Wysocki Adamski Sobczak Czerwinski Cieslak Glowacki Zakrzewski Kolodziej Sikorski Krajewski Gajewski",
		"r": "Kowal Nowa Wisn Jank Krol Dab Zaj Wit Gor Sik Bor Czar Sad Sok Wil Bial Brz Chm Gaw Jas Kos Lip Mor Pap Rad Sob Tar Wal Zar",
		"x": "owski ewski inski ak ek czyk iak",
	},
	"CZECHIA": {
		"f": "Jan Jakub Tomas Lukas Ondrej David Adam Matej Vojtech Filip Petr Martin Pavel Michal Marek Jiri Josef Vaclav Ales Radek Zdenek Libor Dominik Stepan",
		"s": "Novak Svoboda Novotny Dvorak Prochazka Kucera Vesely Horak Nemec Pokorny Pospisil Hajek Kral Jelinek Ruzicka Benes Fiala Sedlacek Dolezal Zeman Kolar Navratil Cermak Vanek Urban Blaha Kriz Kovar Bartos Vlcek Polak Musil Kopecky Simek Konecny Maly Holub Stastny Hruby Soukup Sykora Tichy Moravec Machacek Bartak Kubat Mares Stransky Vacek Hora Stepanek Krejci Matousek Hlavacek",
	},
	"CROATIA": {
		"f": "Luka Marko Ivan Nikola Filip Mateo Josip Ante Mario Domagoj Bruno Dario Tomislav Ivica Mislav Borna Toni Kristijan Lovro Sandro Dino Petar Igor Leon Roko Duje",
		"s": "Horvat Kovacevic Babic Maric Juric Knezevic Vukovic Markovic Matic Tomic Pavlovic Bozic Blazevic Grgic Pavic Radic Peric Kos Klaric Lovric Vidovic Perkovic Popovic Brkic Jukic Bilic Bosnjak Galic Sesar Barisic Mlinaric Rukavina Butkovic Cosic Dragic Erceg Franjic Glavas Grbic Hrgovic Ivankovic Jelavic Lucic Majstorovic Nincevic Pranjic Radeljic Sertic Vrdoljak Zec Zovko",
	},
	"SERBIA": {
		"f": "Luka Marko Nikola Stefan Filip Aleksandar Milos Nemanja Dusan Lazar Vuk Petar Zoran Dejan Bojan Uros Vladimir Srdjan Mihajlo Andrija Veljko Strahinja Ognjen Lazar",
		"s": "Jovanovic Petrovic Nikolic Djordjevic Stojanovic Ilic Stankovic Pavlovic Milosevic Popovic Zivkovic Jankovic Todorovic Ristic Milovanovic Stevanovic Lazic Simic Radovanovic Obradovic Vasic Kovacevic Dimitrijevic Lukic Petkovic Gavrilovic Djukic Mladenovic Bogdanovic Ivanovic Zoric Radic Krstic Milic Sekulic Spasic Blagojevic Arsenijevic Kuzmanovic Velickovic Veljkovic Maksimovic Lalic",
		"r": "Jov Petr Nik Mark Stoj Stank Pavl Pop Ziv Jank Tod Rist Stev Laz Sim Rad Vas Sav Bog Ivan Vuk Zor Krst Gruj Spas Blag Maks Dragan Bran Vel Sret Ljub Mir Dob",
		"x": "ovic evic ic",
	},
	"UKRAINE": {
		"f": "Andriy Oleksandr Dmytro Mykola Serhiy Yuriy Taras Vitaliy Bohdan Artem Maksym Ivan Oleh Roman Viktor Volodymyr Ruslan Yevhen Vladyslav Illya Mykhailo Danylo Nazar Kyrylo",
		"s": "Bondarenko Kovalenko Tkachenko Kravchenko Kovalchuk Oliynyk Shevchuk Polishchuk Lysenko Moroz Marchenko Petrenko Savchenko Rudenko Melnyk Kuzmenko Pavlenko Klymenko Hrytsenko Levchenko Ostapenko Sydorenko Vasylenko Romanenko Danylyuk Kostenko Mazur Kravets Honcharuk Fedorenko Didenko Ponomarenko Nazarenko Hnatyuk Semenyuk Ivanenko Prykhodko Karpenko",
		"r": "Bondar Koval Tkach Krav Lys Mar Petr Sav Rud Kuz Pav Klym Lev Ost Syd Vas Rom Kost Fed Did Naz Ivan Karp Hlib Zhur",
		"x": "enko chuk yuk ko",
	},
	"JAPAN": {
		"f": "Haruto Yuto Sota Ren Hiroki Takumi Daiki Kenta Ryota Shota Yuki Kaito Riku Sho Kazuki Takeshi Kento Daichi Hayato Koji Naoki Yuma Keisuke Tsubasa Ryo Yusuke Kota Itsuki Minato Soma",
		"s": "Sato Takahashi Tanaka Watanabe Yamamoto Nakamura Kobayashi Kato Yoshida Yamada Sasaki Yamaguchi Matsumoto Inoue Kimura Hayashi Shimizu Yamazaki Mori Abe Ikeda Hashimoto Ishikawa Ogawa Fujita Okada Goto Hasegawa Murakami Kondo Ishii Saito Sakamoto Aoki Fujii Nishimura Fukuda Ota Takeuchi Nakajima Matsuda Harada Ono Tamura Nakano Hirano Kudo Imai Kawaguchi Sugiyama Morita Uchida Takagi Ando Taniguchi Noguchi Kojima Arai Kitamura Iwasaki Wada Miyamoto Sugawara Kanno Chiba Yokoyama Hamada",
	},
}

# A club's foreigners mostly come from these countries (weights), and some leagues lean to their neighbours.
const ABROAD := {"BRAZIL": 8, "ARGENTINA": 6, "FRANCE": 6, "SPAIN": 5, "PORTUGAL": 4, "NETHERLANDS": 4, "GERMANY": 4,
	"ITALY": 3, "BELGIUM": 4, "ENGLAND": 3, "DENMARK": 2, "SWEDEN": 3, "NORWAY": 3, "CROATIA": 3, "SERBIA": 3,
	"POLAND": 3, "SENEGAL": 4, "NIGERIA": 4, "MOROCCO": 3, "JAPAN": 2, "USA": 2, "URUGUAY": 3, "SCOTLAND": 2,
	"IRELAND": 2, "WALES": 1, "AUSTRIA": 2, "SWITZERLAND": 2, "CZECHIA": 2, "UKRAINE": 2, "TURKEY": 1, "GREECE": 1,
	"MEXICO": 1, "ICELAND": 1, "FINLAND": 1}
const LEAN := {
	"ENGLAND": {"IRELAND": 6, "SCOTLAND": 6, "WALES": 4, "NIGERIA": 2},
	"SPAIN": {"ARGENTINA": 8, "URUGUAY": 4, "MEXICO": 3, "BRAZIL": 3},
	"PORTUGAL": {"BRAZIL": 20, "SPAIN": 2},
	"FRANCE": {"SENEGAL": 10, "MOROCCO": 5, "BELGIUM": 3},
	"NETHERLANDS": {"BELGIUM": 5, "MOROCCO": 5},
	"GERMANY": {"AUSTRIA": 6, "SWITZERLAND": 4, "POLAND": 3, "TURKEY": 4, "CROATIA": 2},
	"ITALY": {"ARGENTINA": 4, "BRAZIL": 3, "SERBIA": 2, "CROATIA": 2},
	"DENMARK": {"SWEDEN": 6, "NORWAY": 6, "ICELAND": 3},
	"SCOTLAND": {"ENGLAND": 6, "IRELAND": 5},
	"BELGIUM": {"NETHERLANDS": 5, "FRANCE": 5},
	"TURKEY": {"BRAZIL": 3},
}

# names of real players (and a few famous coaches) that the pools could happen to put together: never made
const BAN := ["Bruno Fernandes", "Gonçalo Ramos", "Nuno Mendes", "André Silva", "Ricardo Pereira", "Tiago Mendes",
	"Ricardo Carvalho", "Paulo Ferreira", "Paulo Sousa", "Rui Costa", "João Pinto", "Nuno Gomes", "Bruno Alves",
	"Pedro Gonçalves", "Pedro Mendes", "Tomás Araújo", "Diogo Costa", "Nuno Santos", "André Almeida", "Rui Silva",
	"André Gomes", "Nuno Tavares", "Hugo Almeida", "Rúben Dias", "Rúben Neves", "João Moutinho", "Thiago Silva",
	"Lucas Moura", "Douglas Costa", "Bruno Guimarães", "Gabriel Barbosa", "Everton Ribeiro", "Diego Costa",
	"Gabriel Magalhães", "Lucas Lima", "Danilo Pereira", "Marcelo Vieira", "Matheus Nunes", "Diego Souza",
	"Douglas Santos", "Thiago Mendes", "Vinícius Souza", "Matheus Pereira", "Anderson Silva", "Sergio Ramos",
	"David Silva", "Pau Torres", "Carlos Soler", "Íñigo Martínez", "Mikel Merino", "Fernando Torres",
	"Xavi Hernández", "Raúl García", "Gerard Moreno", "Marcos Alonso", "Unai Núñez", "Borja Iglesias",
	"Rubén Castro", "Sergio García", "Víctor Muñoz", "Lorenzo Pellegrini", "Gianluca Mancini", "Francesco Caputo",
	"Andrea Conti", "Marco Rossi", "Paolo Rossi", "Federico Gatti", "Ciro Ferrara", "Thomas Meunier",
	"Timo Werner", "Julian Brandt", "Jonas Hofmann", "Robin Koch", "Pascal Gross", "Kevin Vogt", "Philipp Hofmann",
	"Conor Gallagher", "Shane Duffy", "Ryan Fraser", "Lewis Ferguson", "Ross Stewart", "Emil Forsberg",
	"Ante Budimir", "Dusan Tadic", "Nemanja Matic", "Filip Kostic", "Stefan Savic", "Nikola Milenkovic",
	"Marko Grujic", "Lazar Markovic", "Hiroki Sakai", "Hiroki Ito", "Yuma Suzuki", "Jakub Kaminski",
	"Sebastian Szymanski", "Damian Szymanski", "Marcin Wasilewski", "Kacper Kozlowski", "Michal Kadlec",
	"Burak Yilmaz", "Umut Bulut", "Idrissa Gueye", "Pape Sarr", "Pape Gueye", "Abdou Diallo", "Lamine Camara",
	"Ibrahima Konaté", "Youssouf Fofana", "Moussa Diaby", "Moussa Sissoko", "Adama Traoré", "Seydou Keita",
	"Julián Álvarez", "Nahuel Molina", "Cristian Romero", "Facundo Medina", "Exequiel Palacios", "Joaquín Correa",
	"Emiliano Martínez", "Lisandro Martínez", "Raúl Jiménez", "Héctor Herrera", "Edson Álvarez", "Jorge Sánchez",
	"Tyler Adams", "Jordan Morris", "Kyle Walker", "Ben White", "Callum Wilson", "Ben Johnson", "Lewis Hall", "Ryan Mason",
	"Josh King", "Ashley Young", "Scott Parker", "Jack Robinson", "Liam Cooper", "Charlie Taylor", "Ben Gibson",
	"Jack Harrison", "Kieran Gibbs", "Ashley Barnes", "Callum Robinson", "Harry Wilson", "Jack Clarke", "Joe Hart",
	"Danny Ward", "Tom Davies", "Dean Smith", "Mark Noble", "Lewis Cook", "Jamie Ward", "Tom Heaton", "Joe Allen", "Denys Boyko", "Gunnar Jónsson", "Mats Møller", "Kevin Kampl", "Tim Klein"]

static var _p := {} # parsed pools: country -> {"f": Array, "s": Array, "alt": [country, share]}
static var _ban := {}
static var _world := {} # club index -> its 18 names (the computer squads)
static var _nat := {} # a name -> its country, for every name the world made
static var _all := {} # every full name in the world squads
static var _sur := {} # surname -> how often the world uses it
static var _n_world := 0
static var _building := false

static func _split(s: String) -> Array:
	var out := []
	for w in s.split(" ", false):
		out.append(w.replace("_", " "))
	return out

static func _pool(c: String) -> Dictionary:
	if _p.is_empty():
		for k in BAN:
			_ban[k] = true
		for k in POOLS:
			var src: Dictionary = POOLS[k]
			var sur := {}
			for w in _split(str(src.get("s", ""))):
				sur[w] = true
			# more surnames from roots and endings (Lind + gaard)
			var rs := _split(str(src.get("r", "")))
			var xs := _split(str(src.get("x", "")))
			var half := bool(src.get("half", false))
			for r in rs:
				for x in xs:
					var rl: String = r.to_lower()
					if rl.contains(x) or rl.right(2) == x.left(2):
						continue # Wood + wood, Rush + shaw
					var w: String = r + x
					if r.right(1) == x.left(1):
						w = r + x.substr(1) # Wint + ton = Winton, not Wintton
					if half and absi(w.hash()) % 2 == 0:
						continue # keep the real surnames a big share of the country
					if w.length() >= 5 and w.length() <= 12:
						sur[w] = true
			# the Dutch way: van + a place
			for pre in str(src.get("pre", "")).split(" ", false):
				for pl in _split(str(src.get("pr", ""))):
					sur[pre.replace("_", " ") + pl] = true
			var fs := _split(str(src.get("f", "")))
			_p[k] = {"f": fs, "s": sur.keys(), "alt": src.get("alt", [])}
	var c2 := c.to_upper()
	if not _p.has(c2):
		c2 = "ENGLAND"
	var pd: Dictionary = _p[c2]
	if (pd["f"] as Array).is_empty() and not (pd["alt"] as Array).is_empty():
		return _pool(str(pd["alt"][0]))
	return pd

# the country a man of this club is from: mostly the club's own, sometimes from abroad
static func roll_nat(home: String, foreign: float, rng: RandomNumberGenerator) -> String:
	var h := home.to_upper()
	if not POOLS.has(h):
		h = "ENGLAND"
	if rng.randf() >= foreign:
		return h
	var w := ABROAD.duplicate()
	var ln: Dictionary = LEAN.get(h, {})
	for k in ln:
		w[k] = int(w.get(k, 0)) + int(ln[k])
	w.erase(h)
	var tot := 0
	for k in w:
		tot += int(w[k])
	var r := rng.randi_range(1, maxi(tot, 1))
	for k in w:
		r -= int(w[k])
		if r <= 0:
			return str(k)
	return h

static func _surname_of(full: String) -> String:
	var i := full.find(" ")
	return full.substr(i + 1) if i >= 0 else full

# A new made-up full name for a man from this country. `taken` (name -> true) and `squad` (surname -> true)
# are what it must not repeat; the least-used of a few surnames wins, so the world spreads them out.
# With spread false the name depends only on the dice (the same on every phone).
static func make(ctry: String, rng: RandomNumberGenerator, taken: Dictionary, squad := {}, spread := true) -> String:
	if not _building:
		_build()
	var pd := _pool(ctry)
	var alt: Array = pd["alt"]
	if not alt.is_empty() and rng.randf() < float(alt[1]):
		pd = _pool(str(alt[0]))
	var fs: Array = pd["f"]
	var ss: Array = pd["s"]
	var best := ""
	for tries in 40:
		var sn := ""
		var use := 1 << 30
		for k in 4:
			var s2: String = ss[rng.randi() % ss.size()]
			if squad.has(s2):
				continue
			var u := int(_sur.get(s2, 0)) if spread else 0
			if u < use:
				use = u
				sn = s2
		if sn == "":
			continue
		var fn: String = fs[rng.randi() % fs.size()]
		if fn.length() + sn.length() > 19:
			fn = fs[rng.randi() % fs.size()]
		var full := fn + " " + sn
		if _ban.has(full) or taken.has(full) or _all.has(full):
			continue
		best = full
		break
	if best == "":
		# a crowded country: any free combination will do
		for tries in 400:
			var full2: String = str(fs[rng.randi() % fs.size()]) + " " + str(ss[rng.randi() % ss.size()])
			if not taken.has(full2) and not _all.has(full2) and not _ban.has(full2):
				best = full2
				break
	if best == "":
		best = "%s %s" % [str(fs[0]), str(ss[rng.randi() % ss.size()])]
	if spread:
		var s3 := _surname_of(best)
		_sur[s3] = int(_sur.get(s3, 0)) + 1
	if not _nat.has(best):
		_nat[best] = ctry.to_upper()
	return best

# a first name from this country for a man who only has a surname (old saves)
static func first_for(ctry: String, rng: RandomNumberGenerator) -> String:
	var fs: Array = _pool(ctry)["f"]
	return str(fs[rng.randi() % fs.size()])

# how many of a club's men come from abroad
static func foreign_share(club: Dictionary) -> float:
	var c := str(club.get("c", ""))
	var li := int(club.get("lg", -1))
	var t := 1
	if li >= 0 and li < ClubDB.LEAGUES.size():
		t = int(ClubDB.LEAGUES[li]["t"])
	if c == "ENGLAND":
		return [0.5, 0.3, 0.2, 0.12][clampi(t - 1, 0, 3)]
	if c == "":
		return 0.3
	return 0.32 if t == 1 else 0.15

# Every club in the world gets its men's names once, in a fixed order, so every phone (and both players online)
# sees the same names, and no full name turns up twice.
static func _build() -> void:
	if not _world.is_empty() or _building:
		return
	_building = true
	var W: Array = ClubDB.clubs([{}, {}, {}, {}, {}, {}, {}, {}])
	_n_world = W.size()
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261122
	for ci in W.size():
		var cl: Dictionary = W[ci]
		var home := str(cl.get("c", "ENGLAND" if ci % 2 == 0 else "DENMARK"))
		if home == "":
			home = "ENGLAND"
		var fs := foreign_share(cl)
		var squad := {}
		var out := []
		for i in 18:
			var nt := roll_nat(home, fs, rng)
			var nm := make(nt, rng, {}, squad)
			squad[_surname_of(nm)] = true
			_all[nm] = true
			_nat[nm] = nt
			out.append(nm)
		_world[ci] = out
	_building = false

# the 18 names of a club (by world index)
static func club(ci: int) -> Array:
	_build()
	if _world.has(ci):
		return _world[ci]
	# a club beyond the list: still its own names, made from its index
	var rng := RandomNumberGenerator.new()
	rng.seed = ci * 7919 + 13
	var out := []
	var squad := {}
	for i in 18:
		var nm := make(roll_nat("ENGLAND", 0.3, rng), rng, {}, squad, false)
		squad[_surname_of(nm)] = true
		out.append(nm)
	_world[ci] = out
	return out

# the country a world name belongs to ("" when the name was made somewhere else)
static func nat_of(nm: String) -> String:
	_build()
	return str(_nat.get(nm, ""))

# is this name used by a computer squad in the world?
static func in_world(nm: String) -> bool:
	_build()
	return _all.has(nm)

static func surname(full: String) -> String:
	return _surname_of(full)
