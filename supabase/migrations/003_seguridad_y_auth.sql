-- ============================================================
-- MANTENITRAK — Migración 003: correcciones de seguridad + auth
-- Ejecutar DESPUÉS de 001 (schema v1) y 002 (schema v2).
-- Es idempotente: se puede ejecutar más de una vez.
-- ============================================================

-- gen_random_bytes() para códigos de compartir criptográficamente seguros
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ─── 1. VISTA vehicle_summary: respetar RLS ──────────────────
-- Sin security_invoker, la vista se ejecuta con los permisos de su
-- dueño y cualquier usuario autenticado ve TODOS los vehículos,
-- incluido su share_code.
ALTER VIEW public.vehicle_summary SET (security_invoker = true);

-- ─── 2. shared_vehicles: solo se entra con código ────────────
-- La política anterior permitía insertarse en cualquier vehicle_id
-- sin conocer el código. Ahora la única vía es join_vehicle_by_code().
DROP POLICY IF EXISTS "Unirse mediante share_code (INSERT propio)" ON public.shared_vehicles;

-- ─── 3. Códigos de compartir aleatorios de verdad ────────────
-- Alfabeto sin caracteres ambiguos (sin 0/O, 1/I/L).
CREATE OR REPLACE FUNCTION public.generate_share_code(p_len INT DEFAULT 6)
RETURNS TEXT LANGUAGE plpgsql VOLATILE
SET search_path = public, extensions, pg_temp
AS $$
DECLARE
  v_alphabet CONSTANT TEXT := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  v_bytes    BYTEA := gen_random_bytes(p_len);
  v_code     TEXT  := '';
BEGIN
  FOR i IN 0..p_len-1 LOOP
    v_code := v_code || substr(v_alphabet, (get_byte(v_bytes, i) % length(v_alphabet)) + 1, 1);
  END LOOP;
  RETURN v_code;
END;
$$;

ALTER TABLE public.vehicles
  ALTER COLUMN share_code SET DEFAULT public.generate_share_code(6);

-- Impide que el cliente fije el código (el prototipo lo derivaba
-- de la hora actual, lo que lo hacía predecible).
CREATE OR REPLACE FUNCTION public.vehicles_force_share_code()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.share_code := public.generate_share_code(6);
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_vehicles_share_code ON public.vehicles;
CREATE TRIGGER trg_vehicles_share_code
  BEFORE INSERT ON public.vehicles
  FOR EACH ROW EXECUTE FUNCTION public.vehicles_force_share_code();

-- Regenerar el código (por si se ha filtrado). Solo el propietario.
CREATE OR REPLACE FUNCTION public.regenerate_share_code(p_vehicle_id UUID)
RETURNS TEXT LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_code TEXT;
BEGIN
  UPDATE public.vehicles
     SET share_code = public.generate_share_code(6)
   WHERE id = p_vehicle_id AND owner_id = auth.uid()
  RETURNING share_code INTO v_code;
  IF v_code IS NULL THEN
    RAISE EXCEPTION 'No eres el propietario de este vehículo' USING ERRCODE = '42501';
  END IF;
  RETURN v_code;
END;
$$;

