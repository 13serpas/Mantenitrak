import 'vehicle.dart';

/// Sugerencias de marca, modelo y motorización para el asistente.
/// Son solo ayudas para escribir: el usuario puede poner cualquier valor.
///
/// Cubre el mercado español actual (gamas 2025-2026, incluidas las marcas
/// chinas llegadas en los últimos años) y los modelos de unos 20 años atrás
/// que siguen circulando y se venden de segunda mano. Las marcas que ya no
/// se venden en España (Chevrolet, Saab, Rover…) se mantienen por eso.
/// Revisado en noviembre de 2026; ver docs/CATALOGO_VEHICULOS.md.
abstract final class VehicleCatalog {
  // ── Turismos y todoterrenos ──────────────────────────────────
  static const _cars = {
    'Abarth': ['500', '595', '695', '500e', '600e'],
    'Alfa Romeo': ['MiTo', '147', '156', '159', 'Giulietta', 'Brera', 'Giulia', 'Stelvio', 'Tonale', 'Junior'],
    'Alpine': ['A110', 'A290', 'A390'],
    'Audi': ['A1', 'A2', 'A3', 'A4', 'A4 Allroad', 'A5', 'A6', 'A6 Allroad', 'A7', 'A8', 'Q2', 'Q3', 'Q4 e-tron', 'Q5', 'Q6 e-tron', 'Q7', 'Q8', 'Q8 e-tron', 'A6 e-tron', 'e-tron', 'e-tron GT', 'TT', 'R8'],
    'BMW': ['Serie 1', 'Serie 2', 'Serie 2 Active Tourer', 'Serie 2 Gran Coupé', 'Serie 3', 'Serie 4', 'Serie 5', 'Serie 6', 'Serie 7', 'Serie 8', 'X1', 'X2', 'X3', 'X4', 'X5', 'X6', 'X7', 'XM', 'Z4', 'i3', 'i4', 'i5', 'i7', 'iX', 'iX1', 'iX2', 'iX3'],
    'BYD': ['Dolphin Surf', 'Dolphin', 'Dolphin G DM-i', 'Atto 2', 'Atto 2 DM-i', 'Atto 3', 'Atto 3 EVO', 'Seal', 'Seal 6 DM-i', 'Seal 6 DM-i Touring', 'Seal U', 'Seal U DM-i', 'Sealion 5', 'Sealion 7', 'Tang', 'Han'],
    'Chevrolet': ['Matiz', 'Spark', 'Kalos', 'Aveo', 'Lacetti', 'Cruze', 'Epica', 'Orlando', 'Trax', 'Captiva'],
    'Chrysler': ['PT Cruiser', '300C', 'Voyager', 'Grand Voyager'],
    'Citroën': ['Saxo', 'C1', 'C2', 'C3', 'ë-C3', 'C3 Picasso', 'C3 Aircross', 'C4', 'ë-C4', 'C4 X', 'C4 Cactus', 'C4 Picasso', 'Grand C4 Picasso', 'C4 SpaceTourer', 'C5', 'C5 X', 'C5 Aircross', 'C-Elysée', 'C-Zero', 'C8', 'Xsara', 'Xsara Picasso', 'Berlingo', 'SpaceTourer', 'Ami'],
    'Cupra': ['Raval', 'Born', 'Leon', 'Formentor', 'Ateca', 'Terramar', 'Tavascan'],
    'Dacia': ['Logan', 'Logan MCV', 'Sandero', 'Sandero Stepway', 'Duster', 'Bigster', 'Lodgy', 'Dokker', 'Jogger', 'Spring'],
    'Daewoo': ['Matiz', 'Kalos', 'Lanos', 'Nubira', 'Lacetti'],
    'Daihatsu': ['Cuore', 'Sirion', 'Terios'],
    'Deepal': ['S05', 'S07'],
    'DFSK': ['Seres 3', 'Fengon 500', 'Fengon 580'],
    'Dodge': ['Caliber', 'Journey', 'Nitro'],
    'Dongfeng': ['Box', 'Mage', 'Vigo'],
    'DS': ['DS 3', 'DS 3 Crossback', 'DS 4', 'DS 5', 'DS 7', 'DS 9', 'Nº4', 'Nº7', 'Nº8'],
    'Ebro': ['s400', 's700', 's800', 's900'],
    'Fiat': ['Panda', 'Grande Panda', '500', '500e', '500C', '500L', '500X', '600', 'Punto', 'Grande Punto', 'Bravo', 'Stilo', 'Tipo', 'Croma', 'Sedici', 'Qubo', 'Doblò', 'Freemont', '124 Spider'],
    'Ford': ['Ka', 'Ka+', 'Fiesta', 'Fusion', 'B-Max', 'C-Max', 'Grand C-Max', 'Focus', 'Mondeo', 'S-Max', 'Galaxy', 'EcoSport', 'Puma', 'Puma Gen-E', 'Kuga', 'Edge', 'Explorer', 'Capri', 'Mustang', 'Mustang Mach-E', 'Ranger', 'Tourneo Courier', 'Tourneo Connect', 'Tourneo Custom'],
    'Geely': ['EX5', 'Starray', 'E2'],
    'GWM': ['Haval H6', 'Haval H7', 'Haval Jolion', 'Ora 03', 'Wey 05'],
    'Honda': ['Jazz', 'Civic', 'Accord', 'Insight', 'CR-Z', 'FR-V', 'HR-V', 'ZR-V', 'CR-V', 'e', 'e:Ny1', 'Prelude'],
    'Hongqi': ['HS3', 'HS5', 'H9', 'E-HS9', 'EH7'],
    'Hyundai': ['Atos', 'Getz', 'i10', 'i20', 'i30', 'i40', 'ix20', 'ix35', 'Accent', 'Elantra', 'Bayon', 'Kona', 'Tucson', 'Santa Fe', 'Inster', 'Ioniq', 'Ioniq 5', 'Ioniq 6', 'Ioniq 9', 'Nexo', 'Staria'],
    'Infiniti': ['Q30', 'Q50', 'QX30', 'QX70', 'FX'],
    'Jaecoo': ['5', '7', '8'],
    'Jaguar': ['X-Type', 'XE', 'XF', 'XJ', 'F-Type', 'E-Pace', 'F-Pace', 'I-Pace'],
    'Jeep': ['Avenger', 'Renegade', 'Compass', 'Patriot', 'Cherokee', 'Grand Cherokee', 'Wrangler', 'Gladiator'],
    'KGM (SsangYong)': ['Tivoli', 'Korando', 'Torres', 'Actyon', 'Rexton', 'Musso', 'Kyron', 'Rodius'],
    'Kia': ['Picanto', 'Rio', 'Stonic', 'Ceed', 'ProCeed', 'XCeed', 'Venga', 'Soul', 'Carens', 'Niro', 'Sportage', 'Sorento', 'Optima', 'Stinger', 'EV2', 'EV3', 'EV4', 'EV5', 'EV6', 'EV9'],
    'Lada': ['Niva'],
    'Lancia': ['Ypsilon', 'Musa', 'Delta', 'Lybra', 'Thema'],
    'Land Rover': ['Defender', 'Discovery', 'Discovery Sport', 'Freelander', 'Range Rover', 'Range Rover Sport', 'Range Rover Evoque', 'Range Rover Velar'],
    'Leapmotor': ['T03', 'B03X', 'B05', 'B10', 'C10'],
    'Lepas': ['L4', 'L6', 'L8'],
    'Lexus': ['CT', 'IS', 'ES', 'GS', 'LS', 'LBX', 'UX', 'NX', 'RX', 'RZ', 'LC'],
    'Lynk & Co': ['01', '02', '08'],
    'Mazda': ['2', '3', '5', '6', '6e', 'CX-3', 'CX-30', 'CX-5', 'CX-6e', 'CX-60', 'CX-7', 'CX-80', 'MX-30', 'MX-5'],
    'Mercedes-Benz': ['Clase A', 'Clase B', 'Clase C', 'Clase E', 'Clase S', 'Clase G', 'Clase M', 'Clase R', 'Clase T', 'Clase V', 'CLA', 'CLK', 'CLS', 'SLK', 'SLC', 'SL', 'GLA', 'GLB', 'GLC', 'GLE', 'GLK', 'GLS', 'EQA', 'EQB', 'EQC', 'EQE', 'EQS'],
    'MG': ['MG3', 'MG4', 'MG4 Urban', 'MG5', 'ZS', 'ZS EV', 'HS', 'Marvel R', 'MGS5', 'MGS6', 'MGS9', 'IM5', 'Cyberster'],
    'Mini': ['3 puertas', '5 puertas', 'Cabrio', 'Clubman', 'Countryman', 'Paceman', 'Aceman', 'Cooper E'],
    'Mitsubishi': ['Colt', 'Space Star', 'ASX', 'Eclipse Cross', 'Outlander', 'Montero', 'L200', 'i-MiEV'],
    'Nissan': ['Micra', 'Note', 'Almera', 'Primera', 'Pulsar', 'Juke', 'Qashqai', 'X-Trail', 'Murano', 'Pathfinder', 'Navara', 'Ariya', 'Leaf', 'Townstar', '350Z', '370Z'],
    'Omoda': ['4', '5', 'E5', '7', '9'],
    'Opel': ['Agila', 'Adam', 'Karl', 'Corsa', 'Meriva', 'Astra', 'Zafira', 'Zafira Life', 'Vectra', 'Insignia', 'Mokka', 'Crossland', 'Grandland', 'Frontera', 'Antara', 'Combo Life', 'Ampera'],
    'Peugeot': ['107', '108', '206', '207', '208', '307', '308', '407', '408', '508', '607', '1007', '2008', '3008', '4007', '5008', '807', 'Partner Tepee', 'Rifter', 'Traveller'],
    'Polestar': ['2', '3', '4'],
    'Porsche': ['911', 'Boxster', 'Cayman', '718', 'Macan', 'Cayenne', 'Panamera', 'Taycan'],
    'Renault': ['Twingo', 'Clio', 'Modus', 'Megane', 'Megane E-Tech', 'Scenic', 'Grand Scenic', 'Scenic E-Tech', 'Laguna', 'Fluence', 'Latitude', 'Captur', 'Kadjar', 'Arkana', 'Austral', 'Symbioz', 'Rafale', 'Koleos', 'Espace', 'Kangoo', 'Zoe', '4 E-Tech', '5 E-Tech', 'Twizy'],
    'Rover': ['25', '45', '75'],
    'Saab': ['9-3', '9-5'],
    'Seat': ['Arosa', 'Mii', 'Ibiza', 'Córdoba', 'Leon', 'Toledo', 'Altea', 'Altea XL', 'Exeo', 'Alhambra', 'Arona', 'Ateca', 'Tarraco'],
    'Skoda': ['Citigo', 'Fabia', 'Rapid', 'Scala', 'Roomster', 'Octavia', 'Superb', 'Yeti', 'Kamiq', 'Karoq', 'Kodiaq', 'Enyaq', 'Elroq', 'Epiq', 'Peaq'],
    'Smart': ['fortwo', 'forfour', '#1', '#3', '#5'],
    'Subaru': ['Impreza', 'XV', 'Crosstrek', 'Forester', 'Outback', 'Legacy', 'BRZ', 'Solterra'],
    'Suzuki': ['Alto', 'Celerio', 'Ignis', 'Swift', 'Baleno', 'SX4', 'S-Cross', 'Vitara', 'Grand Vitara', 'e Vitara', 'Jimny', 'Swace', 'Across'],
    'Tesla': ['Model 3', 'Model Y', 'Model S', 'Model X'],
    'Toyota': ['Aygo', 'Aygo X', 'Yaris', 'Yaris Cross', 'Urban Cruiser', 'Auris', 'Corolla', 'Corolla Cross', 'Avensis', 'Verso', 'Prius', 'Prius+', 'C-HR', 'C-HR+', 'RAV4', 'Land Cruiser', 'Hilux', 'GT86', 'GR86', 'GR Yaris', 'Supra', 'Camry', 'Mirai', 'bZ4X', 'Proace City Verso'],
    'Volkswagen': ['Fox', 'Lupo', 'up!', 'Polo', 'ID. Polo', 'Golf', 'Golf Plus', 'Golf Sportsvan', 'Jetta', 'Bora', 'Beetle', 'Scirocco', 'Eos', 'Passat', 'Passat CC', 'Arteon', 'Touran', 'Sharan', 'T-Cross', 'Taigo', 'T-Roc', 'Tiguan', 'Tiguan Allspace', 'Tayron', 'Touareg', 'ID.3', 'ID.4', 'ID.5', 'ID.7', 'ID. Cross', 'ID. Buzz', 'Multivan', 'California', 'Amarok'],
    'Volvo': ['C30', 'S40', 'V40', 'V50', 'S60', 'V60', 'V70', 'S80', 'S90', 'V90', 'XC40', 'XC60', 'XC70', 'XC90', 'EX30', 'EX40', 'EC40', 'EX90', 'ES90'],
    'Xpeng': ['G6', 'G9', 'P7', 'X9'],
    'Zeekr': ['001', '7X', 'X'],
  };

