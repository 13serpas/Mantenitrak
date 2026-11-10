# Catálogo de marcas y modelos (revisión de noviembre de 2026)

Archivo: `lib/features/vehicles/domain/vehicle_catalog.dart`. Son sugerencias para autocompletar: el usuario siempre puede escribir otra marca o modelo.

## Qué cubre

| Tipo | Marcas | Modelos | Notas |
|---|---|---|---|
| Coche / 4x4 | 64 | 660 | Gama actual y modelos de los últimos ~20 años que se siguen viendo en el mercado de ocasión. Incluye marcas que ya no se venden (Chevrolet, Saab, Rover, Daewoo, Lancia…). |
| Furgoneta | 18 | 66 | Furgonetas, furgones y pick-ups de trabajo, incluidas eléctricas (ID. Buzz, PV5, eDeliver…). |
| Moto | 29 | 319 | Scooters 125, A2 y gran cilindrada; marcas chinas que ya lideran ventas (Zontes, Voge, QJMotor, CFMoto, Kove) y clásicas españolas (Derbi, Rieju). |
| Quad | 9 | 27 | |
| Camión | 9 | 52 | Incluye gamas anteriores (Stralis, Magnum, TGA, Axor…). |
| Autobús | 15 | 51 | Incluye carroceros españoles (Irizar, Castrosua, Sunsundegui). |
| Autocaravana / camper | 21 | 41 | Marcas sin modelos donde la gama cambia mucho cada año. |
| Barco / moto de agua | 20 | 50 | Si el modelo no tiene motores propios, se sugieren motores marinos habituales. |

Además hay motorizaciones para 45 modelos superventas (Sandero, Clio, ZS, Ibiza, Corolla, Arona, 2008, 208, Qashqai, Yaris Cross, Tucson, Sportage, T-Roc, Golf, Seal U DM-i…).

## Marcas y modelos añadidos destacados

- **Marcas chinas ya asentadas en España:**
  - BYD: Dolphin Surf, Atto 2 y Atto 2 DM-i, Atto 3 EVO, Seal 6 DM-i, Seal U DM-i, Sealion 5 y 7, Tang…
  - MG: MG3, MG4 y MG4 Urban, ZS, HS, MGS5, MGS6, MGS9, Cyberster…
  - Omoda, Jaecoo y Ebro (s400 a s900).
  - Leapmotor: T03, B03X, B05, B10, C10.
  - Lynk & Co, Xpeng, Zeekr, Geely, Deepal, GWM, Hongqi, Lepas, Dongfeng, DFSK.
- **Novedades 2025-2026:** Cupra Raval, VW ID. Polo e ID. Cross, Skoda Elroq, Epiq y Peaq, Renault 4 y 5 E-Tech, Dacia Bigster, Fiat Grande Panda, Opel Frontera, Toyota C-HR+ y Urban Cruiser, Kia EV2 a EV5, Mazda 6e y CX-6e, BMW iX3, DS Nº4/Nº7/Nº8, Alpine A290/A390…
- **Modelos de años anteriores:**
  - Seat Altea, Exeo, Córdoba y Toledo; Opel Zafira, Meriva y Vectra; Ford C-Max, S-Max y Mondeo; Citroën Xsara Picasso y C4 Picasso; Peugeot 207/307/407.
  - Renault Laguna y Scenic; Toyota Auris y Avensis; Hyundai ix35; Nissan Note y Almera; Mercedes Clase M y CLK; BMW Serie 6…

## Mejoras de búsqueda

- No distingue mayúsculas ni acentos: "citroen" encuentra "Citroën", "león" encuentra "Leon" y "tenere" encuentra "Ténéré 700".
- Las marcas de cada tipo están en orden alfabético y sin modelos repetidos. Un test lo comprueba.

## Fuentes consultadas

- Ranking de ventas 2025 (Sandero, Clio, MG ZS, Ibiza…): https://es.motor1.com/news/783245/top10-ventas-coches-espana-2025-analisis-mercado/
- Marcas más vendidas a particulares en 2025: https://www.carwow.es/noticias/6707/marcas-coches-mas-vendidas-espana-2025
- Coches de ocasión más vendidos en 2025: https://www.bolsamania.com/noticias/ultimas/economiamotor--volkswagen-golf-seat-ibiza-y-renault-megane-los-coches-de-ocasion-mas-vendidos-en-espana-en-2025--20644998.html
- Marcas chinas en España: https://www.motorpasion.com/industria/invasion-coches-chinos-no-era-espejismo-2025-byd-mg-omoda-jaecoo-venden-coches-espana-que-skoda-nissan-ford
- Gama BYD 2026: https://www.byd.com/es-es/news-list/ayudas-plan-auto-byd-2026
- Gama MG 2026: https://www.km77.com/coches/mg?rc=prices
- Gama Leapmotor 2026: https://autonomiacocheselectricos.es/articulos/gama-leapmotor-espana-que-modelo-elegir/
- Ebro, Omoda y Jaecoo: https://www.hibridosyelectricos.com/coches/ano-record-nueva-marca-en-espana-supera-jaecoo-en-ventas_84757_102.html
- Lanzamientos mes a mes en 2026 (motor.es):
  - julio: https://www.motor.es/noticias/nuevos-coches-espana-2026-julio-2026115636.html
  - agosto: https://www.motor.es/noticias/nuevos-coches-espana-2026-agosto-2026116197.html
  - octubre: https://www.motor.es/noticias/nuevos-coches-espana-2026-octubre-2026117405.html
- Motos más vendidas en 2025: https://www.mundomotero.com/el-sorpasso-chino-en-el-sector-de-la-moto-en-espana-en-2025-que-nadie-quiso-ver
- Autocaravanas más vendidas: https://www.motorpasion.com/furgonetas-y-caravanas/regla-motos-125-tambien-funciona-mundo-camper-vendidas-espana-que-se-pueden-llevar-carnet-coche

Los modelos de años anteriores, camiones, autobuses y barcos salen de conocimiento general del mercado español, no de una fuente concreta. Conviene repasarlos una vez al año.