-- ─── 4. join_vehicle_by_code con límite de intentos ──────────
CREATE TABLE IF NOT EXISTS public.join_attempts (
  id         BIGSERIAL PRIMARY KEY,
  user_id    UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  success    BOOLEAN NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_join_attempts_user ON public.join_attempts(user_id, created_at DESC);
ALTER TABLE public.join_attempts ENABLE ROW LEVEL SECURITY;  -- sin políticas: solo accesible vía funciones

CREATE OR REPLACE FUNCTION public.join_vehicle_by_code(
  p_code TEXT,
  p_role TEXT DEFAULT 'regular'
)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid     UUID := auth.uid();
  v_vehicle public.vehicles;
  v_fails   INT;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('error', 'Debes iniciar sesión');
  END IF;
  IF p_role NOT IN ('regular','company','mechanic') THEN
    RETURN jsonb_build_object('error', 'Rol no válido');
  END IF;

  SELECT count(*) INTO v_fails FROM public.join_attempts
   WHERE user_id = v_uid AND NOT success AND created_at > NOW() - INTERVAL '1 hour';
  IF v_fails >= 10 THEN
    RETURN jsonb_build_object('error', 'Demasiados intentos. Prueba de nuevo en una hora.');
  END IF;

  SELECT * INTO v_vehicle FROM public.vehicles WHERE share_code = upper(trim(p_code));
  IF NOT FOUND THEN
    INSERT INTO public.join_attempts (user_id, success) VALUES (v_uid, FALSE);
    RETURN jsonb_build_object('error', 'Código no válido');
  END IF;

  IF v_vehicle.owner_id = v_uid THEN
    RETURN jsonb_build_object('error', 'Ya eres el propietario de este vehículo');
  END IF;

  INSERT INTO public.join_attempts (user_id, success) VALUES (v_uid, TRUE);
  INSERT INTO public.shared_vehicles (vehicle_id, user_id, role)
  VALUES (v_vehicle.id, v_uid, p_role)
  ON CONFLICT (vehicle_id, user_id) DO UPDATE SET role = EXCLUDED.role;

  RETURN jsonb_build_object('success', true, 'vehicle_id', v_vehicle.id,
                            'brand', v_vehicle.brand, 'model', v_vehicle.model);
END;
$$;

-- ─── 5. search_path fijo en funciones SECURITY DEFINER ───────
ALTER FUNCTION public.has_vehicle_access(UUID) SET search_path = public, pg_temp;

-- ─── 6. Informes: ejecutar con los permisos del usuario ──────
-- Como SECURITY DEFINER, cualquiera podía leer los totales de
-- combustible y mantenimiento de cualquier vehículo.
ALTER FUNCTION public.get_expense_summary(UUID, TEXT, INT, INT, INT, DATE, DATE) SECURITY INVOKER;
ALTER FUNCTION public.get_expense_summary(UUID, TEXT, INT, INT, INT, DATE, DATE) SET search_path = public, pg_temp;
ALTER FUNCTION public.get_upcoming_expenses(UUID, INT) SECURITY INVOKER;
ALTER FUNCTION public.get_upcoming_expenses(UUID, INT) SET search_path = public, pg_temp;

-- ─── 7. Registrar km (propietario o usuario compartido) ──────
-- vehicles solo admite UPDATE del propietario, así que un usuario
-- compartido no podía actualizar current_km (fallaba en silencio).
CREATE OR REPLACE FUNCTION public.log_km(
  p_vehicle_id UUID,
  p_km         INT,
  p_date       DATE DEFAULT CURRENT_DATE
)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.has_vehicle_access(p_vehicle_id) THEN
    RAISE EXCEPTION 'Sin acceso a este vehículo' USING ERRCODE = '42501';
  END IF;
  IF p_km IS NULL OR p_km < 0 THEN
    RAISE EXCEPTION 'Kilometraje no válido' USING ERRCODE = '22023';
  END IF;
  INSERT INTO public.km_logs (vehicle_id, user_id, km, logged_at)
  VALUES (p_vehicle_id, auth.uid(), p_km, COALESCE(p_date, CURRENT_DATE));
  UPDATE public.vehicles
     SET current_km = p_km
   WHERE id = p_vehicle_id AND (current_km IS NULL OR current_km < p_km);
END;
$$;

-- ─── 8. Trigger de viajes ────────────────────────────────────
-- (a) total_cost es una columna generada y aún vale NULL en un
--     trigger BEFORE: cost_per_km salía siempre vacío.
-- (b) Usaba UPDATE directo sobre vehicles, bloqueado para usuarios
--     compartidos. Ahora usa log_km().
-- El cliente NO debe insertar km_logs ni tocar current_km al cerrar
-- un viaje: lo hace este trigger.
CREATE OR REPLACE FUNCTION public.calculate_trip_cost_per_km()
RETURNS TRIGGER LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
DECLARE v_total NUMERIC;
BEGIN
  IF NEW.km_end IS NOT NULL AND NEW.km_end > NEW.km_start THEN
    v_total := COALESCE(NEW.fuel_cost,0) + COALESCE(NEW.toll_cost,0) + COALESCE(NEW.other_cost,0);
    NEW.cost_per_km := ROUND(v_total / (NEW.km_end - NEW.km_start)::NUMERIC, 3);
    IF OLD.km_end IS NULL THEN
      PERFORM public.log_km(NEW.vehicle_id, NEW.km_end, COALESCE(NEW.ended_at, CURRENT_DATE));
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

-- ─── 9. Perfiles: compatible con Google y visibles entre co-usuarios
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  INSERT INTO public.profiles (id, display_name, avatar_url)
  VALUES (
    NEW.id,
    COALESCE(NULLIF(NEW.raw_user_meta_data->>'full_name',''),
             NULLIF(NEW.raw_user_meta_data->>'name',''),
             split_part(NEW.email, '@', 1)),
    COALESCE(NEW.raw_user_meta_data->>'avatar_url', NEW.raw_user_meta_data->>'picture')
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;

-- Para mostrar nombres (no UUIDs) en la pantalla de compartir.
CREATE OR REPLACE FUNCTION public.shares_vehicle_with(p_other UUID)
RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT EXISTS (
    SELECT 1
      FROM public.vehicles v
      LEFT JOIN public.shared_vehicles s ON s.vehicle_id = v.id
     WHERE (v.owner_id = auth.uid() OR s.user_id = auth.uid())
       AND (v.owner_id = p_other    OR s.user_id = p_other)
  );
$$;

DROP POLICY IF EXISTS "Ver perfiles de co-usuarios" ON public.profiles;
CREATE POLICY "Ver perfiles de co-usuarios"
  ON public.profiles FOR SELECT
  USING (public.shares_vehicle_with(id));