  // ── Furgonetas, furgones y pick-ups de trabajo ───────────────
  static const _vans = {
    'Citroën': ['Nemo', 'Berlingo', 'Jumpy', 'Jumper'],
    'Dacia': ['Dokker Van'],
    'Fiat': ['Fiorino', 'Doblò', 'Qubo', 'Scudo', 'Talento', 'Ducato'],
    'Ford': ['Transit Courier', 'Transit Connect', 'Transit Custom', 'Transit', 'E-Transit', 'Ranger'],
    'Hyundai': ['H-1', 'H350', 'Staria'],
    'Isuzu': ['D-Max'],
    'Iveco': ['Daily', 'eDaily'],
    'Kia': ['PV5'],
    'Maxus': ['eDeliver 3', 'eDeliver 7', 'eDeliver 9', 'Deliver 9', 'T90'],
    'Mercedes-Benz': ['Citan', 'Vito', 'eVito', 'Sprinter', 'eSprinter'],
    'Mitsubishi': ['L200'],
    'Nissan': ['NV200', 'Townstar', 'NV300', 'Primastar', 'NV400', 'Interstar', 'Navara'],
    'Opel': ['Combo', 'Vivaro', 'Movano'],
    'Peugeot': ['Bipper', 'Partner', 'Expert', 'Boxer'],
    'Piaggio': ['Porter'],
    'Renault': ['Express', 'Kangoo', 'Trafic', 'Master'],
    'Toyota': ['Proace City', 'Proace', 'Proace Max', 'Hilux'],
    'Volkswagen': ['Caddy', 'Transporter', 'Multivan', 'California', 'Grand California', 'Crafter', 'ID. Buzz', 'Amarok'],
  };

