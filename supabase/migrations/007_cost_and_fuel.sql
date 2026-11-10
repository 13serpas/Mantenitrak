-- ============================================================
-- MANTENITRAK — Migración 007: coste total repartido y repostajes
-- (mejora del punto 5 y punto 6). Ejecutar después de 006. Idempotente.
-- ============================================================

-- ─── 1. Coste estimado en mantenimientos ─────────────────────
-- true cuando el coste sale de repartir un total entre varios trabajos.
ALTER TABLE public.maintenance_records
  ADD COLUMN IF NOT EXISTS cost_estimated BOOLEAN NOT NULL DEFAULT FALSE;

-- ─── 2. Comprobación de km compartida ────────────────────────
-- Unos km anotados en una fecha no pueden ser menos que una lectura del
-- mismo día o anterior, ni más que una lectura de un día posterior.
-- La usan register_maintenance y register_fuel.
CREATE OR REPLACE FUNCTION public.assert_km_fits(p_vehicle_id UUID, p_km INT, p_date DATE)
RETURNS VOID
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_prev RECORD;
  v_next RECORD;
BEGIN
  IF p_km IS NULL THEN RETURN; END IF;
  IF p_km < 0 OR p_km > 3000000 THEN
    RAISE EXCEPTION 'Kilometraje no válido' USING ERRCODE = '22023';
  END IF;
  SELECT km, logged_at INTO v_prev FROM public.km_logs
   WHERE vehicle_id = p_vehicle_id AND logged_at <= p_date AND km > p_km
   ORDER BY km DESC LIMIT 1;
  IF FOUND THEN
    RAISE EXCEPTION 'Los km son menores que una lectura anterior (% km el %)',
      replace(to_char(v_prev.km, 'FM9,999,999'), ',', '.'), to_char(v_prev.logged_at, 'DD/MM/YYYY')
      USING ERRCODE = '22023';
  END IF;
  SELECT km, logged_at INTO v_next FROM public.km_logs
   WHERE vehicle_id = p_vehicle_id AND logged_at > p_date AND km < p_km
   ORDER BY km ASC LIMIT 1;
  IF FOUND THEN
    RAISE EXCEPTION 'Los km son mayores que una lectura posterior (% km el %)',
      replace(to_char(v_next.km, 'FM9,999,999'), ',', '.'), to_char(v_next.logged_at, 'DD/MM/YYYY')
      USING ERRCODE = '22023';
  END IF;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.assert_km_fits(UUID, INT, DATE) FROM anon, public;
GRANT EXECUTE ON FUNCTION public.assert_km_fits(UUID, INT, DATE) TO authenticated;

