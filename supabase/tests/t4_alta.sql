\pset pager off
\set VERBOSITY terse
INSERT INTO auth.users VALUES ('00000000-0000-0000-0000-00000000000a','ana@x.com','{"full_name":"Ana"}');
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','00000000-0000-0000-0000-00000000000a',false) \g /dev/null
\echo '--- 1) alta completa con ficha (intenta colar vehicle_id/id ajenos y owner_id):'
SELECT create_vehicle(
  '{"type":"coche","brand":" Seat ","model":"Ibiza","year":"2019","plate":"  4521   hjk ","fuel_type":"Gasolina","usage":"Ciudad","zone":"costa","current_km":"50000","annual_km":"12000","owner_id":"00000000-0000-0000-0000-0000000000ff","share_code":"AAAAAA"}',
  '{"oil_type":"5W-30","oil_liters":"4.2","oil_brands":["Castrol","Repsol"],"tire_size_front":"205/55 R16","vehicle_id":"11111111-1111-1111-1111-111111111111","id":"22222222-2222-2222-2222-222222222222","source":"ia"}'
) IS NOT NULL AS creado;
SELECT brand, plate, owner_id = auth.uid() AS dueño_correcto, share_code <> 'AAAAAA' AS codigo_aleatorio, current_km FROM vehicles;
SELECT km, logged_at = CURRENT_DATE AS hoy FROM km_logs;
SELECT oil_type, oil_liters, oil_brands, source, vehicle_id = (SELECT id FROM vehicles) AS ficha_del_vehiculo FROM vehicle_specs;
\echo '--- 2) año imposible:'
SELECT create_vehicle('{"type":"coche","brand":"A","model":"B","year":"1800"}');
\echo '--- 3) ficha con litros no numéricos -> no debe quedar el vehículo a medias:'
SELECT create_vehicle('{"type":"moto","brand":"Honda","model":"PCX","year":"2022","current_km":"100"}', '{"oil_liters":"mucho"}');
SELECT count(*) AS vehiculos_total FROM vehicles;
\echo '--- 4) tipo no permitido:'
SELECT create_vehicle('{"type":"patinete","brand":"X","model":"Y","year":"2020"}');
\echo '--- 5) barco sin km (permitido):'
SELECT create_vehicle('{"type":"barco","brand":"Beneteau","model":"Flyer 7","year":"2018"}') IS NOT NULL AS barco_ok;
SELECT count(*) AS km_logs_total FROM km_logs;
\echo '--- 6) sin sesión:'
SELECT set_config('request.jwt.claim.sub','',false) \g /dev/null
SELECT create_vehicle('{"type":"coche","brand":"A","model":"B","year":"2020"}');