  // ── Motos y scooters ─────────────────────────────────────────
  static const _motos = {
    'Aprilia': ['SR GT 125', 'RS 125', 'RS 457', 'RS 660', 'Tuono 660', 'Tuareg 660', 'Shiver 750', 'Dorsoduro', 'Tuono V4', 'RSV4'],
    'Benelli': ['BN 125', 'Leoncino 500', 'TRK 502', 'TRK 702', '752S'],
    'BMW Motorrad': ['G 310 R', 'G 310 GS', 'F 650 GS', 'F 700 GS', 'F 750 GS', 'F 800 GS', 'F 850 GS', 'F 900 GS', 'F 800 R', 'F 900 R', 'F 900 XR', 'R 1200 GS', 'R 1250 GS', 'R 1300 GS', 'R 1250 RT', 'R nineT', 'S 1000 R', 'S 1000 RR', 'S 1000 XR', 'C 400 X', 'C 400 GT', 'CE 04'],
    'CFMoto': ['300NK', '450NK', '800NK', '450SR', '450MT', '700MT', '800MT', '700CL-X', '450CL-C'],
    'Daelim': ['Daystar', 'S2', 'Otello'],
    'Derbi': ['Senda', 'Terra', 'Mulhacén', 'GPR'],
    'Ducati': ['Monster', 'Monster 821', 'Scrambler', 'Hypermotard', 'SuperSport', 'Multistrada', 'Multistrada V2', 'Multistrada V4', 'Panigale V2', 'Panigale V4', 'Streetfighter V4', 'Diavel', 'DesertX'],
    'Harley-Davidson': ['Sportster 883', 'Iron 883', 'Forty-Eight', 'Sportster S', 'Nightster', 'Street Bob', 'Fat Bob', 'Fat Boy', 'Road King', 'Street Glide', 'Pan America'],
    'Honda': ['Vision 110', 'Wave 110', 'Scoopy SH125', 'SH125', 'SH150', 'SH300', 'SH350', 'PCX125', 'Forza 125', 'Forza 350', 'Forza 750', 'ADV 350', 'X-ADV', 'Integra', 'CB125F', 'CB125R', 'CB300R', 'CB500F', 'CB500 Hornet', 'CB500X', 'NX500', 'CBR500R', 'CB600F Hornet', 'CBF600', 'CB650F', 'CB650R', 'CBR650R', 'CB750 Hornet', 'CBF1000', 'CBR1000RR Fireblade', 'NC700X', 'NC750X', 'XL750 Transalp', 'Varadero', 'Deauville', 'Africa Twin', 'Rebel 500', 'Rebel 1100', 'Gold Wing', 'Monkey', 'MSX125 Grom', 'EM1 e:'],
    'Husqvarna': ['Svartpilen 125', 'Svartpilen 401', 'Vitpilen 401', 'Norden 901'],
    'Kawasaki': ['Z125', 'Z400', 'Z650', 'Z650RS', 'Z750', 'Z800', 'Z900', 'Z900RS', 'Z1000', 'ER-6n', 'Ninja 400', 'Ninja 500', 'Ninja 650', 'Ninja ZX-6R', 'Ninja ZX-10R', 'Versys-X 300', 'Versys 650', 'Versys 1000', 'Vulcan S', 'Eliminator'],
    'Kove': ['450 Rally', '800X'],
    'KTM': ['Duke 125', 'Duke 390', 'Duke 690', 'Duke 790', 'Duke 890', '1290 Super Duke R', 'RC 125', 'RC 390', '390 Adventure', '790 Adventure', '890 Adventure', '1290 Super Adventure', 'EXC 300'],
    'Kymco': ['Agility 125', 'Agility City', 'People S', 'People GT', 'Super Dink', 'Grand Dink', 'X-Town', 'Xciting', 'DT X360', 'AK 550'],
    'Macbor': ['Montana XR1', 'Montana XR3', 'Montana XR5', 'Eight Mile', 'Rockster'],
    'Moto Guzzi': ['V7', 'V85 TT', 'V100 Mandello', 'Stelvio'],
    'MV Agusta': ['Brutale', 'Dragster', 'F3', 'Turismo Veloce'],
    'Piaggio': ['Zip', 'Fly', 'Liberty', 'Medley', 'Beverly', 'X7', 'X10', 'MP3'],
    'QJMotor': ['SRK 600', 'SRK 700', 'SRK 800', 'SRT 550', 'SRT 800', 'SRV 550'],
    'Rieju': ['Tango', 'MRT', 'Marathon', 'Century'],
    'Royal Enfield': ['Bullet 350', 'Classic 350', 'Meteor 350', 'Hunter 350', 'Scram 411', 'Himalayan', 'Himalayan 450', 'Guerrilla 450', 'Interceptor 650', 'Continental GT 650', 'Super Meteor 650', 'Shotgun 650'],
    'Silence': ['S01', 'S02'],
    'Suzuki': ['Address', 'Burgman 125', 'Burgman 200', 'Burgman 400', 'Burgman 650', 'GSX-S125', 'GSX-R125', 'GS500', 'Gladius', 'SV650', 'Bandit 650', 'Bandit 1250', 'GSX-S750', 'GSX-8S', 'GSX-8R', 'GSX-S1000', 'GSX-S1000GT', 'Katana', 'GSX-R600', 'GSX-R750', 'GSX-R1000', 'Hayabusa', 'V-Strom 250 SX', 'V-Strom 650', 'V-Strom 800DE', 'V-Strom 1050'],
    'SYM': ['Symphony 125', 'Symphony ST', 'Fiddle', 'Orbit', 'Jet 14', 'ADX 125', 'Joymax Z', 'Cruisym', 'Maxsym TL', 'ADXTG 400'],
    'Triumph': ['Speed 400', 'Scrambler 400 X', 'Trident 660', 'Tiger 660 Sport', 'Daytona 660', 'Street Triple', 'Speed Triple', 'Street Twin', 'Speed Twin', 'Bonneville T100', 'Bonneville T120', 'Tiger 800', 'Tiger 900', 'Tiger 1200', 'Rocket 3'],
    'Vespa': ['Primavera', 'Sprint', 'LX', 'GTS 125', 'GTS 300', 'GTV', 'Elettrica'],
    'Voge': ['SR1 ADV 125', 'SR4 Max', '300 AC', '300 Rally', '525 ACX', '525 DSX', '625 DSX', '900 DSX'],
    'Yamaha': ["D'elight", "Neo's", 'X-City', 'Majesty', 'Tricity 125', 'Tricity 300', 'NMAX 125', 'NMAX 155', 'XMAX 125', 'XMAX 300', 'XMAX 400', 'TMAX', 'MT-125', 'YZF-R125', 'XSR125', 'MT-03', 'YZF-R3', 'FZ6 Fazer', 'XJ6', 'MT-07', 'XSR700', 'Tracer 7', 'YZF-R7', 'YZF-R6', 'MT-09', 'XSR900', 'Tracer 9', 'Niken', 'FZ1', 'MT-10', 'YZF-R1', 'Ténéré 700', 'Super Ténéré'],
    'Zontes': ['125X', '125V', '350D', '350E', '350T', '368G', '703F'],
  };

