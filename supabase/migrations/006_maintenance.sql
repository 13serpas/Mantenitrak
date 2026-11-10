-- ============================================================
-- MANTENITRAK — Migración 006: registrar mantenimientos (punto 5)
-- Registro atómico de varios trabajos + fotos en Storage.
-- Ejecutar después de 005. Idempotente.
-- ============================================================

-- ─── 1. Bucket privado para las fotos ────────────────────────
-- Antes las fotos iban en base64 dentro de la fila (cientos de KB cada
-- una). Ahora se suben a Storage y la fila guarda solo la ruta:
--   maintenance-photos/<vehicle_id>/<nombre>.jpg
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('maintenance-photos', 'maintenance-photos', false, 5242880,
        ARRAY['image/jpeg', 'image/png', 'image/webp'])
ON CONFLICT (id) DO UPDATE SET
  public             = false,
  file_size_limit    = EXCLUDED.file_size_limit,
  allowed_mime_types = EXCLUDED.allowed_mime_types;

-- Vehículo al que pertenece una ruta de Storage (NULL si no es válida).
CREATE OR REPLACE FUNCTION public.photo_vehicle_id(p_name TEXT)
RETURNS UUID
LANGUAGE sql IMMUTABLE
SET search_path = public, pg_temp
AS $$
  SELECT CASE
    WHEN split_part(p_name, '/', 1) ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    THEN split_part(p_name, '/', 1)::UUID
  END;
$$;

CREATE OR REPLACE FUNCTION public.is_vehicle_owner(p_vehicle_id UUID)
RETURNS BOOLEAN
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT EXISTS (SELECT 1 FROM public.vehicles WHERE id = p_vehicle_id AND owner_id = auth.uid());
$$;

-- Quien tiene acceso al vehículo (propietario o compartido) ve y sube
-- fotos. Borra quien la subió o el propietario del vehículo.
-- (Sustituye a las políticas por carpeta de usuario que estaban
-- comentadas en el esquema v1: con ellas el taller no veía las fotos del
-- propietario ni al revés.)
DROP POLICY IF EXISTS "Ver fotos de mis vehículos" ON storage.objects;
CREATE POLICY "Ver fotos de mis vehículos" ON storage.objects FOR SELECT TO authenticated
  USING (bucket_id = 'maintenance-photos'
         AND public.has_vehicle_access(public.photo_vehicle_id(name)));

DROP POLICY IF EXISTS "Subir fotos a mis vehículos" ON storage.objects;
CREATE POLICY "Subir fotos a mis vehículos" ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'maintenance-photos'
              AND public.has_vehicle_access(public.photo_vehicle_id(name)));

DROP POLICY IF EXISTS "Borrar fotos propias o de mis vehículos" ON storage.objects;
CREATE POLICY "Borrar fotos propias o de mis vehículos" ON storage.objects FOR DELETE TO authenticated
  USING (bucket_id = 'maintenance-photos'
         AND (owner_id = auth.uid()::TEXT
              OR public.is_vehicle_owner(public.photo_vehicle_id(name))));

-- ─── 2. Registrar uno o varios mantenimientos ────────────────
-- p_items: [{ "item_id": "aceite", "item_name": "Aceite del motor",
--             "cost": 89.9, "photos": ["<vehicle_id>/abc.jpg"] }, …]
-- Todo o nada: si un elemento no es válido no se guarda ninguno.
-- Si llegan km, se guardan como lectura (log_km) comprobando que encajan
-- con las lecturas anteriores y posteriores.
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
  v_prev   RECORD;
  v_next   RECORD;
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

  -- Los km tienen que encajar con lo ya anotado: no menos que una lectura
  -- del mismo día o anterior, no más que una lectura de un día posterior.
  IF p_km IS NOT NULL THEN
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

    INSERT INTO public.maintenance_records
      (vehicle_id, user_id, item_id, item_name, performed_at, km, cost, notes, photos)
    VALUES
      (p_vehicle_id, v_uid, v_id, v_name, p_date, p_km, round(v_cost, 2), v_notes,
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
