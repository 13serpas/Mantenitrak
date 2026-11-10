# Precios de referencia para repartir un coste total

Cuando registras varios trabajos y solo sabes **lo que pagaste en total**, la app
reparte ese total entre los trabajos. Para que el reparto tenga sentido (un kit
de distribución no puede costar lo mismo que un filtro de aire), usa una tabla de
precios orientativos de taller en España.

## Qué es y qué no es

- **Es** una tabla fija en `lib/features/maintenance/domain/reference_prices.dart`
  con el precio medio de cada trabajo (pieza + mano de obra, IVA incluido).
- **Solo se usa la proporción** entre trabajos. Si pagaste 200 € por aceite y
  filtro, el reparto da ≈ 121,96 € y ≈ 24,39 € (proporción 75 : 15); la suma
  siempre es exactamente lo que pagaste.
- **No son precios de tienda en directo.** Las tiendas de recambios (Oscaro,
  Autodoc, Norauto…) no ofrecen una API pública de precios y stock, y leer sus
  webs a escondidas iría contra sus condiciones de uso. Si en el futuro se
  firma un acuerdo con alguna o se usa un catálogo de pago (por ejemplo, TecDoc),
  basta con sustituir la tabla por una consulta: el resto de la app no cambia.
- El importe repartido se guarda marcado como **estimado** (`cost_estimated`,
  migración 007) y se muestra con «≈» en el historial y en la ficha del registro.

## Cómo se reparte

1. Cada trabajo pesa su precio de referencia según el tipo de vehículo:
   turismo, moto/quad, camión/autobús o barco.
2. Furgonetas y 4x4 pesan un 15 % más que un turismo, las autocaravanas un 25 % y
   los autobuses un 20 % más que un camión.
3. Un «otro trabajo» (escrito a mano) pesa la mediana de los demás.
4. Se reparte en céntimos. El céntimo que sobra del redondeo va al trabajo más
   caro, así la suma cuadra siempre.
5. Si solo hay un trabajo, se guarda el total tal cual y **no** se marca como
   estimado.

## Tabla de turismo

| Trabajo | € | Fuente |
|---|---:|---|
| Aceite + filtro de aceite | 75 + 15 = 90 | Tallerator (vía Autofácil): media nacional de aceite y filtro de 89,72 € |
| Filtro de aire | 33 | Tallerator (vía Autofácil): 32,58 € |
| Pastillas delanteras | 115 | Tallerator (vía Autofácil): 114,89 € |
| 4 neumáticos | 454 | Tallerator (vía Autofácil): 453,81 € |
| Kit de distribución | 415 | Tallerator (vía Autofácil): 415,25 € |
| ITV | 43 | FACUA 2026: media de 39,18 € (gasolina) y 46,09 € (diésel), más la tasa de Tráfico de 4,18 € |
| Refrigerante, líquido de frenos, bujías, batería, filtro de habitáculo y de combustible, discos, pastillas traseras | 30–230 | Estimación propia a partir de las anteriores |

Las tablas de moto, camión y barco son estimaciones propias que mantienen esas
proporciones. Conviene revisarlas una vez al año (los precios de taller han
subido en torno a un 34 % en cinco años, según datos del INE que recoge CONEPA).

## Fuentes

- [Autofácil: mantenimiento a los 100.000 km, precios medios de Tallerator](https://www.autofacil.es/mantenimiento/mantenimiento-coche-verano-100000-km/105146.html)
- [Autofácil: precio medio del kit de distribución](https://www.autofacil.es/cuesta-cambiar-kit-distribucion/)
- [Motor16: informe de FACUA sobre las tarifas de la ITV en 2026](https://www.motor16.com/las-ultimas-noticias/precio-itv-segun-comunidad/)
- [Total Renting: tasa de Tráfico de la ITV en 2026](https://totalrenting.es/informacion/cuanto-cuesta-la-itv/)
- [Motor16: la factura del taller sube un 34 % en cinco años](https://www.motor16.com/las-ultimas-noticias/factura-taller-sube-frenos/)