  static const _quads = {
    'Can-Am': ['Outlander', 'Renegade', 'DS 450'],
    'CFMoto': ['CForce 450', 'CForce 520', 'CForce 625', 'CForce 850', 'CForce 1000'],
    'Honda': ['TRX420 Rancher', 'TRX520 Foreman', 'TRX680 Rincon'],
    'Kymco': ['MXU 300', 'MXU 550', 'MXU 700'],
    'Linhai': ['LH 300', 'LH 500', 'LH 600'],
    'Polaris': ['Sportsman 450', 'Sportsman 570', 'Sportsman 1000', 'Scrambler'],
    'Suzuki': ['KingQuad'],
    'TGB': ['Blade'],
    'Yamaha': ['Grizzly', 'Kodiak', 'Raptor 700', 'YFZ450R'],
  };

  static const _trucks = {
    'DAF': ['LF', 'CF', 'XF', 'XF 105', 'XG', 'XG+', 'XB'],
    'Isuzu': ['Serie N', 'Serie F'],
    'Iveco': ['Eurocargo', 'Stralis', 'Trakker', 'S-Way', 'X-Way', 'T-Way'],
    'MAN': ['TGL', 'TGM', 'TGS', 'TGX', 'TGA'],
    'Mercedes-Benz': ['Atego', 'Axor', 'Antos', 'Actros', 'Arocs', 'Econic', 'eActros'],
    'Mitsubishi Fuso': ['Canter', 'eCanter'],
    'Renault Trucks': ['Midlum', 'Premium', 'Magnum', 'Kerax', 'D', 'C', 'K', 'T', 'T High', 'E-Tech T'],
    'Scania': ['Serie P', 'Serie G', 'Serie R', 'Serie S', 'Serie L', 'XT'],
    'Volvo': ['FL', 'FE', 'FM', 'FMX', 'FH', 'FH16', 'FH Aero'],
  };

