-- ============================================================
-- MANTENITRAK — Migración 004: alta de vehículo atómica
-- Ejecutar después de 003. Idempotente.
-- ============================================================

-- ─── Política de lectura de vehicles ─────────────────────────
-- Al insertar con RETURNING (o .insert().select() desde la app), Postgres
-- exige que la fila nueva pase la política SELECT. has_vehicle_access()
-- no ve la fila recién insertada en la misma sentencia, así que el alta
-- fallaba SIEMPRE con "violates row-level security policy". Comprobar
-- owner_id directamente sobre la fila lo resuelve (y es más rápido).
DROP POLICY IF EXISTS "Ver vehículos propios y compartidos" ON public.vehicles;
CREATE POLICY "Ver vehículos propios y compartidos"
  ON public.vehicles FOR SELECT
  USING (owner_id = auth.uid() OR public.has_vehicle_access(id));

-- Origen de la ficha técnica: la de IA es orientativa y la app lo indica.
ALTER TABLE public.vehicle_specs
  ADD COLUMN IF NOT EXISTS source TEXT;

DO $$ BEGIN
  ALTER TABLE public.vehicle_specs
    ADD CONSTRAINT vehicle_specs_source_check CHECK (source IN ('ia', 'manual', 'foto'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Crea vehículo + primera lectura de km + ficha técnica en UNA transacción.
-- Si algo falla no queda nada a medias (el prototipo hacía 3 llamadas
-- sueltas y podía dejar un vehículo sin su lectura de km).
-- SECURITY INVOKER: se aplican las políticas RLS normales.
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
  v_km     INT  := NULLIF(p_vehicle->>'current_km', '')::INT;
  v_annual INT  := NULLIF(p_vehicle->>'annual_km', '')::INT;
  v_year   INT  := NULLIF(p_vehicle->>'year', '')::INT;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Debes iniciar sesión' USING ERRCODE = '42501';
  END IF;
  IF COALESCE(trim(p_vehicle->>'brand'), '') = '' OR COALESCE(trim(p_vehicle->>'model'), '') = '' THEN
    RAISE EXCEPTION 'Marca y modelo son obligatorios' USING ERRCODE = '22023';
  END IF;
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
    trim(p_vehicle->>'brand'),
    trim(p_vehicle->>'model'),
    v_year,
    NULLIF(trim(p_vehicle->>'engine'), ''),
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

  -- Solo se copian las columnas conocidas: nada de lo que mande el cliente
  -- (o la IA) puede escribir en otras columnas.
  IF p_specs IS NOT NULL AND p_specs <> '{}'::JSONB THEN
    INSERT INTO public.vehicle_specs (
      vehicle_id, oil_type, oil_liters, oil_brands, oil_filter_ref, air_filter_ref,
      cabin_filter_ref, fuel_filter_ref, spark_plug_ref, tire_size_front,
      tire_size_rear, tire_brand, battery_spec, notes, source
    ) VALUES (
      v_id,
      NULLIF(trim(p_specs->>'oil_type'), ''),
      NULLIF(p_specs->>'oil_liters', '')::NUMERIC(4,2),
      CASE WHEN jsonb_typeof(p_specs->'oil_brands') = 'array'
           THEN ARRAY(SELECT jsonb_array_elements_text(p_specs->'oil_brands'))
           ELSE NULL END,
      NULLIF(trim(p_specs->>'oil_filter_ref'), ''),
      NULLIF(trim(p_specs->>'air_filter_ref'), ''),
      NULLIF(trim(p_specs->>'cabin_filter_ref'), ''),
      NULLIF(trim(p_specs->>'fuel_filter_ref'), ''),
      NULLIF(trim(p_specs->>'spark_plug_ref'), ''),
      NULLIF(trim(p_specs->>'tire_size_front'), ''),
      NULLIF(trim(p_specs->>'tire_size_rear'), ''),
      NULLIF(trim(p_specs->>'tire_brand'), ''),
      NULLIF(trim(p_specs->>'battery_spec'), ''),
      NULLIF(trim(p_specs->>'notes'), ''),
      COALESCE(NULLIF(p_specs->>'source', ''), 'manual')
    );
  END IF;

  RETURN v_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.create_vehicle(JSONB, JSONB) TO authenticated;
REVOKE EXECUTE ON FUNCTION public.create_vehicle(JSONB, JSONB) FROM anon;
