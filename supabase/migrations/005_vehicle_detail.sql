-- ============================================================
-- MANTENITRAK — Migración 005: detalle del vehículo (punto 4)
-- Editar vehículo, guardar la ficha técnica y blindar columnas.
-- Ejecutar después de 004. Idempotente.
-- ============================================================

-- ─── 1. Columnas que la app puede modificar directamente ─────
-- La política RLS solo dice QUIÉN puede actualizar (el propietario), no
-- QUÉ columnas. Sin esto, el propietario podía poner a mano un
-- share_code fácil de adivinar, cambiar owner_id o falsear current_km
-- sin dejar lectura en km_logs. Los km van por log_km() y el código por
-- regenerate_share_code(), ambas SECURITY DEFINER, que no se ven afectadas.
REVOKE UPDATE ON public.vehicles FROM anon, authenticated;
GRANT UPDATE (type, brand, model, year, engine, plate, fuel_type, usage, role, zone, annual_km)
  ON public.vehicles TO authenticated;

-- ─── 2. Guardar (o borrar) la ficha técnica ──────────────────
-- Una ficha vacía la elimina. Solo se copian columnas conocidas.
-- SECURITY INVOKER: la política de vehicle_specs exige ser propietario.
CREATE OR REPLACE FUNCTION public.save_vehicle_specs(
  p_vehicle_id UUID,
  p_specs      JSONB
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_liters NUMERIC;
  v_owner  BOOLEAN;
  v_empty  BOOLEAN;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Debes iniciar sesión' USING ERRCODE = '42501';
  END IF;

  SELECT owner_id = auth.uid() INTO v_owner FROM public.vehicles WHERE id = p_vehicle_id;
  IF v_owner IS DISTINCT FROM TRUE THEN
    RAISE EXCEPTION 'Solo el propietario puede cambiar la ficha técnica' USING ERRCODE = '42501';
  END IF;

  -- ¿Queda algún dato útil? (source no cuenta)
  v_empty := p_specs IS NULL OR NOT EXISTS (
    SELECT 1 FROM jsonb_each(p_specs) e
    WHERE e.key <> 'source'
      AND e.value <> 'null'::JSONB
      AND NOT (jsonb_typeof(e.value) = 'string' AND trim(e.value #>> '{}') = '')
      AND NOT (jsonb_typeof(e.value) = 'array' AND jsonb_array_length(e.value) = 0)
  );
  IF v_empty THEN
    DELETE FROM public.vehicle_specs WHERE vehicle_id = p_vehicle_id;
    RETURN;
  END IF;

  BEGIN
    v_liters := NULLIF(replace(p_specs->>'oil_liters', ',', '.'), '')::NUMERIC;
  EXCEPTION WHEN invalid_text_representation THEN
    RAISE EXCEPTION 'Los litros de aceite deben ser un número' USING ERRCODE = '22023';
  END;
  IF v_liters IS NOT NULL AND (v_liters <= 0 OR v_liters > 60) THEN
    RAISE EXCEPTION 'Los litros de aceite deben estar entre 0 y 60' USING ERRCODE = '22023';
  END IF;

  INSERT INTO public.vehicle_specs AS s (
    vehicle_id, oil_type, oil_liters, oil_brands, oil_filter_ref, air_filter_ref,
    cabin_filter_ref, fuel_filter_ref, spark_plug_ref, tire_size_front,
    tire_size_rear, tire_brand, battery_spec, notes, source
  ) VALUES (
    p_vehicle_id,
    left(NULLIF(trim(p_specs->>'oil_type'), ''), 120),
    v_liters,
    CASE WHEN jsonb_typeof(p_specs->'oil_brands') = 'array'
         THEN ARRAY(SELECT left(x, 60) FROM jsonb_array_elements_text(p_specs->'oil_brands') x LIMIT 5)
         ELSE NULL END,
    left(NULLIF(trim(p_specs->>'oil_filter_ref'), ''), 120),
    left(NULLIF(trim(p_specs->>'air_filter_ref'), ''), 120),
    left(NULLIF(trim(p_specs->>'cabin_filter_ref'), ''), 120),
    left(NULLIF(trim(p_specs->>'fuel_filter_ref'), ''), 120),
    left(NULLIF(trim(p_specs->>'spark_plug_ref'), ''), 120),
    left(NULLIF(trim(p_specs->>'tire_size_front'), ''), 120),
    left(NULLIF(trim(p_specs->>'tire_size_rear'), ''), 120),
    left(NULLIF(trim(p_specs->>'tire_brand'), ''), 120),
    left(NULLIF(trim(p_specs->>'battery_spec'), ''), 120),
    left(NULLIF(trim(p_specs->>'notes'), ''), 1000),
    CASE WHEN p_specs->>'source' IN ('ia', 'manual', 'foto') THEN p_specs->>'source' ELSE 'manual' END
  )
  ON CONFLICT (vehicle_id) DO UPDATE SET
    oil_type         = EXCLUDED.oil_type,
    oil_liters       = EXCLUDED.oil_liters,
    oil_brands       = EXCLUDED.oil_brands,
    oil_filter_ref   = EXCLUDED.oil_filter_ref,
    air_filter_ref   = EXCLUDED.air_filter_ref,
    cabin_filter_ref = EXCLUDED.cabin_filter_ref,
    fuel_filter_ref  = EXCLUDED.fuel_filter_ref,
    spark_plug_ref   = EXCLUDED.spark_plug_ref,
    tire_size_front  = EXCLUDED.tire_size_front,
    tire_size_rear   = EXCLUDED.tire_size_rear,
    tire_brand       = EXCLUDED.tire_brand,
    battery_spec     = EXCLUDED.battery_spec,
    notes            = EXCLUDED.notes,
    source           = EXCLUDED.source;
END;
$$;

GRANT EXECUTE ON FUNCTION public.save_vehicle_specs(UUID, JSONB) TO authenticated;
REVOKE EXECUTE ON FUNCTION public.save_vehicle_specs(UUID, JSONB) FROM anon, public;

-- ─── 3. Editar los datos del vehículo ────────────────────────
-- Mismas validaciones que create_vehicle. Los km NO se editan aquí:
-- una lectura nueva va por log_km() para que quede en el historial.
CREATE OR REPLACE FUNCTION public.update_vehicle(
  p_vehicle_id UUID,
  p_vehicle    JSONB
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_year   INT;
  v_annual INT;
  v_type   TEXT := p_vehicle->>'type';
  v_rows   INT;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Debes iniciar sesión' USING ERRCODE = '42501';
  END IF;
  IF COALESCE(trim(p_vehicle->>'brand'), '') = '' OR COALESCE(trim(p_vehicle->>'model'), '') = '' THEN
    RAISE EXCEPTION 'Marca y modelo son obligatorios' USING ERRCODE = '22023';
  END IF;
  BEGIN
    v_year   := NULLIF(p_vehicle->>'year', '')::INT;
    v_annual := NULLIF(p_vehicle->>'annual_km', '')::INT;
  EXCEPTION WHEN invalid_text_representation THEN
    RAISE EXCEPTION 'Año o km al año no válidos' USING ERRCODE = '22023';
  END;
  IF v_year IS NULL OR v_year < 1900 OR v_year > EXTRACT(YEAR FROM NOW())::INT + 1 THEN
    RAISE EXCEPTION 'Año no válido' USING ERRCODE = '22023';
  END IF;
  IF v_annual IS NOT NULL AND (v_annual < 0 OR v_annual > 500000) THEN
    RAISE EXCEPTION 'Km al año no válidos' USING ERRCODE = '22023';
  END IF;

  UPDATE public.vehicles SET
    type      = v_type,
    brand     = left(trim(p_vehicle->>'brand'), 60),
    model     = left(trim(p_vehicle->>'model'), 60),
    year      = v_year,
    engine    = left(NULLIF(trim(p_vehicle->>'engine'), ''), 80),
    plate     = NULLIF(upper(regexp_replace(trim(COALESCE(p_vehicle->>'plate', '')), '\s+', ' ', 'g')), ''),
    fuel_type = NULLIF(p_vehicle->>'fuel_type', ''),
    -- Los barcos no tienen uso por km.
    usage     = CASE WHEN v_type = 'barco' THEN NULL ELSE NULLIF(p_vehicle->>'usage', '') END,
    role      = COALESCE(NULLIF(p_vehicle->>'role', ''), 'owner'),
    zone      = CASE WHEN v_type = 'barco' THEN 'interior' ELSE COALESCE(NULLIF(p_vehicle->>'zone', ''), 'interior') END,
    annual_km = CASE WHEN v_type = 'barco' THEN NULL ELSE v_annual END
  WHERE id = p_vehicle_id;

  -- RLS filtra en silencio las filas ajenas: 0 filas = sin permiso o no existe.
  GET DIAGNOSTICS v_rows = ROW_COUNT;
  IF v_rows = 0 THEN
    RAISE EXCEPTION 'Solo el propietario puede editar este vehículo' USING ERRCODE = '42501';
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.update_vehicle(UUID, JSONB) TO authenticated;
REVOKE EXECUTE ON FUNCTION public.update_vehicle(UUID, JSONB) FROM anon, public;

-- ─── 4. create_vehicle reutiliza la misma lógica de ficha ────
-- Así la validación de litros y los límites de longitud son idénticos
-- en el alta y en la edición.
CREATE OR REPLACE FUNCTION public.create_vehicle(
  p_vehicle JSONB,
  p_specs   JSONB DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid    UUID := auth.uid();
  v_id     UUID;
  v_km     INT;
  v_annual INT;
  v_year   INT;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Debes iniciar sesión' USING ERRCODE = '42501';
  END IF;
  IF COALESCE(trim(p_vehicle->>'brand'), '') = '' OR COALESCE(trim(p_vehicle->>'model'), '') = '' THEN
    RAISE EXCEPTION 'Marca y modelo son obligatorios' USING ERRCODE = '22023';
  END IF;
  BEGIN
    v_km     := NULLIF(p_vehicle->>'current_km', '')::INT;
    v_annual := NULLIF(p_vehicle->>'annual_km', '')::INT;
    v_year   := NULLIF(p_vehicle->>'year', '')::INT;
  EXCEPTION WHEN invalid_text_representation THEN
    RAISE EXCEPTION 'Año o kilómetros no válidos' USING ERRCODE = '22023';
  END;
  IF v_year IS NULL OR v_year < 1900 OR v_year > EXTRACT(YEAR FROM NOW())::INT + 1 THEN
    RAISE EXCEPTION 'Año no válido' USING ERRCODE = '22023';
  END IF;
  IF v_km IS NOT NULL AND (v_km < 0 OR v_km > 3000000) THEN
    RAISE EXCEPTION 'Kilometraje no válido' USING ERRCODE = '22023';
  END IF;
  IF v_annual IS NOT NULL AND (v_annual < 0 OR v_annual > 500000) THEN
    RAISE EXCEPTION 'Km al año no válidos' USING ERRCODE = '22023';
  END IF;

  INSERT INTO public.vehicles (
    owner_id, type, brand, model, year, engine, plate,
    fuel_type, usage, role, zone, current_km, annual_km
  ) VALUES (
    v_uid,
    p_vehicle->>'type',
    left(trim(p_vehicle->>'brand'), 60),
    left(trim(p_vehicle->>'model'), 60),
    v_year,
    left(NULLIF(trim(p_vehicle->>'engine'), ''), 80),
    NULLIF(upper(regexp_replace(trim(COALESCE(p_vehicle->>'plate', '')), '\s+', ' ', 'g')), ''),
    NULLIF(p_vehicle->>'fuel_type', ''),
    NULLIF(p_vehicle->>'usage', ''),
    COALESCE(NULLIF(p_vehicle->>'role', ''), 'owner'),
    COALESCE(NULLIF(p_vehicle->>'zone', ''), 'interior'),
    v_km,
    v_annual
  )
  RETURNING id INTO v_id;

  IF v_km IS NOT NULL THEN
    INSERT INTO public.km_logs (vehicle_id, user_id, km, logged_at)
    VALUES (v_id, v_uid, v_km, CURRENT_DATE);
  END IF;

  IF p_specs IS NOT NULL THEN
    PERFORM public.save_vehicle_specs(v_id, p_specs);
  END IF;

  RETURN v_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.create_vehicle(JSONB, JSONB) TO authenticated;
REVOKE EXECUTE ON FUNCTION public.create_vehicle(JSONB, JSONB) FROM anon, public;