  static const _buses = {
    'BYD': ['eBus 12', 'eBus 18'],
    'Castrosua': ['New City', 'Magnus'],
    'Irizar': ['i3', 'i4', 'i6', 'i6S', 'i8', 'ie bus', 'ie tram'],
    'Isuzu': ['Novo', 'Citibus'],
    'Iveco Bus': ['Crossway', 'Urbanway', 'Streetway', 'Evadys', 'Magelys'],
    'MAN': ["Lion's City", "Lion's Intercity", "Lion's Coach"],
    'Mercedes-Benz': ['Citaro', 'eCitaro', 'Intouro', 'Tourismo', 'Sprinter City'],
    'Neoplan': ['Tourliner', 'Cityliner', 'Skyliner'],
    'Scania': ['Citywide', 'Interlink', 'Touring'],
    'Setra': ['ComfortClass', 'TopClass', 'MultiClass'],
    'Solaris': ['Urbino', 'Urbino electric', 'InterUrbino'],
    'Sunsundegui': ['SC5', 'SC7', 'Sideral'],
    'Temsa': ['Safari', 'HD 12', 'LD'],
    'Van Hool': ['TX', 'EX', 'A330'],
    'Volvo': ['7900', '8900', '9700', '9900'],
  };

  // ── Autocaravanas, campers y caravanas ───────────────────────
  static const _caravans = {
    'Adria': ['Coral', 'Matrix', 'Compact', 'Sonic', 'Twin', 'Altea', 'Adora'],
    'Benimar': ['Tessoro', 'Mileo', 'Sport', 'Benivan'],
    'Bürstner': ['Lyseo', 'Travel Van', 'Campeo'],
    'Carado': ['T135', 'T338', 'V600'],
    'Carthago': ['C-Tourer', 'Chic'],
    'Challenger': <String>[],
    'Chausson': <String>[],
    'Dethleffs': ['Trend', 'Just', 'Pulse', 'Globebus', 'Globetrotter'],
    'Elnagh': <String>[],
    'Globecar': <String>[],
    'Hymer': ['B-Klasse', 'Exsis', 'ML-T', 'Grand Canyon S', 'Free'],
    'Joa Camp': <String>[],
    'Knaus': ['BoxStar', 'Van TI', 'Sky TI', 'Live Wave', 'Sport'],
    'McLouis': ['Menfys', 'Fusion'],
    'Pilote': <String>[],
    'Pössl': <String>[],
    'Rapido': <String>[],
    'Roller Team': <String>[],
    'Sun Living': <String>[],
    'Weinsberg': ['CaraCompact', 'CaraBus', 'CaraTour', 'CaraSuite', 'CaraOne'],
    'Westfalia': <String>[],
  };

