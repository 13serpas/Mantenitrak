\pset pager off
\set VERBOSITY terse
INSERT INTO auth.users VALUES ('00000000-0000-0000-0000-00000000000a','ana@x.com','{}'),
                              ('00000000-0000-0000-0000-00000000000b','bea@x.com','{}'),
                              ('00000000-0000-0000-0000-00000000000c','cris@x.com','{}');
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','00000000-0000-0000-0000-00000000000a',false) \g /dev/null
SELECT create_vehicle('{"type":"coche","brand":"Seat","model":"Ibiza","year":"2015","current_km":"120000","fuel_type":"Diésel"}') AS vid \gset
RESET ROLE;
INSERT INTO km_logs (vehicle_id, user_id, km, logged_at) VALUES (:'vid', '00000000-0000-0000-0000-00000000000a', 110000, CURRENT_DATE - 100);
INSERT INTO shared_vehicles (vehicle_id, user_id, role) VALUES (:'vid', '00000000-0000-0000-0000-00000000000b', 'mechanic');
SET ROLE authenticated;

\echo '=== A) Coste total repartido (cost_estimated)'
SELECT register_maintenance(:'vid', CURRENT_DATE - 5, NULL,
  '[{"item_id":"aceite","cost":"121,96","cost_estimated":true},
    {"item_id":"filtro_aceite","cost":24.39,"cost_estimated":true},
    {"item_id":"bateria","cost":90},
    {"item_id":"itv","cost_estimated":true}]');
SELECT item_id, cost, cost_estimated FROM maintenance_records ORDER BY item_id;

\echo '=== B) Repostaje con litros y precio: calcula total'
SELECT register_fuel(:'vid', CURRENT_DATE - 30, 115000, 40, 1.459, NULL, true, 'Diésel', '  Repsol Gran Vía  ') IS NOT NULL AS ok;
\echo '=== B2) con total y precio: calcula litros'
SELECT register_fuel(:'vid', CURRENT_DATE - 15, 115600, NULL, 1.5, 30, false, 'Diésel', NULL) IS NOT NULL AS ok;
\echo '=== B3) los tres cuadran (redondeo del surtidor)'
SELECT register_fuel(:'vid', CURRENT_DATE - 1, 116100, 35.21, 1.479, 52.08, true, 'Diésel', 'Repsol Gran Vía') IS NOT NULL AS ok;
\echo '=== B4) Bea (compartido) también registra, sin km'
SELECT set_config('request.jwt.claim.sub','00000000-0000-0000-0000-00000000000b',false) \g /dev/null
SELECT register_fuel(:'vid', CURRENT_DATE, NULL, 20, NULL, 30, true, 'Diésel premium', NULL) IS NOT NULL AS ok;
SELECT set_config('request.jwt.claim.sub','00000000-0000-0000-0000-00000000000a',false) \g /dev/null
SELECT logged_at - CURRENT_DATE AS dia, km, liters, price_per_liter, total, full_tank, fuel_type, station, consumption_l100,
       (user_id = '00000000-0000-0000-0000-00000000000b') AS de_bea
  FROM fuel_logs ORDER BY logged_at;
SELECT km, logged_at - CURRENT_DATE AS dia FROM km_logs ORDER BY logged_at;
SELECT current_km FROM vehicles;

\echo '=== C) validaciones (todas deben fallar)'
SELECT register_fuel(:'vid', CURRENT_DATE, NULL, 40, NULL, NULL);
SELECT register_fuel(:'vid', CURRENT_DATE + 1, NULL, 40, 1.5, NULL);
SELECT register_fuel(:'vid', CURRENT_DATE, NULL, 40, 1.5, 80);
SELECT register_fuel(:'vid', CURRENT_DATE, NULL, -5, 1.5, NULL);
SELECT register_fuel(:'vid', CURRENT_DATE, NULL, 40, 15, NULL);
SELECT register_fuel(:'vid', CURRENT_DATE, NULL, NULL, 0.001, 50);
SELECT register_fuel(:'vid', CURRENT_DATE, NULL, 40, 1.5, NULL, true, 'AdBlue');
SELECT register_fuel(:'vid', CURRENT_DATE, 100000, 40, 1.5, NULL);
SELECT register_fuel(:'vid', CURRENT_DATE - 50, 117000, 40, 1.5, NULL);
\echo '=== C2) mismo día, km mayores que la lectura de ese día: ok'
SELECT register_fuel(:'vid', CURRENT_DATE - 1, 116150, 10, 1.5, NULL) IS NOT NULL AS ok;
\echo '=== C3) eléctrico: kWh y €/kWh'
SELECT register_fuel(:'vid', CURRENT_DATE, NULL, 42.5, 0.39, NULL, true, 'Electricidad', 'Casa') IS NOT NULL AS ok;

\echo '=== D) Cris sin acceso; borrar: solo el autor'
SELECT set_config('request.jwt.claim.sub','00000000-0000-0000-0000-00000000000c',false) \g /dev/null
SELECT register_fuel(:'vid', CURRENT_DATE, NULL, 40, 1.5, NULL);
SELECT count(*) AS cris_ve FROM fuel_logs;
SELECT set_config('request.jwt.claim.sub','00000000-0000-0000-0000-00000000000b',false) \g /dev/null
WITH d AS (DELETE FROM fuel_logs WHERE user_id <> auth.uid() RETURNING 1) SELECT count(*) AS bea_borra_ajenos FROM d;
WITH d AS (DELETE FROM fuel_logs WHERE user_id = auth.uid() RETURNING 1) SELECT count(*) AS bea_borra_suyo FROM d;
\echo '=== E) anon'
RESET ROLE; SET ROLE anon;
SELECT register_fuel(:'vid', CURRENT_DATE, NULL, 40, 1.5, NULL);
SELECT assert_km_fits(:'vid', 1, CURRENT_DATE);