-- ─── 3. register_maintenance con coste estimado ──────────────
CREATE OR REPLACE FUNCTION public.register_maintenance(
  p_vehicle_id UUID,
  p_date       DATE,
  p_km         INT,
  p_items      JSONB,
  p_notes      TEXT DEFAULT NULL
)
RETURNS INT
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid    UUID := auth.uid();
  v_item   JSONB;
  v_id     TEXT;
  v_name   TEXT;
  v_cost   NUMERIC;
  v_photos TEXT[];
  v_count  INT := 0;
  v_est    BOOLEAN;
  v_notes  TEXT := left(NULLIF(trim(p_notes), ''), 1000);
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Debes iniciar sesión' USING ERRCODE = '42501';
  END IF;
  IF NOT public.has_vehicle_access(p_vehicle_id) THEN
    RAISE EXCEPTION 'No tienes acceso a este vehículo' USING ERRCODE = '42501';
  END IF;

  IF p_date IS NULL OR p_date > CURRENT_DATE THEN
    RAISE EXCEPTION 'La fecha no puede ser futura' USING ERRCODE = '22023';
  END IF;
  IF p_date < DATE '1950-01-01' THEN
    RAISE EXCEPTION 'La fecha no es válida' USING ERRCODE = '22023';
  END IF;

  IF p_items IS NULL OR jsonb_typeof(p_items) <> 'array' OR jsonb_array_length(p_items) = 0 THEN
    RAISE EXCEPTION 'Elige al menos un trabajo' USING ERRCODE = '22023';
  END IF;
  IF jsonb_array_length(p_items) > 40 THEN
    RAISE EXCEPTION 'Demasiados trabajos en un solo registro' USING ERRCODE = '22023';
  END IF;

  IF p_km IS NOT NULL THEN
    PERFORM public.assert_km_fits(p_vehicle_id, p_km, p_date);
  END IF;

  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items) LOOP
    v_id   := v_item->>'item_id';
    v_name := left(NULLIF(trim(v_item->>'item_name'), ''), 80);

    IF v_id IS NULL OR v_id !~ '^[a-z_]{2,40}$' THEN
      RAISE EXCEPTION 'Trabajo no válido' USING ERRCODE = '22023';
    END IF;
    IF v_id = 'otro' AND v_name IS NULL THEN
      RAISE EXCEPTION 'Escribe qué trabajo se hizo' USING ERRCODE = '22023';
    END IF;

    BEGIN
      v_cost := NULLIF(replace(v_item->>'cost', ',', '.'), '')::NUMERIC;
    EXCEPTION WHEN invalid_text_representation THEN
      RAISE EXCEPTION 'El coste debe ser un número' USING ERRCODE = '22023';
    END;
    IF v_cost IS NOT NULL AND (v_cost < 0 OR v_cost > 99999) THEN
      RAISE EXCEPTION 'El coste debe estar entre 0 y 99.999 €' USING ERRCODE = '22023';
    END IF;

    -- Solo rutas de ESTE vehículo: no se pueden enlazar fotos de otros.
    v_photos := ARRAY(SELECT jsonb_array_elements_text(COALESCE(v_item->'photos', '[]'::JSONB)));
    IF cardinality(v_photos) > 6 THEN
      RAISE EXCEPTION 'Máximo 6 fotos por trabajo' USING ERRCODE = '22023';
    END IF;
    IF EXISTS (
      SELECT 1 FROM unnest(v_photos) p
      WHERE p !~ ('^' || p_vehicle_id::TEXT || '/[A-Za-z0-9_-]{1,80}\.(jpg|jpeg|png|webp)$')
    ) THEN
      RAISE EXCEPTION 'Ruta de foto no válida' USING ERRCODE = '22023';
    END IF;

    -- Coste estimado = reparto de un total entre varios trabajos.
    v_est := COALESCE((v_item->>'cost_estimated')::BOOLEAN, FALSE) AND v_cost IS NOT NULL;

    INSERT INTO public.maintenance_records
      (vehicle_id, user_id, item_id, item_name, performed_at, km, cost, cost_estimated, notes, photos)
    VALUES
      (p_vehicle_id, v_uid, v_id, v_name, p_date, p_km, round(v_cost, 2), v_est, v_notes,
       CASE WHEN cardinality(v_photos) = 0 THEN NULL ELSE v_photos END);
    v_count := v_count + 1;
  END LOOP;

  -- Lectura de km (sin duplicar si ya existe la misma ese día).
  IF p_km IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public.km_logs WHERE vehicle_id = p_vehicle_id AND logged_at = p_date AND km = p_km
  ) THEN
    PERFORM public.log_km(p_vehicle_id, p_km, p_date);
  END IF;

  RETURN v_count;
END;
$$;


GRANT EXECUTE ON FUNCTION public.register_maintenance(UUID, DATE, INT, JSONB, TEXT) TO authenticated;
REVOKE EXECUTE ON FUNCTION public.register_maintenance(UUID, DATE, INT, JSONB, TEXT) FROM anon, public;

-- ─── 4. Consumo: lo calcula la app ───────────────────────────
-- El trigger de 001 dividía los litros de UN repostaje entre los km desde
-- el lleno anterior, sin sumar los repostajes parciales intermedios, y
-- fallaba al registrar repostajes atrasados. La app ya calcula el consumo
-- por tramos (lleno a lleno) con todos los litros, así que se retira.
DROP TRIGGER IF EXISTS trg_fuel_consumption ON public.fuel_logs;