  // ── Embarcaciones y motos de agua ────────────────────────────
  static const _boats = {
    'Astondoa': <String>[],
    'Bavaria': ['Cruiser', 'C', 'SR', 'Vida'],
    'Bayliner': ['VR5', 'VR6', 'Element', 'Trophy'],
    'Beneteau': ['Antares', 'Flyer', 'Gran Turismo', 'Swift Trawler', 'Oceanis', 'First'],
    'Brig': ['Eagle', 'Navigator', 'Falcon'],
    'Capelli': ['Tempest'],
    'Fountaine Pajot': <String>[],
    'Jeanneau': ['Cap Camarat', 'Merry Fisher', 'Leader', 'Sun Odyssey'],
    'Kawasaki': ['Jet Ski STX 160', 'Jet Ski Ultra 310'],
    'Lagoon': ['40', '42', '46'],
    'Pacific Craft': <String>[],
    'Quicksilver': ['Activ 455', 'Activ 505', 'Activ 555', 'Activ 605', 'Activ 675', 'Activ 755', 'Activ 805', 'Activ 875'],
    'Ranieri': <String>[],
    'Rodman': <String>[],
    'Saver': <String>[],
    'Sea Ray': ['SPX', 'SDX', 'Sundancer'],
    'Sea-Doo': ['Spark', 'GTI', 'GTX', 'RXT', 'Wake'],
    'Sessa': <String>[],
    'Yamaha': ['WaveRunner EX', 'WaveRunner VX', 'WaveRunner FX', 'WaveRunner GP'],
    'Zodiac': ['Cadet', 'Medline', 'Pro Open'],
  };

  /// Motores fueraborda e intraborda habituales (barcos sin catálogo propio).
  static const _boatEngines = [
    'Mercury 40 CV', 'Mercury 60 CV', 'Mercury 115 CV', 'Mercury 150 CV', 'Mercury 200 CV',
    'Yamaha F40', 'Yamaha F70', 'Yamaha F115', 'Yamaha F150', 'Yamaha F200',
    'Suzuki DF40', 'Suzuki DF70', 'Suzuki DF115', 'Suzuki DF140',
    'Honda BF40', 'Honda BF100', 'Tohatsu MFS 50', 'Volvo Penta D2', 'Volvo Penta D4', 'Yanmar 3YM30',
  ];

