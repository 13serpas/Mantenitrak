\pset pager off
\set VERBOSITY terse
INSERT INTO auth.users VALUES ('00000000-0000-0000-0000-00000000000a','ana@x.com','{"full_name":"Ana López"}'),
                              ('00000000-0000-0000-0000-00000000000b','bea@x.com','{}'),
                              ('00000000-0000-0000-0000-00000000000c','cris@x.com','{}');
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','00000000-0000-0000-0000-00000000000a',false) \g /dev/null
SELECT create_vehicle('{"type":"coche","brand":"Seat","model":"Ibiza","year":"2015","current_km":"120000"}') AS vid \gset
SELECT share_code IS NULL AS sin_codigo_en_vehicles FROM vehicles;

\echo '=== A) Ana obtiene el código (se crea), repetir devuelve el mismo'
SELECT code AS c1, expires_at > now() + interval '6 days' AS siete_dias FROM get_share_invite(:'vid') \gset
\echo 'siete_dias' :siete_dias
SELECT (SELECT code FROM get_share_invite(:'vid')) = :'c1' AS mismo;
SELECT count(*) AS ana_no_ve_la_tabla FROM vehicle_invites;

\echo '=== B) Bea se une como taller con el código en minúsculas y con espacio'
SELECT set_config('request.jwt.claim.sub','00000000-0000-0000-0000-00000000000b',false) \g /dev/null
SELECT brand, model, already_member FROM join_vehicle_by_code(lower(substr(:'c1',1,3)) || ' ' || substr(:'c1',4), 'mechanic');
SELECT already_member FROM join_vehicle_by_code(:'c1', 'regular');
SELECT role AS sigue_como_taller FROM shared_vehicles;
\echo 'Bea (compartida) no puede ver ni renovar el código:'
SELECT * FROM get_share_invite(:'vid');
SELECT * FROM regenerate_share_code(:'vid');
SELECT display_name, role, is_me FROM vehicle_members(:'vid');
SELECT set_member_role(:'vid', '00000000-0000-0000-0000-00000000000b', 'company');

\echo '=== C) Ana ve a todos con nombre y cambia el rol de Bea'
SELECT set_config('request.jwt.claim.sub','00000000-0000-0000-0000-00000000000a',false) \g /dev/null
SELECT display_name, role, is_me FROM vehicle_members(:'vid');
SELECT set_member_role(:'vid', '00000000-0000-0000-0000-00000000000b', 'mechanic');
SELECT set_member_role(:'vid', '00000000-0000-0000-0000-00000000000b', 'jefe');
SELECT set_member_role(:'vid', '00000000-0000-0000-0000-00000000000c', 'regular');
SELECT join_vehicle_by_code(:'c1');

\echo '=== D) Ana renueva: el código viejo deja de valer'
SELECT code AS c2 FROM regenerate_share_code(:'vid', 1) \gset
SELECT :'c1' <> :'c2' AS distinto;
SELECT * FROM regenerate_share_code(:'vid', 99);
SELECT set_config('request.jwt.claim.sub','00000000-0000-0000-0000-00000000000c',false) \g /dev/null
SELECT * FROM join_vehicle_by_code(:'c1');
SELECT * FROM join_vehicle_by_code('ab');
SELECT * FROM join_vehicle_by_code(:'c2', 'admin');
\echo 'caducado:'
RESET ROLE; UPDATE vehicle_invites SET expires_at = now() - interval '1 minute'; SET ROLE authenticated;
SELECT * FROM join_vehicle_by_code(:'c2');
\echo 'get_share_invite crea uno nuevo si ha caducado:'
SELECT set_config('request.jwt.claim.sub','00000000-0000-0000-0000-00000000000a',false) \g /dev/null
SELECT code AS c3 FROM get_share_invite(:'vid') \gset
SELECT :'c3' <> :'c2' AS renovado;

\echo '=== E) Límite de intentos (Cris ya lleva 2 fallos, 8 más = 10)'
SELECT set_config('request.jwt.claim.sub','00000000-0000-0000-0000-00000000000c',false) \g /dev/null
DO $$ BEGIN FOR i IN 1..8 LOOP PERFORM join_vehicle_by_code('ZZZZZZ'); END LOOP; END $$;
SELECT * FROM join_vehicle_by_code(:'c3');

\echo '=== F) Quitar acceso: Bea sale; Ana quita a otro'
SELECT set_config('request.jwt.claim.sub','00000000-0000-0000-0000-00000000000b',false) \g /dev/null
WITH d AS (DELETE FROM shared_vehicles WHERE vehicle_id = :'vid' AND user_id = auth.uid() RETURNING 1) SELECT count(*) AS bea_sale FROM d;
SELECT count(*) AS bea_ya_no_ve FROM vehicles;
SELECT * FROM join_vehicle_by_code(:'c3', 'regular');
SELECT set_config('request.jwt.claim.sub','00000000-0000-0000-0000-00000000000a',false) \g /dev/null
WITH d AS (DELETE FROM shared_vehicles WHERE vehicle_id = :'vid' AND user_id = '00000000-0000-0000-0000-00000000000b' RETURNING 1) SELECT count(*) AS ana_quita FROM d;

\echo '=== G) anon no puede nada'
RESET ROLE; SET ROLE anon;
SELECT * FROM get_share_invite(:'vid');
SELECT * FROM join_vehicle_by_code(:'c3');
SELECT * FROM vehicle_members(:'vid');
SELECT generate_share_code(6);
