\pset pager off
\set VERBOSITY terse
INSERT INTO auth.users VALUES ('00000000-0000-0000-0000-00000000000a','ana@x.com','{}'),
                              ('00000000-0000-0000-0000-00000000000b','bea@x.com','{}'),
                              ('00000000-0000-0000-0000-00000000000c','cris@x.com','{}');
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','00000000-0000-0000-0000-00000000000a',false) \g /dev/null
SELECT create_vehicle('{"type":"coche","brand":"Seat","model":"Ibiza","year":"2019","current_km":"50000"}') AS vid \gset
-- Lecturas: 40.000 hace 200 días y 50.000 hoy
RESET ROLE;
INSERT INTO km_logs (vehicle_id, user_id, km, logged_at) VALUES (:'vid', '00000000-0000-0000-0000-00000000000a', 40000, CURRENT_DATE - 200);
INSERT INTO shared_vehicles (vehicle_id, user_id, role) VALUES (:'vid', '00000000-0000-0000-0000-00000000000b', 'mechanic');
SET ROLE authenticated;

\echo '--- 1) varios trabajos con coste, foto y notas, sin km:'
SELECT register_maintenance(:'vid', CURRENT_DATE - 10, NULL,
  jsonb_build_array(
    jsonb_build_object('item_id','aceite','item_name','Aceite del motor','cost','89,90','photos', jsonb_build_array(:'vid' || '/a1.jpg')),
    jsonb_build_object('item_id','filtro_aceite','item_name','Filtro de aceite','cost',12),
    jsonb_build_object('item_id','otro','item_name','  Escobillas  ')),
  '  Taller Pepe ') AS guardados;
SELECT item_id, item_name, cost, notes, photos FROM maintenance_records ORDER BY item_id;
SELECT count(*) AS lecturas_km FROM km_logs;

\echo '--- 2) con km de hoy: guarda lectura y actualiza current_km:'
SELECT register_maintenance(:'vid', CURRENT_DATE, 51000, '[{"item_id":"itv"}]');
SELECT current_km, (SELECT count(*) FROM km_logs) AS lecturas FROM vehicles;
\echo '--- 2b) mismo día y mismos km: no duplica la lectura:'
SELECT register_maintenance(:'vid', CURRENT_DATE, 51000, '[{"item_id":"bateria"}]');
SELECT count(*) AS lecturas FROM km_logs;

\echo '--- 3) km incoherentes:'
SELECT register_maintenance(:'vid', CURRENT_DATE, 45000, '[{"item_id":"itv"}]');
SELECT register_maintenance(:'vid', CURRENT_DATE - 300, 42000, '[{"item_id":"itv"}]');
\echo '--- 3b) km en el pasado coherentes (entre lecturas): ok'
SELECT register_maintenance(:'vid', CURRENT_DATE - 100, 45000, '[{"item_id":"neumaticos"}]');
SELECT current_km FROM vehicles;

\echo '--- 4) validaciones:'
SELECT register_maintenance(:'vid', CURRENT_DATE + 1, NULL, '[{"item_id":"itv"}]');
SELECT register_maintenance(:'vid', CURRENT_DATE, NULL, '[]');
SELECT register_maintenance(:'vid', CURRENT_DATE, NULL, '[{"item_id":"otro"}]');
SELECT register_maintenance(:'vid', CURRENT_DATE, NULL, '[{"item_id":"DROP TABLE"}]');
SELECT register_maintenance(:'vid', CURRENT_DATE, NULL, '[{"item_id":"itv","cost":"mucho"}]');
SELECT register_maintenance(:'vid', CURRENT_DATE, NULL, '[{"item_id":"itv","cost":-5}]');
SELECT register_maintenance(:'vid', CURRENT_DATE, NULL, '[{"item_id":"itv","photos":["11111111-1111-1111-1111-111111111111/x.jpg"]}]');
SELECT register_maintenance(:'vid', CURRENT_DATE, NULL, jsonb_build_array(jsonb_build_object('item_id','itv','photos', jsonb_build_array(:'vid' || '/../x.jpg'))));
\echo '--- 4b) todo o nada: el segundo falla y no se guarda el primero'
SELECT count(*) AS antes FROM maintenance_records \gset
SELECT register_maintenance(:'vid', CURRENT_DATE, NULL, '[{"item_id":"itv"},{"item_id":"otro"}]');
SELECT count(*) - :antes AS nuevos FROM maintenance_records;

\echo '--- 5) Bea (taller compartido) puede registrar; Cris no:'
SELECT set_config('request.jwt.claim.sub','00000000-0000-0000-0000-00000000000b',false) \g /dev/null
SELECT register_maintenance(:'vid', CURRENT_DATE, NULL, '[{"item_id":"frenos_delanteros","cost":110}]');
SELECT set_config('request.jwt.claim.sub','00000000-0000-0000-0000-00000000000c',false) \g /dev/null
SELECT register_maintenance(:'vid', CURRENT_DATE, NULL, '[{"item_id":"itv"}]');

\echo '--- 6) Storage: rutas de vehículo y permisos'
SELECT photo_vehicle_id(:'vid' || '/a.jpg') = :'vid' AS ruta_ok, photo_vehicle_id('basura/a.jpg') AS ruta_mala;
SELECT set_config('request.jwt.claim.sub','00000000-0000-0000-0000-00000000000b',false) \g /dev/null
INSERT INTO storage.objects (bucket_id, name) VALUES ('maintenance-photos', :'vid' || '/bea.jpg') RETURNING 'Bea sube' AS ok;
SELECT set_config('request.jwt.claim.sub','00000000-0000-0000-0000-00000000000a',false) \g /dev/null
INSERT INTO storage.objects (bucket_id, name) VALUES ('maintenance-photos', :'vid' || '/ana.jpg') RETURNING 'Ana sube' AS ok;
SELECT count(*) AS ana_ve FROM storage.objects;
\echo '--- 6b) Cris no ve, no sube a ese vehículo ni a una ruta sin vehículo:'
SELECT set_config('request.jwt.claim.sub','00000000-0000-0000-0000-00000000000c',false) \g /dev/null
SELECT count(*) AS cris_ve FROM storage.objects;
INSERT INTO storage.objects (bucket_id, name) VALUES ('maintenance-photos', :'vid' || '/cris.jpg');
INSERT INTO storage.objects (bucket_id, name) VALUES ('maintenance-photos', 'cris/x.jpg');
\echo '--- 6c) Bea ve las de Ana pero solo borra la suya; Ana (propietaria) borra cualquiera:'
SELECT set_config('request.jwt.claim.sub','00000000-0000-0000-0000-00000000000b',false) \g /dev/null
SELECT count(*) AS bea_ve FROM storage.objects;
DELETE FROM storage.objects WHERE name LIKE '%/ana.jpg' RETURNING name;
DELETE FROM storage.objects WHERE name LIKE '%/bea.jpg' RETURNING 'Bea borra la suya' AS ok;
SELECT set_config('request.jwt.claim.sub','00000000-0000-0000-0000-00000000000a',false) \g /dev/null
DELETE FROM storage.objects WHERE name LIKE '%/ana.jpg' RETURNING 'Ana borra' AS ok;

\echo '--- 7) anon no puede ejecutar:'
SET ROLE anon;
SELECT register_maintenance(:'vid', CURRENT_DATE, NULL, '[{"item_id":"itv"}]');