  /// Motorizaciones frecuentes de los modelos más vendidos, por "Marca|Modelo".
  static const _engines = {
    'Audi|A3': ['30 TFSI 110 CV', '35 TFSI 150 CV', '30 TDI 116 CV', '35 TDI 150 CV', '40 TFSI e 204 CV', 'S3 310 CV'],
    'BMW|Serie 1': ['116i', '118i', '120i', '116d', '118d', '120d', 'M135'],
    'BMW|Serie 3': ['318i', '320i', '330i', '318d', '320d', '330e'],
    'BYD|Atto 2 DM-i': ['DM-i 156 CV', 'DM-i 212 CV'],
    'BYD|Seal U DM-i': ['DM-i 218 CV', 'DM-i AWD 324 CV'],
    'Citroën|C3': ['1.2 PureTech 83 CV', '1.2 PureTech 110 CV', '1.2 Hybrid 100 CV', '1.5 BlueHDi 100 CV'],
    'Citroën|C4': ['1.2 PureTech 130 CV', '1.2 Hybrid 136 CV', '1.5 BlueHDi 130 CV', 'ë-C4 156 CV'],
    'Cupra|Formentor': ['1.5 TSI 150 CV', 'e-Hybrid 204 CV', 'e-Hybrid 272 CV', '2.0 TSI VZ 333 CV'],
    'Dacia|Duster': ['1.0 TCe 100 CV GLP', '1.2 TCe 130 CV', '1.5 dCi 115 CV', 'Hybrid 140 CV'],
    'Dacia|Sandero': ['1.0 SCe 65 CV', '1.0 TCe 90 CV', '1.0 ECO-G 100 CV GLP', 'Hybrid 155 CV'],
    'Fiat|500': ['1.2 69 CV', '1.0 Hybrid 70 CV', '500e 95 CV', '500e 118 CV'],
    'Ford|Focus': ['1.0 EcoBoost 125 CV', '1.0 EcoBoost mHEV 155 CV', '1.5 EcoBlue 120 CV', '1.6 TDCi 115 CV'],
    'Ford|Puma': ['1.0 EcoBoost mHEV 125 CV', '1.0 EcoBoost mHEV 155 CV', 'ST 200 CV'],
    'Hyundai|i10': ['1.0 MPI 67 CV', '1.2 MPI 79 CV'],
    'Hyundai|Kona': ['1.0 T-GDi 120 CV', '1.6 HEV 141 CV', 'Eléctrico 156 CV', 'Eléctrico 218 CV'],
    'Hyundai|Tucson': ['1.6 T-GDi 150 CV', '1.6 T-GDi HEV 230 CV', '1.6 T-GDi PHEV 265 CV', '1.6 CRDi 136 CV'],
    'Kia|Niro': ['1.6 HEV 141 CV', '1.6 PHEV 183 CV', 'Eléctrico 204 CV'],
    'Kia|Sportage': ['1.6 T-GDi 150 CV', '1.6 T-GDi HEV 230 CV', '1.6 T-GDi PHEV 265 CV', '1.6 CRDi 136 CV'],
    'Mercedes-Benz|Clase A': ['A 180', 'A 200', 'A 250 e', 'A 180 d', 'A 200 d'],
    'MG|HS': ['1.5 T-GDi 170 CV', 'Hybrid+ 224 CV', 'PHEV 272 CV'],
    'MG|MG3': ['1.5 VTi 106 CV', 'Hybrid+ 194 CV'],
    'MG|ZS': ['1.5 VTi-tech 106 CV', 'Hybrid+ 196 CV'],
    'Nissan|Qashqai': ['1.3 DIG-T 140 CV', '1.3 DIG-T 158 CV', '1.5 e-Power 190 CV', '1.5 dCi 115 CV'],
    'Opel|Corsa': ['1.2 75 CV', '1.2 Turbo 100 CV', '1.2 Hybrid 100 CV', '1.5 Diésel 100 CV', 'Electric 136 CV'],
    'Peugeot|208': ['1.2 PureTech 75 CV', '1.2 PureTech 100 CV', '1.2 Hybrid 100 CV', '1.5 BlueHDi 100 CV', 'e-208 136 CV', 'e-208 156 CV'],
    'Peugeot|2008': ['1.2 PureTech 100 CV', '1.2 PureTech 130 CV', '1.2 Hybrid 136 CV', '1.5 BlueHDi 110 CV', 'e-2008 156 CV'],
    'Peugeot|308': ['1.2 PureTech 130 CV', '1.2 Hybrid 136 CV', '1.5 BlueHDi 130 CV', 'Hybrid 180 CV PHEV'],
    'Renault|Captur': ['1.0 TCe 90 CV', '1.0 TCe 100 CV GLP', '1.3 TCe 140 CV', 'E-Tech 145 CV', '1.5 dCi 115 CV'],
    'Renault|Clio': ['1.0 TCe 90 CV', '1.0 TCe 100 CV GLP', '1.3 TCe 140 CV', 'E-Tech 145 CV', '1.5 dCi 100 CV'],
    'Renault|Megane': ['1.3 TCe 140 CV', '1.5 dCi 115 CV', 'E-Tech 160 CV PHEV'],
    'Seat|Arona': ['1.0 TSI 95 CV', '1.0 TSI 115 CV', '1.5 TSI 150 CV', '1.0 TGI 90 CV GNC'],
    'Seat|Ateca': ['1.0 TSI 110 CV', '1.5 TSI 150 CV', '2.0 TDI 115 CV', '2.0 TDI 150 CV'],
    'Seat|Ibiza': ['1.0 MPI 80 CV', '1.0 TSI 95 CV', '1.0 TSI 115 CV', '1.5 TSI 150 CV', '1.0 TGI 90 CV GNC'],
    'Seat|Leon': ['1.0 TSI 110 CV', '1.5 TSI 150 CV', '1.5 eTSI 150 CV', '2.0 TDI 115 CV', '2.0 TDI 150 CV', 'e-Hybrid 204 CV'],
    'Skoda|Octavia': ['1.0 TSI 110 CV', '1.5 TSI 150 CV', '2.0 TDI 115 CV', '2.0 TDI 150 CV', 'RS 265 CV'],
    'Tesla|Model 3': ['Propulsión trasera', 'Gran Autonomía', 'Performance'],
    'Tesla|Model Y': ['Propulsión trasera', 'Gran Autonomía', 'Performance'],
    'Toyota|C-HR': ['1.8 Hybrid 140 CV', '2.0 Hybrid 197 CV', '2.0 PHEV 223 CV'],
    'Toyota|Corolla': ['1.8 Hybrid 140 CV', '2.0 Hybrid 196 CV'],
    'Toyota|RAV4': ['2.5 Hybrid 218 CV', '2.5 Hybrid AWD 222 CV', '2.5 PHEV 306 CV'],
    'Toyota|Yaris': ['1.0 VVT-i 72 CV', '1.5 Hybrid 116 CV', '1.5 Hybrid 130 CV', 'GR 261 CV'],
    'Toyota|Yaris Cross': ['1.5 Hybrid 116 CV', '1.5 Hybrid 130 CV'],
    'Volkswagen|Golf': ['1.0 TSI 110 CV', '1.5 TSI 130 CV', '1.5 TSI 150 CV', '2.0 TDI 115 CV', '2.0 TDI 150 CV', 'eHybrid 204 CV', '2.0 TSI GTI 245 CV'],
    'Volkswagen|Polo': ['1.0 MPI 80 CV', '1.0 TSI 95 CV', '1.0 TSI 110 CV', '2.0 TSI GTI 207 CV'],
    'Volkswagen|T-Roc': ['1.0 TSI 110 CV', '1.5 TSI 150 CV', '2.0 TDI 115 CV', '2.0 TDI 150 CV'],
  };

