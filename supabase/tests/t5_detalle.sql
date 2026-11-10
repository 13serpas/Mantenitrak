\pset pager off
\set VERBOSITY terse
INSERT INTO auth.users VALUES ('00000000-0000-0000-0000-00000000000a','ana@x.com','{"full_name":"Ana"}'),
                              ('00000000-0000-0000-0000-00000000000b','bea@x.com','{}'),
                              ('00000000-0000-0000-0000-00000000000c','cris@x.com','{}');
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','00000000-0000-0000-0000-00000000000a',false) \g /dev/null
SELECT create_vehicle('{"type":"coche","brand":"Seat","model":"Ibiza","year":"2019","current_km":"50000"}',
                      '{"oil_type":"5W-30","oil_liters":"4,2","source":"ia"}') AS vid \gset
\echo '--- 1) alta con litros "4,2" (coma) y ficha creada por save_vehicle_specs:'
SELECT oil_type, oil_liters, source FROM vehicle_specs;

\echo '--- 2) dueña edita datos (matrícula normalizada, km/año):'
SELECT update_vehicle(:'vid', '{"type":"coche","brand":"Seat","model":"Leon","year":"2020","plate":" 1234   abc ","fuel_type":"Diésel","usage":"Carretera","zone":"norte","annual_km":"20000","role":"company"}');
SELECT brand, model, year, plate, fuel_type, usage, zone, annual_km, role, current_km FROM vehicles;

\echo '--- 3) intento de colar columnas protegidas vía update_vehicle (se ignoran):'
SELECT update_vehicle(:'vid', '{"type":"coche","brand":"Seat","model":"Leon","year":"2020","current_km":"1","share_code":"AAAAAA","owner_id":"00000000-0000-0000-0000-00000000000b"}');
SELECT current_km, share_code <> 'AAAAAA' AS codigo_intacto, owner_id = auth.uid() AS sigue_siendo_mia FROM vehicles;

\echo '--- 4) UPDATE directo de columnas protegidas (debe fallar por permisos):'
UPDATE vehicles SET share_code = 'AAAAAA';
UPDATE vehicles SET current_km = 1;
UPDATE vehicles SET owner_id = '00000000-0000-0000-0000-00000000000b';
\echo '--- 4b) UPDATE directo de una columna permitida (funciona):'
UPDATE vehicles SET engine = '1.0 TSI' RETURNING engine;

\echo '--- 5) validaciones de update_vehicle:'
SELECT update_vehicle(:'vid', '{"type":"coche","brand":"","model":"X","year":"2020"}');
SELECT update_vehicle(:'vid', '{"type":"coche","brand":"A","model":"X","year":"veinte"}');
SELECT update_vehicle(:'vid', '{"type":"coche","brand":"A","model":"X","year":"2020","annual_km":"999999"}');
SELECT update_vehicle(:'vid', '{"type":"patinete","brand":"A","model":"X","year":"2020"}');

\echo '--- 6) ficha: litros fuera de rango y no numéricos:'
SELECT save_vehicle_specs(:'vid', '{"oil_liters":"75"}');
SELECT save_vehicle_specs(:'vid', '{"oil_liters":"mucho"}');
\echo '--- 6b) actualizar ficha (upsert) con marcas y campo desconocido:'
SELECT save_vehicle_specs(:'vid', '{"oil_type":"5W-40","tire_size_front":"205/55 R16","oil_brands":["Castrol","Repsol"],"vehicle_id":"11111111-1111-1111-1111-111111111111","hack":"x","source":"manual"}');
SELECT oil_type, oil_liters, tire_size_front, oil_brands, source, count(*) OVER () AS filas FROM vehicle_specs;
\echo '--- 6c) ficha vacía => se borra:'
SELECT save_vehicle_specs(:'vid', '{"oil_type":"  ","oil_brands":[],"source":"manual"}');
SELECT count(*) AS fichas FROM vehicle_specs;

\echo '--- 7) Bea comparte el vehículo como taller y NO puede editar ni cambiar ficha:'
RESET ROLE;
INSERT INTO shared_vehicles (vehicle_id, user_id, role) VALUES (:'vid', '00000000-0000-0000-0000-00000000000b', 'mechanic');
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','00000000-0000-0000-0000-00000000000b',false) \g /dev/null
SELECT count(*) AS bea_lo_ve FROM vehicles;
SELECT update_vehicle(:'vid', '{"type":"coche","brand":"Hack","model":"X","year":"2020"}');
SELECT save_vehicle_specs(:'vid', '{"oil_type":"hack"}');
DELETE FROM vehicles WHERE id = :'vid' RETURNING id;
\echo '--- 7b) Bea sí puede dejar de seguirlo (borrar su acceso):'
DELETE FROM shared_vehicles WHERE vehicle_id = :'vid' AND user_id = auth.uid() RETURNING role;
SELECT count(*) AS bea_ya_no_lo_ve FROM vehicles;

\echo '--- 8) Cris (sin acceso) no puede nada:'
SELECT set_config('request.jwt.claim.sub','00000000-0000-0000-0000-00000000000c',false) \g /dev/null
SELECT update_vehicle(:'vid', '{"type":"coche","brand":"Hack","model":"X","year":"2020"}');
SELECT save_vehicle_specs(:'vid', '{"oil_type":"hack"}');

\echo '--- 9) borrar mantenimiento propio / ajeno:'
SELECT set_config('request.jwt.claim.sub','00000000-0000-0000-0000-00000000000a',false) \g /dev/null
INSERT INTO maintenance_records (vehicle_id, user_id, item_id, km) VALUES (:'vid', auth.uid(), 'aceite', 50000) RETURNING id AS rid \gset
SELECT set_config('request.jwt.claim.sub','00000000-0000-0000-0000-00000000000c',false) \g /dev/null
DELETE FROM maintenance_records WHERE id = :'rid' RETURNING id;
SELECT set_config('request.jwt.claim.sub','00000000-0000-0000-0000-00000000000a',false) \g /dev/null
DELETE FROM maintenance_records WHERE id = :'rid' RETURNING item_id;

\echo '--- 10) log_km sigue funcionando (DEFINER) pese al REVOKE:'
SELECT log_km(:'vid', 52000, CURRENT_DATE);
SELECT current_km FROM vehicles;

\echo '--- 11) la dueña borra el vehículo (cascada):'
DELETE FROM vehicles WHERE id = :'vid' RETURNING brand;
SELECT (SELECT count(*) FROM km_logs) AS km_logs, (SELECT count(*) FROM vehicles) AS vehiculos;

\echo '--- 12) sin sesión:'
SELECT set_config('request.jwt.claim.sub','',false) \g /dev/null
SELECT save_vehicle_specs(:'vid', '{"oil_type":"x"}');
SELECT update_vehicle(:'vid', '{"type":"coche","brand":"A","model":"B","year":"2020"}');
\echo '--- 13) anon no puede ejecutar las funciones:'
SET ROLE anon;
SELECT update_vehicle(:'vid', '{"type":"coche","brand":"A","model":"B","year":"2020"}');