-- ─── 5. Registrar un repostaje (punto 6) ─────────────────────
-- Basta con dos de los tres importes (cantidad, precio, total): el
-- tercero se calcula. Si llegan los tres, deben cuadrar.
-- En eléctricos, la cantidad son kWh y el precio €/kWh.
-- Si llegan km, se comprueban con las lecturas y se guardan con log_km
-- (el prototipo hacía UPDATE directo: fallaba en vehículos compartidos).
CREATE OR REPLACE FUNCTION public.register_fuel(
  p_vehicle_id UUID,
  p_date       DATE,
  p_km         INT,
  p_liters     NUMERIC,
  p_price      NUMERIC,
  p_total      NUMERIC,
  p_full_tank  BOOLEAN DEFAULT TRUE,
  p_fuel_type  TEXT DEFAULT NULL,
  p_station    TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid    UUID := auth.uid();
  v_liters NUMERIC := p_liters;
  v_price  NUMERIC := p_price;
  v_total  NUMERIC := p_total;
  v_given  INT := (p_liters IS NOT NULL)::INT + (p_price IS NOT NULL)::INT + (p_total IS NOT NULL)::INT;
  v_id     UUID;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Debes iniciar sesión' USING ERRCODE = '42501';
  END IF;
  IF NOT public.has_vehicle_access(p_vehicle_id) THEN
    RAISE EXCEPTION 'No tienes acceso a este vehículo' USING ERRCODE = '42501';
  END IF;
  IF p_date IS NULL OR p_date > CURRENT_DATE OR p_date < DATE '1950-01-01' THEN
    RAISE EXCEPTION 'La fecha no puede ser futura' USING ERRCODE = '22023';
  END IF;

  IF v_given < 2 THEN
    RAISE EXCEPTION 'Indica al menos dos de: cantidad, precio y total' USING ERRCODE = '22023';
  END IF;
  IF (v_liters IS NOT NULL AND (v_liters <= 0 OR v_liters > 999))
     OR (v_price IS NOT NULL AND (v_price <= 0 OR v_price > 9.999))
     OR (v_total IS NOT NULL AND (v_total <= 0 OR v_total > 9999)) THEN
    RAISE EXCEPTION 'Algún importe está fuera de rango' USING ERRCODE = '22023';
  END IF;

  IF v_liters IS NULL THEN v_liters := round(v_total / v_price, 3); END IF;
  IF v_price  IS NULL THEN v_price  := round(v_total / v_liters, 3); END IF;
  IF v_total  IS NULL THEN v_total  := round(v_liters * v_price, 2); END IF;
  -- Margen: el surtidor redondea y a veces hay descuentos de céntimos.
  IF abs(v_liters * v_price - v_total) > greatest(0.10, v_total * 0.02) THEN
    RAISE EXCEPTION 'Cantidad × precio no coincide con el total (% €)',
      replace(to_char(round(v_liters * v_price, 2), 'FM99990.00'), '.', ',')
      USING ERRCODE = '22023';
  END IF;
  IF v_price > 9.999 OR v_liters > 999 THEN
    RAISE EXCEPTION 'Algún importe está fuera de rango' USING ERRCODE = '22023';
  END IF;

  IF p_fuel_type IS NOT NULL AND p_fuel_type NOT IN
     ('Gasolina 95', 'Gasolina 98', 'Diésel', 'Diésel premium', 'GLP', 'GNC', 'Electricidad') THEN
    RAISE EXCEPTION 'Combustible no válido' USING ERRCODE = '22023';
  END IF;

  IF p_km IS NOT NULL THEN
    PERFORM public.assert_km_fits(p_vehicle_id, p_km, p_date);
  END IF;

  INSERT INTO public.fuel_logs
    (vehicle_id, user_id, logged_at, km, liters, price_per_liter, total, fuel_type, full_tank, station)
  VALUES
    (p_vehicle_id, v_uid, p_date, p_km, round(v_liters, 3), round(v_price, 3), round(v_total, 2),
     p_fuel_type, COALESCE(p_full_tank, TRUE), left(NULLIF(trim(p_station), ''), 80))
  RETURNING id INTO v_id;

  IF p_km IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public.km_logs WHERE vehicle_id = p_vehicle_id AND logged_at = p_date AND km = p_km
  ) THEN
    PERFORM public.log_km(p_vehicle_id, p_km, p_date);
  END IF;

  RETURN v_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.register_fuel(UUID, DATE, INT, NUMERIC, NUMERIC, NUMERIC, BOOLEAN, TEXT, TEXT) TO authenticated;
REVOKE EXECUTE ON FUNCTION public.register_fuel(UUID, DATE, INT, NUMERIC, NUMERIC, NUMERIC, BOOLEAN, TEXT, TEXT) FROM anon, public;