  static Map<String, List<String>> _for(VehicleType? type) => switch (type) {
        VehicleType.coche || VehicleType.todoterreno => _cars,
        VehicleType.furgoneta => _vans,
        VehicleType.moto => _motos,
        VehicleType.quad => _quads,
        VehicleType.camion => _trucks,
        VehicleType.autobus => _buses,
        VehicleType.caravana => _caravans,
        VehicleType.barco => _boats,
        _ => const {},
      };

  static List<String> brands(VehicleType? type) => _for(type).keys.toList();

  /// No distingue mayúsculas ni acentos: "citroen" encuentra "Citroën" y
  /// "león" encuentra "Leon".
  static List<String> models(VehicleType? type, String brand) {
    final catalog = _for(type);
    final key = catalog.keys.where((b) => normalize(b) == normalize(brand));
    return key.isEmpty ? const [] : catalog[key.first]!;
  }

  /// Motorizaciones del modelo. En barcos, si el modelo no tiene lista
  /// propia, sugiere los motores marinos más habituales.
  static List<String> engines(String brand, String model, {VehicleType? type}) {
    final b = normalize(brand);
    final m = normalize(model);
    for (final entry in _engines.entries) {
      final [eb, em] = entry.key.split('|');
      if (normalize(eb) == b && normalize(em) == m) return entry.value;
    }
    return type == VehicleType.barco ? _boatEngines : const [];
  }

  /// Filtro para autocompletar: contiene el texto, sin distinguir
  /// mayúsculas ni acentos.
  static Iterable<String> filter(List<String> options, String query) {
    final q = normalize(query);
    if (q.isEmpty) return options;
    return options.where((o) => normalize(o).contains(q));
  }

  static const _accents = {
    'á': 'a', 'à': 'a', 'ä': 'a', 'â': 'a',
    'é': 'e', 'è': 'e', 'ë': 'e', 'ê': 'e',
    'í': 'i', 'ì': 'i', 'ï': 'i', 'î': 'i',
    'ó': 'o', 'ò': 'o', 'ö': 'o', 'ô': 'o',
    'ú': 'u', 'ù': 'u', 'ü': 'u', 'û': 'u',
  };

  /// Minúsculas, sin acentos y sin espacios sobrantes.
  static String normalize(String s) {
    final lower = s.trim().toLowerCase();
    final buf = StringBuffer();
    for (final ch in lower.split('')) {
      buf.write(_accents[ch] ?? ch);
    }
    return buf.toString().replaceAll(RegExp(r'\s+'), ' ');
  }
}
